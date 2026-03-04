# Codecaine Terraform Infrastructure

MSA 프로젝트를 위한 모듈화된 Terraform 인프라

## 구조

```
├── common/          # 비용 없음 - VPC, Subnets
├── igw/            # Internet Gateway
├── nat/            # NAT Gateway (비용 발생)
├── rds/            # RDS MySQL (비용 발생)
└── compute/        # Bastion Host (비용 발생)
```

## 배포 순서

### 1. Common (필수)
```bash
cd common
terraform init
terraform apply
```

### 2. IGW (Public 서브넷 인터넷 연결)
```bash
cd ../igw
terraform init
terraform apply
```

### 3. NAT (선택 - Private 서브넷 아웃바운드)
```bash
cd ../nat
terraform init
terraform apply
```

### 4. RDS (선택 - 데이터베이스)
```bash
cd ../rds
# terraform.tfvars에서 db_password 변경
terraform init
terraform apply
```

### 5. Compute (선택 - Bastion)
```bash
cd ../compute
# terraform.tfvars에서 key_name, my_ip 변경
terraform init
terraform apply
```

## 네트워크 구성

- **Region**: ap-northeast-2 (서울)
- **AZs**: ap-northeast-2a, ap-northeast-2c
- **VPC CIDR**: 10.0.0.0/16
- **Public Subnets**: 10.0.0.0/24, 10.0.1.0/24
- **Private Subnets**: 10.0.10.0/24, 10.0.11.0/24
- **Private DB Subnets**: 10.0.20.0/24, 10.0.21.0/24

## 비용 관리

필요한 리소스만 배포하고 사용하지 않을 때는 삭제:

```bash
cd <folder>
terraform destroy
```

## 주의사항

- Common은 다른 모듈의 의존성이므로 마지막에 삭제
- RDS 삭제시 데이터 백업 확인
- NAT Gateway는 시간당 과금
