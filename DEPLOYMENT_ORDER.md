# Terraform 모듈 배포 순서

## 의존성 그래프

```
foundation
    │
    ├─→ nat                  (foundation remote state 참조)
    ├─→ database-rds         (foundation remote state 참조)
    ├─→ database-rds-single  (독립 - 하드코딩된 VPC/SG, 테스트용)
    └─→ security             (foundation remote state 참조)

ecr        (독립)
s3-buckets (독립)
storage    (독립 - GitHub Actions OIDC/IAM)

compute    (foundation + ecr + s3-buckets + security remote state 참조)
           └─→ analysis-agent remote state 참조 (AGENTCORE_RUNTIME_ARN 환경변수)

agentcore/provisioner      (독립)
agentcore/analysis-agent   (ecr + provisioner remote state 참조)
agentcore/chatbot-agent    (ecr + provisioner remote state 참조)
agentcore/supervisor-agent (ecr + provisioner + analysis-agent + chatbot-agent remote state 참조)

dms  (database-rds Secrets Manager 생성 후 실행)
```

---

## 배포 순서

### Step 1 — foundation
**의존성**: 없음

```cmd
cd foundation
terraform init
terraform apply --auto-approve
```

---

### Step 2 — nat, ecr, s3-buckets, storage (병렬 가능)
**의존성**: nat → foundation / 나머지 독립

```cmd
cd nat        && terraform init && terraform apply --auto-approve
cd ecr        && terraform init && terraform apply --auto-approve
cd s3-buckets && terraform init && terraform apply --auto-approve
cd storage    && terraform init && terraform apply --auto-approve
```

---

### Step 3 — security, database-rds (병렬 가능)
**의존성**: security → foundation / database-rds → foundation

```cmd
cd security     && terraform init && terraform apply --auto-approve
cd database-rds && terraform init && terraform apply --auto-approve
```

> security apply 완료 후 ACM certificate ARN, Route53 Zone ID output 확인 필요.
> database-rds-single은 테스트 목적 시에만 별도 실행 (database-rds와 동시 apply 금지 — Secrets Manager 이름 충돌).

---

### Step 4 — agentcore/provisioner
**의존성**: 없음 (독립)

```cmd
cd agentcore\provisioner
terraform init
terraform apply --auto-approve
```

> AgentCore Runtime 생성용 Lambda + IAM role 배포.
> 이후 에이전트 모듈들이 이 Lambda를 호출해 Runtime을 생성함.

---

### Step 5 — agentcore 에이전트 (순서 중요)
**의존성**: provisioner 완료 필수 / supervisor는 analysis + chatbot 완료 필수

```cmd
cd agentcore\analysis-agent   && terraform init && terraform apply --auto-approve
cd agentcore\chatbot-agent    && terraform init && terraform apply --auto-approve
cd agentcore\supervisor-agent && terraform init && terraform apply --auto-approve
```

> ECR에 이미지가 없으면 Runtime 생성을 건너뜀 (skipped).
> 이미지 push 후 `-replace=aws_lambda_invocation.agentcore_runtime`으로 재실행 필요.
> 자세한 내용은 `agentcore/README.md` 참조.

---

### Step 6 — compute
**의존성**: foundation + ecr + s3-buckets + security + analysis-agent 모두 완료 필요

```cmd
cd compute
terraform init
terraform apply --auto-approve
```

> ECR에 각 서비스 이미지 푸시 완료 후 실행.
> analysis-agent Runtime ARN을 환경변수로 주입하므로 analysis-agent 먼저 배포 필요.

---

### Step 7 — dms (독립, 순서 무관)

```cmd
cd dms
terraform init
terraform apply --auto-approve
```

> dms는 database-rds apply 완료 후 Secrets Manager에 시크릿이 생성된 뒤 실행.

---

## 삭제 순서 (역순)

```cmd
cd dms                              && terraform destroy --auto-approve
cd compute                          && terraform destroy --auto-approve
cd agentcore\supervisor-agent       && terraform destroy --auto-approve
cd agentcore\chatbot-agent          && terraform destroy --auto-approve
cd agentcore\analysis-agent         && terraform destroy --auto-approve
cd agentcore\provisioner            && terraform destroy --auto-approve
cd database-rds                     && terraform destroy --auto-approve
cd security                         && terraform destroy --auto-approve
cd storage                          && terraform destroy --auto-approve
cd s3-buckets                       && terraform destroy --auto-approve
cd ecr                              && terraform destroy --auto-approve
cd nat                              && terraform destroy --auto-approve
cd foundation                       && terraform destroy --auto-approve
```

> S3 버킷은 비어있어야 삭제 가능.
> Secrets Manager는 recovery_window_in_days = 0으로 즉시 삭제 설정됨.
> database-rds-single 사용 시: database-rds destroy 전에 먼저 destroy.

---

## compute 배포 전 체크리스트

- [ ] `security` apply 완료 → `acm_certificate_arn`, `route53_zone_id` output 확인
- [ ] `ecr` apply 완료 → 각 서비스 이미지 ECR 푸시 완료
- [ ] `s3-buckets` apply 완료
- [ ] `agentcore/analysis-agent` apply 완료 → Runtime ARN output 확인
- [ ] `bastion_key_name` 키 페어 존재 확인
- [ ] `bastion_allowed_cidrs`에 현재 IP 추가

```cmd
terraform -chdir=security output acm_certificate_arn
terraform -chdir=security output route53_zone_id
terraform -chdir=agentcore/analysis-agent output agentcore_runtime_arn
```
