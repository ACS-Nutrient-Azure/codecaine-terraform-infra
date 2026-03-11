# Foundation Infrastructure

변화 없는 기본 인프라 리소스 (비용 무료/최소)

## 포함 리소스

- VPC
- Internet Gateway
- Public Subnets (ALB용)
- Private App Subnets (ECS Tasks용)
- Private DB Subnets (RDS용)
- Route Tables
- Security Groups (ALB, ECS, RDS, VPC Endpoints)
- DB Subnet Group

## 배포

```bash
cd foundation
terraform init
terraform plan
terraform apply
```

## 주의사항

- 다른 모든 모듈의 기반이 되므로 가장 먼저 배포
- 삭제는 모든 의존 리소스 삭제 후 마지막에 수행
