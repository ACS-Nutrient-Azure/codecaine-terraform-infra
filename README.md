# ECS Web Service Infrastructure (리팩토링 완료)

ECS Fargate 기반 웹서비스 인프라 (Terraform)

> **최신 업데이트**: Observability 파이프라인 구축 (ADOT + X-Ray + CloudWatch + Grafana)
> **팀**: CodeCaine (CDCI)

## 네이밍 규칙

모든 AWS 리소스는 **CDCI** (CodeCaine 약어)로 시작하는 일관된 네이밍 규칙을 따릅니다.

### 패턴
```
CDCI-{ENVIRONMENT}-{RESOURCE_TYPE}-{DETAIL}
```

### 예시
- VPC: `CDCI-PRD-VPC`
- Subnet: `CDCI-PRD-VPC-PUBLIC-2A`, `CDCI-PRD-VPC-PRIVATE-APP-2C`
- Bastion: `CDCI-PRD-BASTION`, `CDCI-PRD-BASTION-SG`
- ECS: `CDCI-PRD-ECS-CLUSTER`, `CDCI-PRD-ECS-SERVICE`
- ALB: `CDCI-PRD-ALB`, `CDCI-PRD-TG`
- RDS: `CDCI-PRD-RDS-SG`
- NAT: `CDCI-PRD-NAT-GW`, `CDCI-PRD-NAT-EIP`

### 환경 코드
- `PRD`: 프로덕션 환경
- `STG`: 스테이징 환경
- `DEV`: 개발 환경

### 설정 방법
```hcl
# terraform.tfvars
project_name = "cdci"  # CodeCaine 팀 약어
environment  = "prd"   # prd, stg, dev
```

## 아키텍처

```
Internet
    ↓
Route53 → ACM (SSL/TLS)
    ↓
WAF → ALB (Public Subnet) ← Bastion Host (SSH 접근)
    ↓
ECS Fargate Tasks (Private Subnet) ↔ ECS Tasks (마이크로서비스 간 통신)
    ↓
Aurora PostgreSQL Global DB (Private DB Subnet)
    ↓
다중 리전 복제 (글로벌 확장)
```

## 주요 개선 사항

### ✅ 1. Bastion 서버 추가
- 퍼블릭 서브넷에 배치
- 프라이빗 리소스 안전 접근
- SSM Session Manager 지원

### ✅ 2. Aurora PostgreSQL Global Database
- 기존 RDS → Aurora 전환
- Serverless v2 자동 스케일링
- 다중 리전 복제 (1초 미만 지연)

### ✅ 3. 보안 그룹 개선
- ECS 간 통신 허용 (self 참조)
- Bastion → DB 접근 허용
- 최소 권한 원칙 적용

## 모듈 구조

### 기본 골격 (변화 없는 인프라)

| 모듈 | 리소스 | 비용 | 설명 |
|------|--------|------|------|
| **foundation/** | VPC, Subnets, IGW, Route Tables, Security Groups | 무료 | 네트워크 기반 |
| **storage/** | ECR, GitHub OIDC | 거의 무료 | 컨테이너 이미지 저장소 |
| **security/** | Route53, ACM, WAF, Cognito | 최소 | 보안 및 인증 |

### 비용 발생 리소스 (독립 관리)

| 모듈 | 리소스 | 월 예상 비용 | 설명 |
|------|--------|--------------|------|
| **nat/** | NAT Gateway | ~$32 (1개) | Private 서브넷 아웃바운드 |
| **database-rds/** | Aurora PostgreSQL | ~$43-172 | Aurora Serverless v2 |
| **compute/** | ECS Fargate, ALB, Bastion | ~$37 | 웹서비스 + 관리 서버 |
| **monitoring/** | AWS Managed Grafana | ~$9 | 통합 Observability 대시보드 |

**총 예상 비용**: ~$112-241/month (Aurora 스케일링에 따라 변동)

## 배포 순서

### 1. Foundation (필수)
```bash
cd foundation
terraform init
terraform apply
```

### 2. Storage (ECR)
```bash
cd ../storage
# terraform.tfvars에서 github_repo 수정
terraform init
terraform apply
```

### 3. Security (ACM, WAF, Cognito)
```bash
cd ../security
# terraform.tfvars에서 domain_name 수정
terraform init
terraform apply
```

### 4. NAT Gateway (선택)
```bash
cd nat
# connectivity_type = "public" (Regional 구성)
terraform init
terraform apply
```

**비용**: ~$32/month (단일 NAT Gateway)

### 5. Database - Aurora (권장)
```bash
cd database-rds
# terraform.tfvars에서 db_password 설정 (각 클러스터별)
# users-cluster, history-cluster, analysis-cluster
terraform init
terraform apply
```

### 6. Compute (ECS, ALB, Bastion)
```bash
cd compute
# use_existing_vpc = true 설정 (foundation VPC 사용)
# SSH 키 페어 생성 후 terraform.tfvars에 공개키 입력
# ECR에 이미지 푸시 후
terraform init
terraform apply
```

## 네트워크 구성

- **Region**: ap-northeast-2 (서울)
- **AZs**: ap-northeast-2a, ap-northeast-2c
- **VPC CIDR**: 10.0.0.0/16
- **Public Subnets**: 10.0.0.0/24, 10.0.1.0/24 (ALB, Bastion)
- **Private App Subnets**: 10.0.10.0/24, 10.0.11.0/24 (ECS)
- **Private DB Subnets**: 10.0.20.0/24, 10.0.21.0/24 (Aurora)

## Bastion 서버 사용

### SSH 키 페어 생성
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/bastion-key -C "bastion@myapp"
cat ~/.ssh/bastion-key.pub  # terraform.tfvars에 입력
```

### Bastion 접속
```bash
# SSH 접속
chmod 400 ~/.ssh/bastion-key
ssh -i ~/.ssh/bastion-key ec2-user@<BASTION_PUBLIC_IP>

# SSM Session Manager (권장)
aws ssm start-session --target <BASTION_INSTANCE_ID>
```

### Aurora 접속
```bash
# Bastion에서 직접 접속
psql -h <AURORA_ENDPOINT> -U dbadmin -d appdb1

# 로컬에서 SSH 터널링
ssh -i ~/.ssh/bastion-key -L 5432:<AURORA_ENDPOINT>:5432 ec2-user@<BASTION_PUBLIC_IP>
psql -h localhost -U dbadmin -d appdb1
```

## GitHub Actions 워크플로우

```yaml
name: Deploy to ECS

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-northeast-2
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build and push
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: myapp-prd
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
      
      - name: Update ECS service
        run: |
          aws ecs update-service \
            --cluster myapp-prd-cluster \
            --service myapp-prd-service \
            --force-new-deployment
```

## 비용 관리

### 프로덕션 환경 비용 절감
```bash
# 사용하지 않을 때 삭제
cd compute && terraform destroy
cd ../database && terraform destroy
cd ../nat && terraform destroy
```

### 최소 비용 구성 (Prd)
- NAT Gateway: 1개 (~$32/month)
- RDS: db.t3.micro × 3, Single-AZ (~$50/month)
- ECS: 0.25 vCPU + 0.5 GB × 1 task (~$9/month)
- ALB: (~$20/month)

**최소 비용**: ~$108/month

### 프로덕션 구성
- NAT Gateway: 2개 (HA) (~$64/month)
- RDS: db.t3.small × 3, Multi-AZ (~$200/month)
- ECS: 0.5 vCPU + 1 GB × 4 tasks (~$72/month)
- ALB: (~$30/month)
- WAF: (~$10/month)

**프로덕션 비용**: ~$380/month

## 주요 기능

### Auto Scaling
- CPU 기반: 70% 목표
- Memory 기반: 80% 목표
- Request 기반: 1000 req/target 목표

### 보안
- WAF: SQL Injection, XSS 방어
- Shield Standard: DDoS 방어 (무료)
- ACM: SSL/TLS 인증서 (무료)
- Cognito: 사용자 인증/인가

### 모니터링 (Observability)
- ADOT Sidecar: 분산 트레이싱 수집 (X-Ray)
- CloudWatch Logs: 애플리케이션 로그
- CloudWatch Metrics: CPU, Memory, Request (Container Insights 포함)
- AWS Managed Grafana: 통합 관제 대시보드

### 고가용성
- Multi-AZ: 2개 가용 영역
- ALB: 자동 장애 조치
- ECS: 자동 복구
- RDS: Multi-AZ 옵션

## 데이터베이스 연결

### Aurora PostgreSQL
```bash
# Bastion을 통한 접속
ssh -i ~/.ssh/bastion-key ec2-user@<BASTION_PUBLIC_IP>
psql -h <AURORA_ENDPOINT> -U dbadmin -d appdb1

# 비밀번호 조회
aws secretsmanager get-secret-value \
  --secret-id cdci-prd-users-cluster-password \
  --query SecretString --output text | jq -r .password
```

### Aurora PostgreSQL
```bash
```hcl
# database-rds/terraform.tfvars
enable_global_database = true
```

### 2. 보조 리전 추가 (별도 Terraform 워크스페이스)
```bash
# us-east-1 리전에 보조 클러스터 생성
cd database-rds-secondary
terraform workspace new us-east-1
terraform apply
```

## Observability 구축 현황

### 아키텍처

```
ECS Fargate Task
├── App Container
│   └── OTEL SDK (traces 생성)
└── ADOT Sidecar (otel-collector)
    ├── Traces  → AWS X-Ray
    └── Metrics → CloudWatch EMF

CloudWatch
├── AWS/ECS          (CPU, Memory - 서비스별)
├── AWS/ApplicationELB (RequestCount, TargetResponseTime, 4xx/5xx)
└── ECS/ContainerInsights (RunningTaskCount - Container Insights)

AWS Managed Grafana (g-39fdcca4d2)
└── CDCI PRD 폴더
    ├── ✅ Service Health     (ECS + ALB 모니터링)
    ├── 🔜 X-Ray Traces       (분산 트레이싱)
    └── 🔜 Business Overview  (API 트렌드 / 에러율)
```

### 진행 단계

| Phase | 내용 | 상태 |
|-------|------|------|
| Phase 1 | ADOT 사이드카 + IAM 권한 + Container Insights 활성화 | ✅ 완료 |
| Phase 2 | AWS Managed Grafana 워크스페이스 + SSO 접근 권한 | ✅ 완료 |
| Phase 3 | Service Health 대시보드 (ECS + ALB) | ✅ 완료 |
| Phase 4 | X-Ray Traces 대시보드 | 🔜 진행 예정 |
| Phase 5 | Business Overview 대시보드 | 🔜 진행 예정 |
| Phase 6 | CloudWatch Alarms | 🔜 미정 |

### Service Health 대시보드 패널

| 패널 | 메트릭 | 방식 |
|------|--------|------|
| ALB 요청 수 (서비스별) | `AWS/ApplicationELB` RequestCount | SQL `GROUP BY TargetGroup` |
| ALB 응답시간 P50/P95/P99 | `AWS/ApplicationELB` TargetResponseTime | 표준 메트릭 (p50, p95, p99) |
| 4xx / 5xx 에러 수 | `AWS/ApplicationELB` HTTPCode_Target_*XX_Count | 표준 메트릭 Sum |
| ECS CPU 사용률 | `AWS/ECS` CPUUtilization | SQL `GROUP BY ServiceName` |
| ECS 메모리 사용률 | `AWS/ECS` MemoryUtilization | SQL `GROUP BY ServiceName` |
| ECS 실행 중인 태스크 수 | `ECS/ContainerInsights` RunningTaskCount | SQL `GROUP BY ServiceName` |

### 주요 리소스 ID

| 리소스 | 값 |
|--------|-----|
| Grafana Workspace ID | `g-39fdcca4d2` |
| Grafana URL | `https://g-39fdcca4d2.grafana-workspace.ap-northeast-2.amazonaws.com` |
| CloudWatch 데이터소스 UID | `bfh249rbispvkf` |
| X-Ray 데이터소스 UID | `cfh299z8g6l1ce` |
| ALB ARN suffix | `app/cdci-prd-alb/a70048e764d183e8` |

### Grafana 접근

인증 방식: **AWS IAM Identity Center (SSO)**

```bash
# Terraform 배포 시 서비스 계정 토큰 필요
export TF_VAR_grafana_api_key="glsa_..."
cd monitoring && terraform apply
```

### Grafana CloudWatch 쿼리 포맷 주의사항

CloudWatch Metrics Insights SQL 사용 시:
- 필드명: `sqlExpression` (❌ `expression` → Metric Math 전용)
- 패널당 SQL 쿼리 **1개만** 허용 → 다중 시리즈는 `GROUP BY` 사용
- `region: "default"` 명시 필요

```json
{
  "metricQueryType": 1,
  "metricEditorMode": 1,
  "region": "default",
  "sqlExpression": "SELECT AVG(CPUUtilization) FROM \"AWS/ECS\" WHERE ClusterName = 'cdci-prd-cluster' GROUP BY ServiceName"
}
```

### monitoring 모듈 배포

```bash
cd monitoring
export TF_VAR_grafana_api_key="<서비스 계정 토큰>"
terraform init
terraform apply
```

---

## 트러블슈팅

### ECS Task가 시작되지 않음
1. ECR 이미지 확인
2. CloudWatch Logs 확인
3. Security Group 확인 (ECS 간 통신 허용 확인)
4. NAT Gateway 확인 (Private 서브넷)

### Bastion 접속 불가
1. 보안그룹에서 내 IP 허용 확인
2. 키 파일 권한 확인 (`chmod 400`)
3. Elastic IP 할당 확인

### Aurora 연결 실패
1. Bastion에서 접속 가능한지 확인
2. 보안그룹 규칙 확인 (ECS, Bastion → Aurora)
3. Secrets Manager에서 자격 증명 확인

### Health Check 실패
1. Health Check Path 확인 (`/health`)
2. Container Port 확인 (8080)
3. Application 로그 확인

### 503 에러
1. Target Group Healthy Target 확인
2. ECS Service Desired Count 확인
3. Task Running 상태 확인

## 삭제 순서

```bash
# 역순으로 삭제
cd compute && terraform destroy
cd ../database && terraform destroy
cd ../nat && terraform destroy
cd ../security && terraform destroy
cd ../storage && terraform destroy
cd ../foundation && terraform destroy
```

## 참고 문서

- [리팩토링 상세 가이드](REFACTORING_SUMMARY.md)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Aurora Global Database](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 라이선스

MIT