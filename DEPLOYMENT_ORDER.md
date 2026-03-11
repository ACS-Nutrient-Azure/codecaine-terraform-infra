# Terraform 모듈 배포 순서 가이드

## 🐛 분석 요약

전체 7개 Terraform 모듈의 의존성을 분석하여 순환 참조 없이 안전하게 배포할 수 있는 순서를 결정했습니다.

**분석 결과**: 순환 참조 없음 ✅  
**배포 모드**: 공유 인프라 모드 (foundation 기반)

---

## 📊 모듈별 의존성 맵

### 1. foundation (기반 네트워크)
**의존성**: 없음 (최상위 모듈)

**제공 리소스**:
- VPC, 서브넷 (Public, Private App, Private DB)
- 보안 그룹 (ALB, ECS Tasks, RDS, Bastion, VPC Endpoints)
- Route Tables (NAT Gateway 라우트 제외)
- DB Subnet Group
- VPC Flow Logs

**Outputs**:
```
vpc_id
public_subnet_ids
private_app_subnet_ids
private_db_subnet_ids
db_subnet_group_name
alb_security_group_id
ecs_tasks_security_group_id
rds_security_group_id
bastion_security_group_id
vpc_endpoints_security_group_id
private_app_route_table_ids
```

---

### 2. NAT Gateway (NAT Gateway)
**의존성**: foundation ⚠️

**참조 데이터**:
```terraform
data.terraform_remote_state.foundation.outputs.public_subnet_ids[0]
data.terraform_remote_state.foundation.outputs.private_app_route_table_id
```

**제공 리소스**:
- NAT Gateway (단일, Regional 구성, connectivity_type = "public")
- Elastic IP
- Private App Route Table에 NAT 라우트 추가

**주의사항**:
- foundation의 Route Table을 직접 수정 (aws_route 리소스)
- foundation 배포 완료 후 반드시 배포 필요
- 비용 최적화를 위한 단일 NAT Gateway 구성

---

### 3. security (보안 서비스)
**의존성**: foundation (선택적)

**참조 데이터**:
```terraform
data.terraform_remote_state.foundation.outputs.vpc_id  # VPC Flow Logs용
```

**제공 리소스**:
- Route53 Hosted Zone (선택적 생성)
- ACM Certificate (us-east-1, CloudFront용)
- WAF Web ACL (선택적)
- Cognito User Pool (선택적)
- AWS Config
- CloudTrail
- Shield Standard (자동 활성화)

**독립성**:
- foundation 없이도 배포 가능
- Route53, ACM, CloudTrail은 VPC 독립적

---

### 4. storage (컨테이너 레지스트리 & IAM)
**의존성**: foundation (선택적)

**참조 데이터**:
```terraform
data.terraform_remote_state.foundation  # 참조만 하고 실제 사용 안 함
```

**제공 리소스**:
- ECR Repository
- ECR Lifecycle Policy
- GitHub Actions OIDC Provider (선택적)
- GitHub Actions IAM Role (선택적)

**독립성**:
- foundation 참조를 선언했지만 실제로는 사용하지 않음
- 완전 독립 배포 가능

---

### 5. database-rds (Aurora PostgreSQL)
**의존성**: foundation ✅

**참조 데이터**:
```terraform
data.terraform_remote_state.foundation.outputs.vpc_id
data.terraform_remote_state.foundation.outputs.private_db_subnet_ids
data.terraform_remote_state.foundation.outputs.db_subnet_group_name
data.terraform_remote_state.foundation.outputs.rds_security_group_id
```

**제공 리소스**:
- Aurora PostgreSQL Cluster (3개: users-cluster, history-cluster, analysis-cluster)
- Aurora Cluster Instances (Writer: -wo, Reader: -ro 접미사)
- Aurora Global Database (선택적)
- Secrets Manager (DB 비밀번호 - 사용자 지정)
- CloudWatch Alarms

**주의사항**:
- foundation의 네트워크 리소스 필수
- NAT Gateway 없이도 배포 가능 (Private DB 서브넷)
- 비밀번호는 terraform.tfvars에서 직접 지정

---

### 6. database-dynamodb (DynamoDB)
**의존성**: 없음 (완전 독립)

**제공 리소스**:
- DynamoDB Tables (테이블명: ChatbotData, 실제: cdci-prd-ChatbotData)
- Global Tables (선택적)
- Auto Scaling (선택적)
- Point-in-Time Recovery (항상 활성화)

**독립성**:
- 어떤 모듈도 참조하지 않음
- 완전 독립 배포 가능

---

### 7. compute (ECS, ALB, Bastion)
**의존성**: foundation (필수), storage (조건부)

**VPC 설정**: use_existing_vpc = true (foundation VPC 사용)

**참조 데이터**:
```terraform
data.terraform_remote_state.foundation.outputs.vpc_id
data.terraform_remote_state.foundation.outputs.public_subnet_ids
data.terraform_remote_state.foundation.outputs.private_app_subnet_ids
data.terraform_remote_state.foundation.outputs.alb_security_group_id
data.terraform_remote_state.foundation.outputs.ecs_tasks_security_group_id
```

**참조 데이터** (use_existing_ecr = true):
```terraform
data.terraform_remote_state.storage.outputs.ecr_repository_url
```

**제공 리소스**:
- ECS Cluster
- ECS Service (Fargate)
- Application Load Balancer
- Target Group
- Bastion Host (EC2)
- CloudWatch Log Group
- IAM Roles (ECS Task Execution, ECS Task, Bastion)
- S3 Bucket (ALB Logs)
- S3 Bucket (CODEF API Data - cdci-prd-codef-data, 30일 후 자동 삭제)

**주의사항**:
- 기존 foundation VPC 사용 (새 VPC 생성 안 함)
- Bastion Host는 foundation의 public_subnet 사용
- NAT Gateway 필요 (ECS Tasks가 인터넷 접근 필요)
- CODEF S3 버킷: JSON 데이터 30일 보관 후 삭제

---

## 🚀 권장 배포 순서

### Phase 1: 기반 인프라 (필수)
```bash
# 1단계: VPC 및 네트워크 기반
cd foundation/
terraform init
terraform plan
terraform apply

# 2단계: NAT Gateway (Private 서브넷 인터넷 접근)
cd ../nat/
terraform init
terraform plan
terraform apply
```

**검증 포인트**:
- ✅ VPC, 서브넷, 보안 그룹 생성 확인
- ✅ NAT Gateway 생성 및 Private Route Table 업데이트 확인
- ✅ foundation outputs 확인: `terraform output -json`

**소요 시간**: 약 5-10분

---

### Phase 2: 독립 서비스 (병렬 배포 가능)

이 단계의 모듈들은 서로 의존성이 없어 **병렬로 배포 가능**합니다.

```bash
# 3-A단계: 보안 서비스 (Route53, ACM, WAF, Cognito, CloudTrail)
cd ../security/
terraform init
terraform plan
terraform apply

# 3-B단계: 컨테이너 레지스트리 (ECR, GitHub OIDC)
cd ../storage/
terraform init
terraform plan
terraform apply

# 3-C단계: DynamoDB (완전 독립)
cd ../database-dynamodb/
terraform init
terraform plan
terraform apply
```

**검증 포인트**:
- ✅ ACM Certificate 검증 완료 (DNS 레코드 자동 생성)
- ✅ ECR Repository 생성 확인
- ✅ DynamoDB Tables 생성 확인

**소요 시간**: 약 10-15분 (ACM 검증 대기 시간 포함)

---

### Phase 3: 데이터베이스 (foundation 의존)

```bash
# 4단계: Aurora PostgreSQL Clusters
cd ../database-rds/
terraform init
terraform plan
terraform apply
```

**검증 포인트**:
- ✅ Aurora Cluster 3개 생성 확인 (users-cluster, history-cluster, analysis-cluster)
- ✅ Writer 인스턴스 (-wo 접미사) 및 Reader 인스턴스 (-ro 접미사) 확인
- ✅ Secrets Manager에 비밀번호 저장 확인
- ✅ RDS 엔드포인트 접근 가능 확인 (Bastion 통해)

**소요 시간**: 약 15-20분 (Aurora Cluster 생성 시간)

**주의사항**:
- Aurora Cluster 생성은 시간이 오래 걸림
- Global Database 활성화 시 추가 시간 필요

---

### Phase 4: 컴퓨팅 (최종 단계)

```bash
# 5단계: ECS, ALB, Bastion
cd ../compute/
terraform init
terraform plan
terraform apply
```

**검증 포인트**:
- ✅ ECS Cluster 생성 확인
- ✅ ALB DNS 이름 확인
- ✅ Bastion Host 접근 가능 확인
- ✅ ECS Service 정상 실행 확인 (컨테이너 이미지 필요)
- ✅ CODEF API S3 버킷 생성 확인 (cdci-prd-codef-data)

**소요 시간**: 약 10-15분

**주의사항**:
- ECS Service 배포 전 ECR에 컨테이너 이미지 푸시 필요
- certificate_arn 변수 설정 시 security 모듈의 ACM ARN 사용

---

## ⚠️ 각 단계별 주의사항

### Phase 1 주의사항

#### foundation
- **CIDR 블록 충돌 방지**: `NETWORK_IP_CIDR_MAPPING.md` 참조
- **가용 영역 선택**: 리전별 사용 가능한 AZ 확인
- **VPC Flow Logs**: CloudWatch Logs 비용 발생

#### nat
- **비용 최적화**: 단일 NAT Gateway 사용 (고가용성 vs 비용)
- **Route Table 수정**: foundation의 Route Table을 직접 수정하므로 주의
- **의존성 확인**: foundation 배포 완료 후 실행

---

### Phase 2 주의사항

#### security
- **ACM 검증 대기**: DNS 검증 완료까지 5-10분 소요
- **Route53 도메인**: 기존 도메인 사용 시 `create_route53_zone = false`
- **WAF 비용**: 활성화 시 추가 비용 발생
- **Cognito**: 사용하지 않으면 `enable_cognito = false`

#### storage
- **ECR 이미지**: 배포 후 즉시 이미지 푸시 권장
- **GitHub OIDC**: GitHub Actions 사용 시에만 활성화
- **독립성**: foundation 참조를 선언했지만 실제로는 미사용

#### database-dynamodb
- **완전 독립**: 언제든지 배포 가능
- **Global Tables**: 다중 리전 사용 시에만 활성화
- **비용**: On-Demand vs Provisioned 모드 선택

---

### Phase 3 주의사항

#### database-rds
- **배포 시간**: Aurora Cluster 생성에 15-20분 소요
- **비밀번호 관리**: terraform.tfvars에서 직접 지정, Secrets Manager에 저장
- **클러스터 이름**: users-cluster, history-cluster, analysis-cluster
- **인스턴스 네이밍**: Writer (-wo), Reader (-ro) 접미사
- **Global Database**: 다중 리전 DR 필요 시에만 활성화
- **백업 설정**: 프로덕션 환경에서는 백업 활성화 필수
- **Bastion 접근**: RDS는 Private 서브넷에 있어 Bastion 필요

---

### Phase 4 주의사항

#### compute
- **VPC 설정**: use_existing_vpc = true (foundation VPC 사용)
- **컨테이너 이미지**: ECS Service 시작 전 ECR에 이미지 푸시 필수
- **ALB 인증서**: HTTPS 사용 시 security 모듈의 ACM ARN 필요
- **Bastion 키 페어**: 기존 키 페어 이름 지정 필요
- **NAT Gateway**: Private 서브넷의 ECS Tasks가 인터넷 접근 필요
- **CODEF S3 버킷**: cdci-prd-codef-data (30일 후 자동 삭제)

---

## 🔄 의존성 그래프

```
foundation (VPC, Subnets, Security Groups)
    │
    ├─→ nat (NAT Gateway) ⚠️ Route Table 수정
    │
    ├─→ security (Route53, ACM, WAF, Cognito) [선택적]
    │
    ├─→ storage (ECR, IAM) [선택적 참조]
    │
    ├─→ database-rds (Aurora PostgreSQL) ✅ 필수
    │
    └─→ compute (ECS, ALB, Bastion) ✅ 필수
         └─→ storage (ECR) [선택적]

database-dynamodb (완전 독립) 🔓
```

**범례**:
- ✅ 필수 의존성
- ⚠️ 리소스 수정 의존성
- 🔓 독립 모듈

---

## 🔍 잠재적 문제점 및 해결 방안

### 1. NAT Gateway Route Table 충돌
**문제**: nat 모듈이 foundation의 Route Table을 직접 수정

**증상**:
```
Error: resource already managed by another state
```

**해결 방안**:
- foundation 배포 완료 후 nat 배포
- nat 삭제 시 Route Table 정리 확인
- Terraform state 충돌 시 `terraform import` 사용

**예방**:
```bash
# foundation 배포 후 outputs 확인
cd foundation/
terraform output private_app_route_table_ids

# nat 배포 전 Route Table 상태 확인
aws ec2 describe-route-tables --route-table-ids <route-table-id>
```

---

### 2. ACM Certificate 검증 지연
**문제**: ACM Certificate DNS 검증 완료까지 5-10분 소요

**증상**:
```
Still creating... [5m0s elapsed]
```

**해결 방안**:
- Route53 Zone이 올바르게 설정되었는지 확인
- DNS 전파 대기 (최대 10분)
- 수동 검증: AWS Console에서 DNS 레코드 확인

**예방**:
```bash
# Route53 Zone 확인
aws route53 list-hosted-zones

# ACM Certificate 상태 확인
aws acm describe-certificate --certificate-arn <arn>
```

---

### 3. ECS Service 시작 실패
**문제**: ECR에 컨테이너 이미지가 없어 ECS Service 시작 실패

**증상**:
```
Error: service failed to start: task failed to start
```

**해결 방안**:
1. ECR에 이미지 푸시:
```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 빌드 및 푸시
docker build -t <project>-<env> .
docker tag <project>-<env>:latest <ecr-url>:latest
docker push <ecr-url>:latest
```

2. ECS Service 재배포:
```bash
cd compute/
terraform apply -replace=aws_ecs_service.app
```

**예방**:
- compute 배포 전 ECR에 이미지 푸시
- CI/CD 파이프라인 구축 (GitHub Actions)

---

### 4. Bastion Host 접근 불가
**문제**: Bastion Host에 SSH 접근 불가

**증상**:
```
ssh: connect to host <ip> port 22: Connection timed out
```

**해결 방안**:
1. 보안 그룹 확인:
```bash
# Bastion 보안 그룹 확인
aws ec2 describe-security-groups --group-ids <bastion-sg-id>
```

2. 허용 CIDR 확인:
```terraform
# compute/terraform.tfvars
bastion_allowed_cidrs = ["<your-ip>/32"]
```

3. 키 페어 확인:
```bash
# 키 페어 권한 설정
chmod 400 ~/.ssh/codecaine.pem

# SSH 접속
ssh -i ~/.ssh/codecaine.pem ec2-user@<bastion-ip>
```

**예방**:
- 배포 전 현재 IP 확인: `curl ifconfig.me`
- 키 페어 미리 생성: AWS Console > EC2 > Key Pairs

---

### 5. Aurora Cluster 생성 시간 초과
**문제**: Aurora Cluster 생성에 20분 이상 소요

**증상**:
```
Still creating... [20m0s elapsed]
```

**해결 방안**:
- 정상 동작: Aurora Cluster 생성은 15-25분 소요
- 타임아웃 증가:
```bash
export TF_CLI_ARGS_apply="-timeout=30m"
```

**예방**:
- 프로덕션 환경에서는 점심시간 등 여유 시간에 배포
- Global Database 비활성화로 시간 단축

---

### 6. Terraform State 충돌
**문제**: 여러 사용자가 동시에 배포 시 state 충돌

**증상**:
```
Error: Error acquiring the state lock
```

**해결 방안**:
1. 로컬 state 사용 시:
```bash
# 다른 사용자 배포 완료 대기
# 또는 force-unlock (주의!)
terraform force-unlock <lock-id>
```

2. 원격 state 사용 (권장):
```terraform
# backend.tf
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "foundation/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

**예방**:
- S3 + DynamoDB 백엔드 사용
- 배포 전 팀원과 조율

---

### 7. 순환 참조 위험 (현재 없음)
**현재 상태**: 순환 참조 없음 ✅

**잠재적 위험**:
- compute → security (ACM ARN)
- security → compute (ALB ARN for WAF)

**예방**:
- ACM ARN은 변수로 전달 (remote state 미사용)
- WAF는 ALB 생성 후 수동 연결

---

## 📝 배포 체크리스트

### 배포 전 준비
- [ ] AWS CLI 설치 및 인증 설정
- [ ] Terraform 1.0+ 설치
- [ ] 각 모듈의 `terraform.tfvars` 파일 작성
- [ ] CIDR 블록 계획 (`NETWORK_IP_CIDR_MAPPING.md` 참조)
- [ ] 도메인 준비 (Route53 사용 시)
- [ ] EC2 키 페어 생성 (Bastion 접근용)

### Phase 1: 기반 인프라
- [ ] foundation 배포 완료
- [ ] VPC, 서브넷, 보안 그룹 생성 확인
- [ ] foundation outputs 확인
- [ ] nat 배포 완료
- [ ] NAT Gateway 생성 확인
- [ ] Private Route Table 업데이트 확인

### Phase 2: 독립 서비스
- [ ] security 배포 완료
- [ ] ACM Certificate 검증 완료
- [ ] storage 배포 완료
- [ ] ECR Repository 생성 확인
- [ ] database-dynamodb 배포 완료 (선택적)

### Phase 3: 데이터베이스
- [ ] database-rds 배포 완료
- [ ] Aurora Cluster 3개 생성 확인
- [ ] Secrets Manager 비밀번호 확인
- [ ] RDS 엔드포인트 접근 테스트

### Phase 4: 컴퓨팅
- [ ] ECR에 컨테이너 이미지 푸시
- [ ] compute 배포 완료
- [ ] ECS Cluster 생성 확인
- [ ] ALB DNS 이름 확인
- [ ] Bastion Host 접근 테스트
- [ ] ECS Service 정상 실행 확인

### 배포 후 검증
- [ ] 모든 리소스 생성 확인
- [ ] 네트워크 연결 테스트
- [ ] 보안 그룹 규칙 검증
- [ ] 로그 수집 확인 (CloudWatch, CloudTrail)
- [ ] 비용 모니터링 설정

---

## 🔧 배포 스크립트 예시

### 전체 배포 스크립트
```bash
#!/bin/bash
set -e

echo "=== Phase 1: 기반 인프라 ==="
cd foundation/
terraform init
terraform apply -auto-approve
cd ..

cd nat/
terraform init
terraform apply -auto-approve
cd ..

echo "=== Phase 2: 독립 서비스 ==="
cd security/
terraform init
terraform apply -auto-approve
cd ..

cd storage/
terraform init
terraform apply -auto-approve
cd ..

cd database-dynamodb/
terraform init
terraform apply -auto-approve
cd ..

echo "=== Phase 3: 데이터베이스 ==="
cd database-rds/
terraform init
terraform apply -auto-approve
cd ..

echo "=== Phase 4: 컴퓨팅 ==="
cd compute/
terraform init
terraform apply -auto-approve
cd ..

echo "=== 배포 완료 ==="
```

### 단계별 검증 스크립트
```bash
#!/bin/bash

echo "=== foundation 검증 ==="
cd foundation/
terraform output -json > ../outputs/foundation.json
VPC_ID=$(terraform output -raw vpc_id)
echo "VPC ID: $VPC_ID"
cd ..

echo "=== nat 검증 ==="
cd nat/
NAT_IP=$(terraform output -raw nat_gateway_public_ip)
echo "NAT Gateway IP: $NAT_IP"
cd ..

echo "=== security 검증 ==="
cd security/
ACM_ARN=$(terraform output -raw acm_certificate_arn)
echo "ACM Certificate ARN: $ACM_ARN"
cd ..

echo "=== storage 검증 ==="
cd storage/
ECR_URL=$(terraform output -raw ecr_repository_url)
echo "ECR Repository URL: $ECR_URL"
cd ..

echo "=== database-rds 검증 ==="
cd database-rds/
terraform output aurora_cluster_endpoints
cd ..

echo "=== compute 검증 ==="
cd compute/
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "ALB DNS: $ALB_DNS"
BASTION_IP=$(terraform output -raw bastion_public_ip)
echo "Bastion IP: $BASTION_IP"
cd ..
```

---

## 🗑️ 삭제 순서 (역순)

리소스 삭제 시에는 **배포 순서의 역순**으로 진행해야 합니다.

```bash
# 1. compute 삭제
cd compute/
terraform destroy -auto-approve
cd ..

# 2. database-rds 삭제
cd database-rds/
terraform destroy -auto-approve
cd ..

# 3. 독립 서비스 삭제 (병렬 가능)
cd database-dynamodb/
terraform destroy -auto-approve
cd ..

cd storage/
terraform destroy -auto-approve
cd ..

cd security/
terraform destroy -auto-approve
cd ..

# 4. nat 삭제
cd nat/
terraform destroy -auto-approve
cd ..

# 5. foundation 삭제 (마지막)
cd foundation/
terraform destroy -auto-approve
cd ..
```

**주의사항**:
- RDS 삭제 시 최종 스냅샷 생성 여부 확인
- S3 버킷 (ALB Logs, CloudTrail) 수동 삭제 필요
- Secrets Manager 비밀 복구 기간 (7-30일) 고려

---

## 📚 참고 문서

- `NETWORK_IP_CIDR_MAPPING.md`: CIDR 블록 계획
- `CLUSTER_INDEPENDENCE_GUIDE.md`: 독립 클러스터 배포 가이드
- `DEPLOYMENT_GUIDE.md`: 일반 배포 가이드
- `NAMING_CONVENTION.md`: 리소스 명명 규칙
- 각 모듈의 `README.md`: 모듈별 상세 설명

---

## 🛡️ 재발 방지 권장사항

### 1. 원격 State 백엔드 사용
```terraform
# backend.tf (모든 모듈에 추가)
terraform {
  backend "s3" {
    bucket         = "your-terraform-state"
    key            = "module-name/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### 2. CI/CD 파이프라인 구축
- GitHub Actions로 자동 배포
- Terraform Plan 자동 검토
- 승인 후 Apply 실행

### 3. 모듈 버전 관리
- Git 태그로 모듈 버전 관리
- 프로덕션 환경에서는 특정 버전 고정

### 4. 모니터링 및 알림
- CloudWatch Alarms 설정
- SNS 알림 구성
- Cost Explorer로 비용 모니터링

### 5. 문서화
- 배포 이력 기록
- 변경 사항 문서화
- 트러블슈팅 가이드 업데이트

---

## 📞 문제 발생 시

1. **Terraform 에러**: 에러 메시지 확인 후 해당 리소스 상태 점검
2. **AWS 콘솔 확인**: 리소스가 실제로 생성되었는지 확인
3. **State 파일 확인**: `terraform show` 또는 `terraform state list`
4. **로그 확인**: CloudWatch Logs, CloudTrail 이벤트
5. **롤백**: 문제 발생 시 `terraform destroy` 후 재배포

---

**작성일**: 2024
**버전**: 1.0
**상태**: ✅ 순환 참조 없음, 안전한 배포 순서 확인됨
