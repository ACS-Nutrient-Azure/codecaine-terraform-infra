import boto3
import os
import json
import time


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
        print(f"AgentCore Runtime already exists, updating: {agent_name} (id={existing_id})")
        existing = agentcore.get_agent_runtime(agentRuntimeId=existing_id)
        runtime_arn = existing["agentRuntimeArn"]
        update_kwargs = {
            "agentRuntimeId": existing_id,
            "agentRuntimeArtifact": {"containerConfiguration": {"containerUri": image_uri}},
            "networkConfiguration": existing["networkConfiguration"],
            "roleArn": role_arn,
        }
        if event.get("environment_variables"):
            update_kwargs["environmentVariables"] = event["environment_variables"]
        agentcore.update_agent_runtime(**update_kwargs)
        print(f"AgentCore Runtime updated: {agent_name}")
    else:
        print(f"Creating AgentCore Runtime: {agent_name}")
        last_error = None
        for attempt in range(6):
            try:
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
