# ECS Web Service Infrastructure

ECS Fargate 기반 웹서비스 + AWS Bedrock AgentCore 인프라 (Terraform)

> **최신 업데이트**: AgentCore Runtime 에이전트 메트릭 연동 (boto3 → CloudWatch → Grafana)
> **팀**: CodeCaine (CDCI)

## 아키텍처

```
Internet
    ↓
Route53 → ACM (SSL/TLS)
    ↓
ALB (Public Subnet)
    ↓
ECS Fargate Tasks (Private Subnet)
    ├─→ Aurora PostgreSQL (Private DB Subnet)
    └─→ AgentCore Runtime (analysis-agent, chatbot-agent)
            ↑
    AgentCore Supervisor (오케스트레이터)
```

## 모듈 구조

| 모듈 | 설명 |
|------|------|
| `foundation/` | VPC, Subnets, IGW, Route Tables, Security Groups |
| `nat/` | NAT Gateway |
| `ecr/` | ECR Repository (서비스 + 에이전트) |
| `s3-buckets/` | S3 버킷 |
| `storage/` | GitHub Actions OIDC/IAM |
| `security/` | Route53, ACM, WAF, Cognito |
| `database-rds/` | Aurora PostgreSQL |
| `compute/` | ECS Fargate, ALB, Bastion |
| `monitoring/` | AWS Managed Grafana (Observability 대시보드) |
| `agentcore/provisioner/` | AgentCore Runtime 생성용 Lambda |
| `agentcore/analysis-agent/` | 영양소 분석 에이전트 |
| `agentcore/chatbot-agent/` | 챗봇 에이전트 |
| `agentcore/supervisor-agent/` | 하위 에이전트 오케스트레이터 |
| `dms/` | Database Migration Service |

## Observability 구축 현황

```
ECS Fargate Task
├── App Container
│   └── OTEL SDK (traces 생성)
└── ADOT Sidecar (otel-collector)
    ├── Traces  → AWS X-Ray
    └── Metrics → CloudWatch EMF

AgentCore Runtime
└── Agent Container
    └── boto3 → CloudWatch (CDCI/AgentCore)

CloudWatch
├── AWS/ECS                  (CPU, Memory - 서비스별)
├── AWS/ApplicationELB       (RequestCount, TargetResponseTime, 4xx/5xx)
├── ECS/ContainerInsights    (RunningTaskCount)
└── CDCI/AgentCore           (agent_invocation, latency, token, tool 메트릭)

AWS Managed Grafana (g-39fdcca4d2)
└── CDCI PRD 폴더
    ├── ✅ Service Health     (ECS + ALB 모니터링)
    ├── ✅ Business Overview  (에이전트 호출 / 토큰 / Tool 지표)
    ├── 🔜 X-Ray Traces       (분산 트레이싱)
    └── 🔜 CloudWatch Alarms  (임계값 알림)
```

| Phase | 내용 | 상태 |
|-------|------|------|
| Phase 1 | ADOT 사이드카 + IAM 권한 + Container Insights | ✅ 완료 |
| Phase 2 | AWS Managed Grafana 워크스페이스 + SSO | ✅ 완료 |
| Phase 3 | Service Health 대시보드 (ECS + ALB) | ✅ 완료 |
| Phase 4 | AgentCore 에이전트 메트릭 계측 (boto3 → CloudWatch) | ✅ 완료 |
| Phase 5 | Business Overview 대시보드 (에이전트 지표 시각화) | ✅ 완료 |
| Phase 6 | X-Ray Traces 대시보드 | 🔜 진행 예정 |
| Phase 7 | CloudWatch Alarms | 🔜 미정 |

Grafana URL: `https://g-39fdcca4d2.grafana-workspace.ap-northeast-2.amazonaws.com`

## 배포 순서

전체 배포 순서는 [DEPLOYMENT_ORDER.md](DEPLOYMENT_ORDER.md)를 참조하세요.

AgentCore 에이전트 배포는 [agentcore/README.md](agentcore/README.md)를 참조하세요.

## 네이밍 규칙

```
CDCI-{ENVIRONMENT}-{RESOURCE_TYPE}-{DETAIL}
```

- `PRD`: 프로덕션 / `STG`: 스테이징 / `DEV`: 개발

자세한 내용은 [NAMING_CONVENTION.md](NAMING_CONVENTION.md)를 참조하세요.

## 네트워크 구성

- **Region**: ap-northeast-2 (서울)
- **AZs**: ap-northeast-2a, ap-northeast-2c
- **VPC CIDR**: 10.0.0.0/16
- **Public Subnets**: 10.0.0.0/24, 10.0.1.0/24 (ALB, Bastion)
- **Private App Subnets**: 10.0.10.0/24, 10.0.11.0/24 (ECS)
- **Private DB Subnets**: 10.0.20.0/24, 10.0.21.0/24 (Aurora)

## 참고 문서

- [DEPLOYMENT_ORDER.md](DEPLOYMENT_ORDER.md) - 전체 배포 순서
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - 상세 배포 가이드
- [agentcore/README.md](agentcore/README.md) - AgentCore 에이전트 배포
- [NAMING_CONVENTION.md](NAMING_CONVENTION.md) - 리소스 네이밍 규칙
- [GIT_COMMIT_CONVENTION.md](GIT_COMMIT_CONVENTION.md) - Git 커밋 규칙

## 아키텍처

```
Internet
    ↓
Route53 → ACM (SSL/TLS)
    ↓
ALB (Public Subnet)
    ↓
ECS Fargate Tasks (Private Subnet)
    ├─→ Aurora PostgreSQL (Private DB Subnet)
    └─→ AgentCore Runtime (analysis-agent, chatbot-agent)
            ↑
    AgentCore Supervisor (오케스트레이터)
```

## 모듈 구조

| 모듈 | 설명 |
|------|------|
| `foundation/` | VPC, Subnets, IGW, Route Tables, Security Groups |
| `nat/` | NAT Gateway |
| `ecr/` | ECR Repository (서비스 + 에이전트) |
| `s3-buckets/` | S3 버킷 |
| `storage/` | GitHub Actions OIDC/IAM |
| `security/` | Route53, ACM, WAF, Cognito |
| `database-rds/` | Aurora PostgreSQL |
| `compute/` | ECS Fargate, ALB, Bastion |
| `agentcore/provisioner/` | AgentCore Runtime 생성용 Lambda |
| `agentcore/analysis-agent/` | 영양소 분석 에이전트 |
| `agentcore/chatbot-agent/` | 챗봇 에이전트 |
| `agentcore/supervisor-agent/` | 하위 에이전트 오케스트레이터 |
| `dms/` | Database Migration Service |

## 배포 순서

전체 배포 순서는 [DEPLOYMENT_ORDER.md](DEPLOYMENT_ORDER.md)를 참조하세요.

AgentCore 에이전트 배포는 [agentcore/README.md](agentcore/README.md)를 참조하세요.

## 네이밍 규칙

```
CDCI-{ENVIRONMENT}-{RESOURCE_TYPE}-{DETAIL}
```

- `PRD`: 프로덕션 / `STG`: 스테이징 / `DEV`: 개발

자세한 내용은 [NAMING_CONVENTION.md](NAMING_CONVENTION.md)를 참조하세요.

## 네트워크 구성

- **Region**: ap-northeast-2 (서울)
- **AZs**: ap-northeast-2a, ap-northeast-2c
- **VPC CIDR**: 10.0.0.0/16
- **Public Subnets**: 10.0.0.0/24, 10.0.1.0/24 (ALB, Bastion)
- **Private App Subnets**: 10.0.10.0/24, 10.0.11.0/24 (ECS)
- **Private DB Subnets**: 10.0.20.0/24, 10.0.21.0/24 (Aurora)

## 참고 문서

- [DEPLOYMENT_ORDER.md](DEPLOYMENT_ORDER.md) - 전체 배포 순서
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - 상세 배포 가이드
- [agentcore/README.md](agentcore/README.md) - AgentCore 에이전트 배포
- [NAMING_CONVENTION.md](NAMING_CONVENTION.md) - 리소스 네이밍 규칙
- [GIT_COMMIT_CONVENTION.md](GIT_COMMIT_CONVENTION.md) - Git 커밋 규칙