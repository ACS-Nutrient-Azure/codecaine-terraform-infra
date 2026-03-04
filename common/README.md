# Common Infrastructure

비용이 들지 않는 필수 인프라 구성

## 포함된 리소스

- VPC
- Subnets (Public x2, Private x2, Private DB x2)
- DB Subnet Group

## 서브넷 구성

- **Public Subnets**: 10.0.0.0/24, 10.0.1.0/24 (ap-northeast-2a, 2c)
- **Private Subnets**: 10.0.10.0/24, 10.0.11.0/24 (ap-northeast-2a, 2c)
- **Private DB Subnets**: 10.0.20.0/24, 10.0.21.0/24 (ap-northeast-2a, 2c)

## 배포

```bash
terraform init
terraform plan
terraform apply
```

## 비용이 발생하는 리소스

다음 리소스들은 별도 폴더로 분리되어 필요시 배포:
- Internet Gateway
- NAT Gateway
- RDS
- EC2 인스턴스
- ALB
