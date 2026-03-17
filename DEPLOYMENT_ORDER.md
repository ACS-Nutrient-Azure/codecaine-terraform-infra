# Terraform 모듈 배포 순서

## 의존성 그래프

```
foundation ──────────────────────────────────────────────┐
    │                                                     │
    ├─→ nat                                               │
    │                                                     ▼
ecr (독립)                                           database-rds
    │                                                     
s3-buckets (독립)                                    
    │                                                     
    ├─→ security (foundation + s3-buckets)                
    │                                                     
    └─→ compute (foundation + ecr + s3-buckets)           

storage (독립 - GitHub OIDC IAM만 관리)
```

---

## 배포 순서

### Step 1 — foundation
**의존성**: 없음

```bash
cd foundation && terraform init && terraform apply
```

---

### Step 2 — nat, ecr, s3-buckets, storage (병렬 가능)
**의존성**: nat → foundation / 나머지 독립

```bash
cd nat          && terraform init && terraform apply
cd ecr          && terraform init && terraform apply
cd s3-buckets   && terraform init && terraform apply
cd storage      && terraform init && terraform apply
```

> `nat`은 foundation 완료 후 실행. 나머지 3개는 순서 무관.

---

### Step 3 — security, database-rds (병렬 가능)
**의존성**: security → foundation + s3-buckets / database-rds → foundation

```bash
cd security      && terraform init && terraform apply
cd database-rds  && terraform init && terraform apply
```

> security apply 완료 후 `acm_certificate_arn`, `route53_zone_id` output을 `compute/terraform.tfvars`에 입력.

---

### Step 4 — compute
**의존성**: foundation + ecr + s3-buckets (모두 완료 필요)

```bash
# ECR에 이미지 푸시 먼저
# compute/terraform.tfvars에 certificate_arn, route53_zone_id 입력 후
cd compute && terraform init && terraform apply
```

---

## 삭제 순서 (역순)

```bash
cd compute       && terraform destroy
cd database-rds  && terraform destroy
cd security      && terraform destroy
cd storage       && terraform destroy
cd s3-buckets    && terraform destroy   # 버킷 비운 후 실행
cd ecr           && terraform destroy
cd nat           && terraform destroy
cd foundation    && terraform destroy
```

> S3 버킷(ALB Logs, CloudTrail)은 비어있어야 삭제 가능.  
> Secrets Manager 삭제 후 복구 대기 기간(기본 7일) 있음.

---

## compute 배포 전 체크리스트

- [ ] `security` apply 완료 → `certificate_arn`, `route53_zone_id` 확인
- [ ] `ecr` apply 완료 → 각 서비스 이미지 ECR 푸시 완료
- [ ] `s3-buckets` apply 완료
- [ ] `compute/terraform.tfvars`에 `certificate_arn`, `route53_zone_id` 입력
- [ ] `bastion_key_name` 키 페어 존재 확인
- [ ] `bastion_allowed_cidrs`에 현재 IP 추가

```bash
# security outputs 확인
terraform -chdir=security output acm_certificate_arn
terraform -chdir=security output route53_zone_id
```
