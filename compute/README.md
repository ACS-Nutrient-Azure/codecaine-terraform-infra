# ECS Compute Cluster (독립 실행 가능)

ECS Fargate 기반 컨테이너 클러스터를 독립적으로 배포할 수 있는 모듈입니다.

## 특징

- **독립 실행**: 자체 VPC, 서브넷, 보안 그룹 생성
- **선택적 통합**: 기존 VPC 사용 가능
- **완전한 ECS 스택**: ALB, Auto Scaling, CloudWatch 포함
- **Bastion Host**: 안전한 SSH 접근

## 실행 모드

### 1. 독립 실행 모드 (권장)

새로운 VPC와 네트워크 리소스를 생성합니다.

```hcl
# terraform.tfvars
use_existing_vpc = false
use_existing_ecr = false

vpc_cidr                 = "10.0.0.0/16"
availability_zones       = ["ap-northeast-2a", "ap-northeast-2c"]
public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
enable_nat_gateway       = true
```

**생성되는 리소스:**
- VPC (10.0.0.0/16)
- Public Subnets × 2 (ALB용)
- Private Subnets × 2 (ECS 태스크용)
- Internet Gateway
- NAT Gateway × 2 (고가용성)
- 보안 그룹 (ALB, ECS Tasks)
- ECR Repository
- ECS Cluster
- Application Load Balancer
- Auto Scaling

### 2. 기존 VPC 사용 모드 (권장)

foundation 모듈의 VPC를 사용합니다. 새 VPC를 생성하지 않습니다.

```hcl
# terraform.tfvars
use_existing_vpc = true

# foundation 모듈의 VPC 리소스를 자동으로 참조
# 별도의 VPC ID나 Subnet ID 지정 불필요

use_existing_ecr            = true
existing_ecr_repository_url = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/cdci-prd"
```

**생성되는 리소스:**
- ECS Cluster
- Application Load Balancer
- Auto Scaling
- Bastion Host
- CODEF API S3 버킷 (cdci-prd-codef-data)

## 빠른 시작

### 1. 설정 파일 준비

```bash
# 예제 파일 복사
cp terraform.tfvars.example terraform.tfvars

# 설정 편집
vim terraform.tfvars

# 기존 VPC 사용 설정 (권장)
use_existing_vpc = true
```

### 2. SSH 키 준비 (Bastion용)

기존 EC2 키 페어를 사용합니다 (예: tera-test.pem).

```bash
# AWS 콘솔에서 키 페어가 이미 생성되어 있어야 합니다
# 또는 AWS CLI로 확인:
aws ec2 describe-key-pairs --key-names codecaine

# terraform.tfvars에 키 이름 설정
bastion_key_name = "codecaine"
```

### 3. Terraform 실행

```bash
terraform init
terraform plan
terraform apply
```

### 4. 출력 확인

```bash
# ALB DNS 이름
terraform output alb_dns_name

# ECR Repository URL
terraform output ecr_repository_url

# Bastion Public IP
terraform output bastion_public_ip
```

## 애플리케이션 배포

### 1. Docker 이미지 빌드 및 푸시

```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url)

# 이미지 빌드
docker build -t myapp:latest .

# 태그 지정
docker tag myapp:latest $(terraform output -raw ecr_repository_url):latest

# 푸시
docker push $(terraform output -raw ecr_repository_url):latest
```

### 2. ECS 서비스 업데이트

```bash
# 새 태스크 정의로 서비스 업데이트
aws ecs update-service \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --service $(terraform output -raw ecs_service_name) \
  --force-new-deployment
```

### 3. 배포 확인

```bash
# 서비스 상태 확인
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name)

# 태스크 목록
aws ecs list-tasks \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --service-name $(terraform output -raw ecs_service_name)
```

## Bastion Host 사용

### SSH 접속

```bash
# tera-test.pem 키를 사용하여 접속
ssh -i ~/.ssh/tera-test.pem ec2-user@$(terraform output -raw bastion_public_ip)
```

### ECS Exec (컨테이너 디버깅)

```bash
# ECS Exec 활성화 확인 (terraform.tfvars에서 enable_ecs_exec = true)

# 실행 중인 태스크 ID 확인
TASK_ID=$(aws ecs list-tasks \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --service-name $(terraform output -raw ecs_service_name) \
  --query 'taskArns[0]' --output text | cut -d'/' -f3)

# 컨테이너 접속
aws ecs execute-command \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --task $TASK_ID \
  --container app \
  --interactive \
  --command "/bin/sh"
```

## 모니터링

### CloudWatch Logs

```bash
# 로그 스트림 확인
aws logs tail /ecs/myapp-prd --follow
```

### Container Insights (활성화 시)

```bash
# terraform.tfvars에서 enable_container_insights = true 설정
# CloudWatch Console > Container Insights에서 확인
```

### 메트릭 확인

```bash
# CPU 사용률
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=$(terraform output -raw ecs_service_name) \
              Name=ClusterName,Value=$(terraform output -raw ecs_cluster_name) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## Auto Scaling

Auto Scaling은 다음 메트릭을 기반으로 자동 조정됩니다:

1. **CPU 사용률**: 70% 목표
2. **메모리 사용률**: 80% 목표
3. **요청 수**: 1000 req/target 목표

### 수동 스케일링

```bash
# Desired count 변경
aws ecs update-service \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --service $(terraform output -raw ecs_service_name) \
  --desired-count 3
```

## 비용 최적화

### 프로덕션 환경

```hcl
# terraform.tfvars
enable_nat_gateway        = true   # 고가용성
enable_container_insights = true   # 모니터링
log_retention_days        = 30     # 충분한 로그 보관
task_cpu                  = "512"  # 적절한 리소스
task_memory               = "1024"
desired_count             = 2      # 최소 2개 인스턴스
min_capacity              = 2
max_capacity              = 10
```

**예상 비용**: ~$150-200/월 (트래픽에 따라 변동)

### 개발 환경

```hcl
# terraform.tfvars
enable_nat_gateway        = false  # NAT Gateway 비용 절감
enable_container_insights = false  # CloudWatch 비용 절감
log_retention_days        = 3      # 로그 보관 기간 단축
task_cpu                  = "256"  # 최소 리소스
task_memory               = "512"
desired_count             = 1      # 최소 인스턴스
```

**예상 비용**: ~$20-30/월

## 보안

### 네트워크 보안

- ALB: 인터넷에서 80/443 포트만 허용
- ECS Tasks: ALB에서만 트래픽 허용
- Bastion: 지정된 IP에서만 SSH 허용

### IAM 권한

- Task Execution Role: ECR, CloudWatch Logs 접근
- Task Role: 애플리케이션별 권한 (필요시 추가)

### 암호화

- ECR: AES256 암호화
- EBS: 암호화 활성화
- ALB: TLS 1.3 지원

## 트러블슈팅

### 태스크가 시작되지 않음

```bash
# 태스크 실패 이유 확인
aws ecs describe-tasks \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --tasks <task-id>

# 일반적인 원인:
# 1. ECR 이미지 없음 → 이미지 푸시 확인
# 2. 메모리 부족 → task_memory 증가
# 3. 헬스체크 실패 → health_check_path 확인
```

### ALB 헬스체크 실패

```bash
# 타겟 그룹 상태 확인
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# 해결 방법:
# 1. 애플리케이션이 health_check_path에 응답하는지 확인
# 2. 컨테이너 포트가 올바른지 확인
# 3. 보안 그룹 규칙 확인
```

### NAT Gateway 비용 절감

```bash
# VPC Endpoints 사용 (NAT Gateway 대신)
# network.tf에 추가:

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.cluster[0].id
  service_name = "com.amazonaws.ap-northeast-2.s3"
  route_table_ids = aws_route_table.private_app[*].id
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.cluster[0].id
  service_name        = "com.amazonaws.ap-northeast-2.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
}
```

## 변수 참조

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `use_existing_vpc` | 기존 VPC 사용 여부 | `false` |
| `vpc_cidr` | VPC CIDR 블록 | `10.0.0.0/16` |
| `enable_nat_gateway` | NAT Gateway 활성화 | `true` |
| `task_cpu` | 태스크 CPU (256, 512, 1024, 2048, 4096) | `256` |
| `task_memory` | 태스크 메모리 (MB) | `512` |
| `desired_count` | 원하는 태스크 수 | `1` |
| `min_capacity` | 최소 태스크 수 | `1` |
| `max_capacity` | 최대 태스크 수 | `4` |
| `enable_container_insights` | Container Insights 활성화 | `false` |
| `enable_ecs_exec` | ECS Exec 활성화 | `false` |

전체 변수 목록은 `variables.tf`를 참조하세요.

## 출력 값

| 출력 | 설명 |
|------|------|
| `alb_dns_name` | ALB DNS 이름 |
| `ecr_repository_url` | ECR Repository URL |
| `ecs_cluster_name` | ECS 클러스터 이름 |
| `bastion_public_ip` | Bastion 공개 IP |
| `vpc_id` | VPC ID |

전체 출력 목록은 `outputs.tf`를 참조하세요.

## 관련 문서

- [CLUSTER_INDEPENDENCE_GUIDE.md](../CLUSTER_INDEPENDENCE_GUIDE.md) - 독립 실행 상세 가이드
- [DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md) - 전체 배포 가이드
