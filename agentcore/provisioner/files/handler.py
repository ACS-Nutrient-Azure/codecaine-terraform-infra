import boto3
import os
import json
import time
import urllib.request
import urllib.error
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest


def _update_runtime_via_http(region, existing_id, image_uri, role_arn, network_mode, network_mode_config, environment_variables=None):
    """
    botocore가 networkModeConfig를 미지원하므로 update도 직접 REST API 호출
    PATCH /runtimes/{agentRuntimeId}
    """
    session = boto3.session.Session()
    credentials = session.get_credentials().get_frozen_credentials()

    url = f"https://bedrock-agentcore-control.{region}.amazonaws.com/runtimes/{existing_id}"

    body = {
        "agentRuntimeArtifact": {"containerConfiguration": {"containerUri": image_uri}},
        "networkConfiguration": {"networkMode": network_mode},
        "roleArn": role_arn,
    }

    if network_mode_config:
        body["networkConfiguration"]["networkModeConfig"] = {
            "subnets":        network_mode_config.get("subnet_ids", []),
            "securityGroups": network_mode_config.get("security_group_ids", []),
        }

    if environment_variables:
        body["environmentVariables"] = environment_variables

    body_bytes = json.dumps(body).encode("utf-8")

    request = AWSRequest(method="PUT", url=url, data=body_bytes, headers={
        "Content-Type": "application/json",
        "Accept":       "application/json",
    })
    SigV4Auth(credentials, "bedrock-agentcore", region).add_auth(request)

    req = urllib.request.Request(
        url,
        data=body_bytes,
        headers=dict(request.headers),
        method="PUT",
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _create_runtime_via_http(region, agent_name, image_uri, role_arn, network_mode, network_mode_config, environment_variables=None):
    """
    botocore가 networkModeConfig를 미지원하는 경우 직접 REST API 호출
    PUT /runtimes/ (CreateAgentRuntime)
    """
    session = boto3.session.Session()
    credentials = session.get_credentials().get_frozen_credentials()

    url = f"https://bedrock-agentcore-control.{region}.amazonaws.com/runtimes/"

    body = {
        "agentRuntimeName": agent_name,
        "agentRuntimeArtifact": {"containerConfiguration": {"containerUri": image_uri}},
        "networkConfiguration": {"networkMode": network_mode},
        "roleArn": role_arn,
    }

    if network_mode_config:
        body["networkConfiguration"]["networkModeConfig"] = {
            "subnets":        network_mode_config.get("subnet_ids", []),
            "securityGroups": network_mode_config.get("security_group_ids", []),
        }

    if environment_variables:
        body["environmentVariables"] = environment_variables

    body_bytes = json.dumps(body).encode("utf-8")

    request = AWSRequest(method="PUT", url=url, data=body_bytes, headers={
        "Content-Type": "application/json",
        "Accept":       "application/json",
    })
    SigV4Auth(credentials, "bedrock-agentcore", region).add_auth(request)

    req = urllib.request.Request(
        url,
        data=body_bytes,
        headers=dict(request.headers),
        method="PUT",
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))


def lambda_handler(event, context):
    region       = event.get("region", os.environ.get("AWS_REGION", "ap-northeast-2"))
    agent_name   = event["agent_name"]
    image_uri    = event["image_uri"]
    role_arn     = event["role_arn"]
    ssm_key      = event["ssm_key"]
    network_mode = event.get("network_mode", "PUBLIC")
    account_id   = role_arn.split(":")[4]

    # trust policy 강제 업데이트 (Condition 포함)
    iam = boto3.client("iam")
    role_name = role_arn.split("/")[-1]
    trust_policy = {
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "AssumeRolePolicy",
            "Effect": "Allow",
            "Principal": {"Service": "bedrock-agentcore.amazonaws.com"},
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {"aws:SourceAccount": account_id},
                "ArnLike": {"aws:SourceArn": f"arn:aws:bedrock-agentcore:{region}:{account_id}:*"}
            }
        }]
    }
    iam.update_assume_role_policy(
        RoleName=role_name,
        PolicyDocument=json.dumps(trust_policy)
    )
    print(f"Trust policy updated for role: {role_name}")

    # IAM propagation 대기
    time.sleep(10)

    agentcore = boto3.client("bedrock-agentcore-control", region_name=region)

    # ECR 최신 이미지 태그 조회
    ecr = boto3.client("ecr", region_name=region)
    repo_name = image_uri.split("/", 1)[1].split(":")[0]
    try:
        response = ecr.describe_images(
            repositoryName=repo_name,
            filter={"tagStatus": "TAGGED"},
        )
        images = sorted(
            [img for img in response["imageDetails"] if img.get("imageTags")],
            key=lambda x: x["imagePushedAt"],
            reverse=True,
        )
        if images:
            latest_tag = images[0]["imageTags"][0]
            repo_url = image_uri.rsplit(":", 1)[0]
            image_uri = f"{repo_url}:{latest_tag}"
            print(f"Using latest ECR image: {image_uri}")
        else:
            print(f"No tagged images found in {repo_name} — skipping AgentCore Runtime creation")
            ssm = boto3.client("ssm", region_name=region)
            ssm.put_parameter(Name=ssm_key, Value="pending", Type="String", Overwrite=True)
            return {"runtime_arn": None, "ssm_key": ssm_key, "skipped": True}
    except Exception as e:
        print(f"ECR describe_images failed: {e} — skipping")
        ssm = boto3.client("ssm", region_name=region)
        ssm.put_parameter(Name=ssm_key, Value="pending", Type="String", Overwrite=True)
        return {"runtime_arn": None, "ssm_key": ssm_key, "skipped": True}

    network_mode_config = event.get("network_mode_config")  # VPC 모드 시 subnet/sg 정보

    # 기존 runtime 조회
    paginator = agentcore.get_paginator("list_agent_runtimes")
    existing_id = None
    for page in paginator.paginate():
        for rt in page.get("agentRuntimes", []):
            if rt.get("agentRuntimeName") == agent_name:
                existing_id = rt.get("agentRuntimeId")
                break
        if existing_id:
            break

    if existing_id:
        print(f"AgentCore Runtime already exists: {agent_name} (id={existing_id})")
        existing = agentcore.get_agent_runtime(agentRuntimeId=existing_id)

        existing_subnets = set(
            existing.get("networkConfiguration", {})
                    .get("networkModeConfig", {})
                    .get("subnetIds", [])
        )
        desired_subnets = set(network_mode_config.get("subnet_ids", [])) if network_mode_config else set()

        if desired_subnets and existing_subnets and existing_subnets != desired_subnets:
            print(f"Subnet change detected — deleting and recreating Runtime: {existing_id}")
            agentcore.delete_agent_runtime(agentRuntimeId=existing_id)
            for _ in range(30):
                try:
                    agentcore.get_agent_runtime(agentRuntimeId=existing_id)
                    time.sleep(5)
                except Exception:
                    break
            existing_id = None  # 아래 create 블록에서 처리
        else:
            runtime_arn = existing["agentRuntimeArn"]
            resp_body = _update_runtime_via_http(
                region, existing_id, image_uri, role_arn,
                network_mode, network_mode_config,
                event.get("environment_variables"),
            )
            print(f"AgentCore Runtime updated: {agent_name}")

    if not existing_id:
        # 신규 생성 또는 서브넷 변경으로 인한 재생성
        print(f"Creating AgentCore Runtime: {agent_name}")
        last_error = None
        for attempt in range(6):
            try:
                if network_mode_config:
                    resp_body = _create_runtime_via_http(
                        region, agent_name, image_uri, role_arn,
                        network_mode, network_mode_config,
                        event.get("environment_variables"),
                    )
                    print(f"HTTP create response: {json.dumps(resp_body)}")
                    runtime_arn = resp_body["agentRuntimeArn"]
                else:
                    response = agentcore.create_agent_runtime(
                        agentRuntimeName=agent_name,
                        agentRuntimeArtifact={"containerConfiguration": {"containerUri": image_uri}},
                        networkConfiguration={"networkMode": network_mode},
                        roleArn=role_arn,
                        **( {"environmentVariables": event["environment_variables"]} if event.get("environment_variables") else {} )
                    )
                    runtime_arn = response["agentRuntimeArn"]
                last_error = None
                break
            except agentcore.exceptions.ValidationException as e:
                if "Role validation failed" in str(e):
                    print(f"Role not ready yet, retrying in 5s... (attempt {attempt+1}/6)")
                    time.sleep(5)
                    last_error = e
                else:
                    raise
            except urllib.error.HTTPError as e:
                body = e.read().decode("utf-8")
                if "Role validation failed" in body:
                    print(f"Role not ready yet, retrying in 5s... (attempt {attempt+1}/6)")
                    time.sleep(5)
                    last_error = e
                else:
                    raise
        if last_error:
            raise last_error

    print(f"Runtime ARN: {runtime_arn}")

    # SSM에 ARN 저장
    ssm = boto3.client("ssm", region_name=region)
    ssm.put_parameter(
        Name=ssm_key,
        Value=runtime_arn,
        Type="String",
        Overwrite=True,
    )
    print(f"SSM parameter saved: {ssm_key}")

    return {"runtime_arn": runtime_arn, "ssm_key": ssm_key}
