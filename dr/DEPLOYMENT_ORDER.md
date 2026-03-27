# DR 인프라 배포 순서 (ap-northeast-1 도쿄)

## 개요

DR 인프라는 두 단계로 나뉩니다.

- **Phase 1 (지금)**: 뼈대 인프라 배포 — ECS desired_count=0, AgentCore Runtime 없음
- **Phase 2 (Aurora 전환 + Failover 테스트 시)**: DB Secondary + 자동 Failover 활성화

---

## Phase 1 — 뼈대 배포

### 사전 준비

```bash
mkdir dr/agentcore/files
mkdir dr/failover/files
```

### Step 1 — foundation
**의존성**: 없음

```bash
cd dr/foundation
terraform init && terraform apply --auto-approve
```

### Step 2 — nat
**의존성**: foundation 완료 필수

> ECS Task가 private subnet에서 ECR 이미지 pull 및 외부 통신에 필요.

```bash
cd dr/nat
terraform init && terraform apply --auto-approve
```

### Step 3 — ecr-replication, s3-replication (병렬 가능)
**의존성**: 없음 (독립)

> ECR Replication 설정은 즉시 생성되지만, **기존 이미지는 복제되지 않음**.
> 이후 새로 push되는 이미지부터 도쿄로 자동 복제됨.
> Failover 테스트 전 기존 이미지 수동 sync 필요 (아래 참고).

```bash
cd dr/ecr-replication
terraform init && terraform apply --auto-approve

cd dr/s3-replication
terraform init && terraform apply --auto-approve
```

### Step 4 — agentcore
**의존성**: 없음 (독립)

> provisioner Lambda + nutrient-calc Lambda + IAM Role 배포.
> AgentCore Runtime은 생성하지 않음 — Failover 시 Step Functions이 생성.

```bash
cd dr/agentcore
terraform init && terraform apply --auto-approve
```

### Step 5 — compute
**의존성**: foundation + nat 완료 필수

> ECS Cluster + ALB + ACM + ECS Service (desired_count=0) 배포.
> ACM 인증서 DNS 검증에 수 분 소요될 수 있음.

```bash
cd dr/compute
terraform init && terraform apply --auto-approve
```

---

## Phase 2 — Aurora Global DB + Failover 활성화

### Step 5 — Primary Aurora Global Database 활성화
**의존성**: Phase 1 완료 필수

Primary `database-rds/terraform.tfvars`에서 변경 후 apply:

```hcl
enable_global_database = true
```

```bash
cd database-rds
terraform apply --auto-approve
```

### Step 6 — database (DR Secondary)
**의존성**: Step 5 완료 필수 (Global Cluster ID 참조)

```bash
cd dr/database
terraform init && terraform apply --auto-approve
```

### Step 7 — failover
**의존성**: 모든 이전 단계 완료 필수

> CloudWatch Composite Alarm + Step Functions + EventBridge + Route53 Failover Record 배포.
> 이 모듈 apply 완료 시점부터 자동 Failover가 활성화됨.

`dr/failover/terraform.tfvars`에서 알림 이메일 설정 확인:

```hcl
alarm_sns_email = "your-team@example.com"
```

```bash
cd dr/failover
terraform init && terraform apply --auto-approve
```

---

## ECR 기존 이미지 수동 Sync (Failover 테스트 전 필수)

ECR Replication은 설정 이후 push된 이미지만 복제하므로, 기존 이미지는 수동으로 sync해야 합니다.

```bash
# 서비스 이미지 (users, history, chatbot, analysis, frontend)
# 에이전트 이미지 (analysis-agent, chatbot-agent, summary-agent)

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
SERVICES="users history chatbot analysis frontend analysis-agent chatbot-agent summary-agent"

for SERVICE in $SERVICES; do
  REPO="cdci-prd-${SERVICE}"
  MANIFEST=$(aws ecr batch-get-image \
    --repository-name $REPO \
    --image-ids imageTag=latest \
    --region ap-northeast-2 \
    --query 'images[0].imageManifest' --output text)

  aws ecr put-image \
    --repository-name $REPO \
    --image-tag latest \
    --image-manifest "$MANIFEST" \
    --region ap-northeast-1 2>/dev/null || echo "Skipped: $REPO"
done
```

---

## 삭제 순서 (역순)

```bash
cd dr/nat      && terraform destroy --auto-approve
cd dr/failover   && terraform destroy --auto-approve
cd dr/database   && terraform destroy --auto-approve
cd dr/compute    && terraform destroy --auto-approve
cd dr/agentcore  && terraform destroy --auto-approve
cd dr/s3-replication  && terraform destroy --auto-approve
cd dr/ecr-replication && terraform destroy --auto-approve
cd dr/foundation && terraform destroy --auto-approve
```

> S3 DR 버킷은 비어있어야 삭제 가능.
> ECR Replication 설정 삭제 후에도 도쿄 ECR 레포는 자동 삭제되지 않음 (수동 삭제 필요).
