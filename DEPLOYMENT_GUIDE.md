# 배포 가이드

## 사전 준비

### 1. AWS CLI 설정
```bash
aws configure
# AWS Access Key ID
# AWS Secret Access Key
# Default region: ap-northeast-2
```

### 2. Terraform 설치
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### 3. 도메인 준비
- Route53에 도메인 등록 또는 기존 Zone ID 확인
- 도메인이 없으면 임시로 ALB DNS 사용 가능

## 초기 배포 (전체)

### Step 1: Foundation
```bash
cd foundation
terraform init
terraform plan
terraform apply -auto-approve
```

**확인사항**:
- VPC ID 출력 확인
- Subnet IDs 출력 확인
- Security Group IDs 출력 확인

### Step 2: Storage (ECR)
```bash
cd ../storage
# terraform.tfvars 수정
vi terraform.tfvars
# github_repo = "your-org/your-repo"

terraform init
terraform plan
terraform apply -auto-approve
```

**확인사항**:
- ECR Repository URL 출력 확인
- GitHub Actions Role ARN 출력 확인 (GitHub Secrets에 저장)

### Step 3: Security
```bash
cd ../security
# terraform.tfvars 수정
vi terraform.tfvars
# domain_name = "example.com"
# route53_zone_id = "Z1234567890ABC" (기존 Zone 사용시)

terraform init
terraform plan
terraform apply -auto-approve
```

**확인사항**:
- ACM 인증서 발급 대기 (5-30분)
- WAF Web ACL 생성 확인
- Cognito User Pool 생성 확인

**ACM 인증서 검증**:
```bash
# 인증서 상태 확인
aws acm describe-certificate \
  --certificate-arn <certificate-arn> \
  --query 'Certificate.Status'
```

### Step 4: NAT Gateway (선택)
```bash
cd ../nat
terraform init
terraform plan
terraform apply -auto-approve
```

**비용**: ~$32/month (1개), ~$64/month (2개)

**Skip 조건**:
- Public 서브넷에서 ECS 실행 (비권장)
- VPC Endpoints 사용 (ECR, S3, DynamoDB)

### Step 5: Database
```bash
cd ../database
terraform init
terraform plan
terraform apply -auto-approve
```

**확인사항**:
- RDS 인스턴스 생성 대기 (10-15분)
- Secrets Manager에 비밀번호 저장 확인

**비밀번호 조회**:
```bash
aws secretsmanager get-secret-value \
  --secret-id cdci-prd-users-cluster-password \
  --query SecretString --output text | jq .
```

### Step 6: 컨테이너 이미지 빌드 및 푸시
```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 빌드 (예제)
cat > Dockerfile <<EOF
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
HEALTHCHECK CMD wget -q --spider http://localhost/health || exit 1
EOF

cat > index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>Hello ECS</title></head>
<body><h1>Hello from ECS!</h1></body>
</html>
EOF

# 빌드 및 푸시
docker build -t myapp:latest .
docker tag myapp:latest <ecr-url>:latest
docker push <ecr-url>:latest
```

### Step 7: Compute (ECS, ALB)
```bash
cd ../compute
# terraform.tfvars 수정
vi terraform.tfvars
# container_port = 80 (nginx 예제)
# health_check_path = "/"

terraform init
terraform plan
terraform apply -auto-approve
```

**확인사항**:
- ECS Service 생성 확인
- ALB Target Group Healthy 확인
- Route53 레코드 생성 확인

**서비스 확인**:
```bash
# ECS Service 상태
aws ecs describe-services \
  --cluster myapp-prd-cluster \
  --services myapp-prd-service

# Target Group Health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# 웹 접속
curl https://prd.example.com
```

## 개발 환경 배포 (최소 비용)

### 최소 구성
```bash
# 1. Foundation (필수)
cd foundation && terraform apply -auto-approve

# 2. Storage (필수)
cd ../storage && terraform apply -auto-approve

# 3. Security (ACM만)
cd ../security
# terraform.tfvars에서 enable_waf = false, enable_cognito = false
terraform apply -auto-approve

# 4. Compute (Public 서브넷 사용)
cd ../compute
# main.tf에서 subnets를 public_subnet_ids로 변경
# assign_public_ip = true
terraform apply -auto-approve
```

**비용**: ~$20/month (ALB + ECS 1 task)

## 업데이트 배포

### 코드 변경 후 배포
```bash
# 1. 이미지 빌드 및 푸시
docker build -t myapp:v2 .
docker tag myapp:v2 <ecr-url>:latest
docker push <ecr-url>:latest

# 2. ECS Service 업데이트
aws ecs update-service \
  --cluster myapp-prd-cluster \
  --service myapp-prd-service \
  --force-new-deployment

# 3. 배포 상태 확인
aws ecs describe-services \
  --cluster myapp-prd-cluster \
  --services myapp-prd-service \
  --query 'services[0].deployments'
```

### Terraform 변경 후 배포
```bash
cd <module>
terraform plan
terraform apply
```

## 모니터링

### CloudWatch Logs
```bash
# 실시간 로그
aws logs tail /ecs/myapp-prd --follow

# 에러 로그 필터
aws logs filter-log-events \
  --log-group-name /ecs/myapp-prd \
  --filter-pattern "ERROR"
```

### CloudWatch Metrics
```bash
# ECS CPU 사용률
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=myapp-prd-cluster Name=ServiceName,Value=myapp-prd-service \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### ECS Exec (컨테이너 접속)
```bash
# Task ID 조회
aws ecs list-tasks \
  --cluster myapp-prd-cluster \
  --service-name myapp-prd-service

# 컨테이너 접속
aws ecs execute-command \
  --cluster myapp-prd-cluster \
  --task <task-id> \
  --container myapp-prd \
  --interactive \
  --command "/bin/sh"
```

## 트러블슈팅

### ECS Task가 시작되지 않음

**원인 1: ECR 이미지 없음**
```bash
# ECR 이미지 확인
aws ecr describe-images \
  --repository-name myapp-prd
```

**원인 2: NAT Gateway 없음 (Private 서브넷)**
```bash
# NAT Gateway 배포
cd nat && terraform apply
```

**원인 3: Security Group 문제**
```bash
# Security Group 규칙 확인
aws ec2 describe-security-groups \
  --group-ids <ecs-tasks-sg-id>
```

### Health Check 실패

**원인 1: Health Check Path 오류**
```bash
# Target Group Health Check 설정 확인
aws elbv2 describe-target-groups \
  --target-group-arns <target-group-arn>

# 컨테이너 내부에서 테스트
curl http://localhost:8080/health
```

**원인 2: Container Port 불일치**
```bash
# Task Definition 확인
aws ecs describe-task-definition \
  --task-definition myapp-prd
```

### 503 에러

**원인: Healthy Target 없음**
```bash
# Target Health 확인
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# ECS Service 이벤트 확인
aws ecs describe-services \
  --cluster myapp-prd-cluster \
  --services myapp-prd-service \
  --query 'services[0].events[0:10]'
```

## 삭제

### 전체 삭제
```bash
# 역순으로 삭제
cd compute && terraform destroy -auto-approve
cd ../database && terraform destroy -auto-approve
cd ../nat && terraform destroy -auto-approve
cd ../security && terraform destroy -auto-approve
cd ../storage && terraform destroy -auto-approve
cd ../foundation && terraform destroy -auto-approve
```

### 비용 발생 리소스만 삭제 (개발 중단시)
```bash
cd compute && terraform destroy -auto-approve
cd ../database && terraform destroy -auto-approve
cd ../nat && terraform destroy -auto-approve
```

**주의사항**:
- RDS 삭제시 데이터 백업 필수
- Production 환경에서는 deletion_protection 활성화
- ALB 삭제 보호 활성화시 먼저 비활성화 필요

## GitHub Actions 설정

### 1. Secrets 설정
```
AWS_ROLE_ARN: <github-actions-role-arn>
```

### 2. Workflow 파일 생성
`.github/workflows/deploy.yml` 참조

### 3. 배포 테스트
```bash
git add .
git commit -m "Deploy to ECS"
git push origin main
```

## 비용 최적화

### 개발 환경
- ECS: Fargate Spot 사용 (최대 70% 할인)
- RDS: db.t3.micro, Single-AZ
- NAT: 1개만 사용
- 사용하지 않을 때 삭제

### 프로덕션 환경
- ECS: Fargate Savings Plans (최대 50% 할인)
- RDS: Reserved Instances (최대 72% 할인)
- NAT: 2개 (고가용성)
- CloudWatch Logs: 보관 기간 최소화

## 다음 단계

1. **CI/CD 파이프라인**: GitHub Actions 완성
2. **모니터링**: CloudWatch Dashboard 구성
3. **알림**: SNS + CloudWatch Alarms
4. **백업**: RDS 자동 백업, DynamoDB PITR
5. **보안**: WAF 규칙 커스터마이징
6. **성능**: CloudFront CDN 추가
7. **로깅**: ELK Stack 또는 CloudWatch Insights
