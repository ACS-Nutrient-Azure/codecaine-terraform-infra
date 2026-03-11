# 네이밍 규칙 (Naming Convention)

CodeCaine 팀의 AWS 리소스 네이밍 표준

## 기본 원칙

모든 AWS 리소스는 **CDCI** (CodeCaine 약어)로 시작하는 일관된 네이밍을 따릅니다.

## 네이밍 패턴

```
CDCI-{ENVIRONMENT}-{RESOURCE_TYPE}-{DETAIL}
```

### 구성 요소

1. **CDCI**: CodeCaine 팀 약어 (고정)
2. **ENVIRONMENT**: 환경 코드
   - `PRD`: 프로덕션 환경
   - `STG`: 스테이징 환경
   - `DEV`: 개발 환경
3. **RESOURCE_TYPE**: AWS 리소스 타입
4. **DETAIL**: 추가 상세 정보 (선택)

## 리소스별 네이밍 예시

### VPC & Network
```
CDCI-PRD-VPC                          # VPC
CDCI-PRD-IGW                          # Internet Gateway
CDCI-PRD-VPC-PUBLIC-2A                # Public Subnet (AZ 2a)
CDCI-PRD-VPC-PUBLIC-2C                # Public Subnet (AZ 2c)
CDCI-PRD-VPC-PRIVATE-APP-2A           # Private App Subnet (AZ 2a)
CDCI-PRD-VPC-PRIVATE-APP-2C           # Private App Subnet (AZ 2c)
CDCI-PRD-VPC-PRIVATE-DB-2A            # Private DB Subnet (AZ 2a)
CDCI-PRD-VPC-PRIVATE-DB-2C            # Private DB Subnet (AZ 2c)
CDCI-PRD-PUBLIC-RT                    # Public Route Table
CDCI-PRD-PRIVATE-APP-RT-2A            # Private App Route Table (AZ 2a)
CDCI-PRD-PRIVATE-DB-RT                # Private DB Route Table
```

### Security Groups
```
CDCI-PRD-ALB-SG                       # ALB Security Group
CDCI-PRD-ECS-TASKS-SG                 # ECS Tasks Security Group
CDCI-PRD-RDS-SG                       # RDS Security Group
CDCI-PRD-BASTION-SG                   # Bastion Security Group
CDCI-PRD-VPCE-SG                      # VPC Endpoints Security Group
```

### Compute (ECS)
```
CDCI-PRD-ECS-CLUSTER                  # ECS Cluster
CDCI-PRD-ECS-SERVICE                  # ECS Service
CDCI-PRD-ECS-TASK-DEF                 # ECS Task Definition
CDCI-PRD-ECS-TASK-ROLE                # ECS Task Role
CDCI-PRD-ECS-TASK-EXECUTION-ROLE      # ECS Task Execution Role
CDCI-PRD-ECS-LOGS                     # CloudWatch Log Group
```

### Load Balancer
```
CDCI-PRD-ALB                          # Application Load Balancer
CDCI-PRD-TG                           # Target Group
```

### Bastion
```
CDCI-PRD-BASTION                      # Bastion EC2 Instance
CDCI-PRD-BASTION-SG                   # Bastion Security Group
CDCI-PRD-BASTION-EIP                  # Bastion Elastic IP
CDCI-PRD-BASTION-ROLE                 # Bastion IAM Role
CDCI-PRD-BASTION-PROFILE              # Bastion Instance Profile
```

### NAT Gateway
```
CDCI-PRD-NAT-GW                       # NAT Gateway
CDCI-PRD-NAT-EIP                      # NAT Elastic IP
```

### Database
```
CDCI-PRD-DB-SUBNET-GROUP              # DB Subnet Group
CDCI-PRD-AURORA-CLUSTER-PARAMS        # Aurora Cluster Parameter Group
CDCI-PRD-AURORA-PARAMS                # Aurora Instance Parameter Group

# Aurora Clusters
cdci-prd-users-cluster                # 사용자 데이터 클러스터
cdci-prd-history-cluster              # 히스토리 데이터 클러스터
cdci-prd-analysis-cluster             # 분석 데이터 클러스터

# Aurora Instances
cdci-prd-users-cluster-wo             # Writer 인스턴스
cdci-prd-users-cluster-ro             # Reader 인스턴스
cdci-prd-history-cluster-wo           # Writer 인스턴스
cdci-prd-history-cluster-ro           # Reader 인스턴스
cdci-prd-analysis-cluster-wo          # Writer 인스턴스
cdci-prd-analysis-cluster-ro          # Reader 인스턴스

# DynamoDB
cdci-prd-ChatbotData                  # DynamoDB 테이블
```

### Security (Route53, ACM)
```
CDCI-PRD-ROUTE53-ZONE                 # Route53 Hosted Zone
CDCI-PRD-ACM-CERT                     # ACM Certificate
```

### Storage
```
cdci-prd                              # ECR Repository (소문자)
CDCI-PRD-GITHUB-OIDC                  # GitHub OIDC Provider
CDCI-PRD-GITHUB-ACTIONS-ROLE          # GitHub Actions IAM Role
cdci-prd-codef-data                   # CODEF API S3 버킷
```

## Terraform 설정

### terraform.tfvars
```hcl
project_name = "cdci"  # CodeCaine 팀 약어
environment  = "prd"   # prd, stg, dev
region       = "ap-northeast-2"
```

### 리소스 태그 예시
```hcl
tags = {
  Name = "${upper(var.project_name)}-${upper(var.environment)}-VPC"
}
# 결과: CDCI-PRD-VPC
```

### 리소스 이름 예시 (소문자 필요한 경우)
```hcl
name = lower("${var.project_name}-${var.environment}-alb")
# 결과: cdci-prd-alb
```

## AWS 리소스 이름 제약사항

### 대문자 허용
- EC2 Instance (Tags)
- Security Group (Tags)
- VPC, Subnet (Tags)
- IAM Role
- CloudWatch Log Group

### 소문자만 허용
- S3 Bucket
- ECR Repository
- Load Balancer
- Target Group
- RDS Cluster/Instance
- DynamoDB Table

### 하이픈(-) 사용 불가
- S3 Bucket (일부 리전)

## 네이밍 규칙 적용 범위

✅ **적용 완료**
- foundation/ (VPC, Subnets, Security Groups)
- compute/ (ECS, ALB, Bastion)
- nat/ (NAT Gateway)
- security/ (Route53, ACM)
- storage/ (ECR, IAM)
- database-rds/ (Aurora)
- database-dynamodb/ (DynamoDB)

## 예외 사항

### 1. AWS 관리형 리소스
AWS가 자동으로 생성하는 리소스는 네이밍 규칙을 따르지 않습니다.
- ENI (Elastic Network Interface)
- EBS Volume
- CloudWatch Alarms (자동 생성)

### 2. 서드파티 통합
외부 서비스와 통합 시 해당 서비스의 네이밍 규칙을 따를 수 있습니다.
- GitHub Actions Secrets
- Datadog Tags

## 마이그레이션 가이드

기존 리소스를 새 네이밍 규칙으로 변경하려면:

### 1. Terraform State 백업
```bash
terraform state pull > backup.tfstate
```

### 2. 리소스 이름 변경
```bash
# terraform.tfvars 수정
project_name = "cdci"
```

### 3. 계획 확인
```bash
terraform plan
```

### 4. 적용
```bash
terraform apply
```

### 5. 주의사항
- 일부 리소스는 이름 변경 시 재생성됩니다 (다운타임 발생 가능)
- 프로덕션 환경은 점진적으로 변경하세요
- 의존성이 있는 리소스는 순서대로 변경하세요

## 참고 자료

- [AWS Tagging Best Practices](https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html)
- [Terraform Naming Conventions](https://www.terraform-best-practices.com/naming)
- [AWS Resource Naming Limits](https://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html)
