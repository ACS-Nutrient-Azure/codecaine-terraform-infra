# compute — ECS Fargate 클러스터

ECS Fargate 기반 MSA 서비스 클러스터 모듈입니다.

## 서비스 목록

| 서비스 | 포트 | 설명 |
|--------|------|------|
| `users` | 8000 | 사용자/마이페이지 서비스 |
| `history` | 8000 | 히스토리 서비스 |
| `chatbot` | 8000 | 챗봇 서비스 |
| `analysis` | 8000 | 분석 서비스 |
| `frontend` | 8080 | 프론트엔드 |

`enabled_services` variable로 배포할 서비스를 선택할 수 있습니다.

## 의존성

배포 전 아래 모듈이 먼저 apply 완료되어야 합니다:

- `foundation` — VPC, Subnet, Security Group
- `ecr` — ECR Repository
- `s3-buckets` — S3 버킷
- `security` — ACM, Route53, Cognito
- `agentcore/analysis-agent` — AgentCore Runtime ARN (analysis 서비스 환경변수)

## 배포

```cmd
cd compute
terraform init
terraform apply --auto-approve
```

## Task Role 구조

| Role | 사용 서비스 | 주요 권한 |
|------|------------|-----------|
| `ECS-TASK-ROLE` | history, analysis, frontend | Secrets Manager, SSM, ECS Exec |
| `ECS-TASK-USERS-ROLE` | users | + S3 codef-data, Textract, Bedrock |
| `ECS-TASK-CHATBOT-ROLE` | chatbot | + S3 chatbot-json, Bedrock, AgentCore |

## 환경변수 주입

### 공통 (모든 서비스)
- `PROJECT_NAME`, `ENVIRONMENT`, `AWS_REGION`, `SERVICE_NAME`
- `ALLOWED_ORIGINS`, `COGNITO_USER_POOL_ID`, `COGNITO_CLIENT_ID`
- OTEL 관련 (`OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_ENDPOINT` 등)

### 서비스별
- `chatbot`: `REDIS_HOST`, `REDIS_PORT`, `S3_BUCKET_NAME`, `DYNAMODB_*`
- `users`: `S3_BUCKET_NAME` (codef-data), `CODEF_CLIENT_ID/SECRET`
- `analysis`: `AGENTCORE_RUNTIME_ARN`
- `history`: `APP_ENV`

### DB Secrets (users, history, analysis)
Secrets Manager / SSM Parameter Store에서 주입:
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`

## OTEL 사이드카

모든 task definition에 `otel-collector` 사이드카 컨테이너가 포함됩니다.
- Image: `public.ecr.aws/aws-observability/aws-otel-collector:latest`
- Port: 4317 (gRPC)
- Config: `/etc/ecs/ecs-default-config.yaml`

## GitHub Actions 배포 Role

ECS 서비스 배포에는 `CDCI-PRD-GITHUB-ACTIONS-ROLE`을 사용합니다.

```cmd
terraform -chdir=storage output github_actions_role_arn
```

## 주요 변수

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `enabled_services` | 배포할 서비스 목록 | 모든 서비스 |
| `enable_ecs_exec` | ECS Exec 활성화 | `false` |
| `enable_container_insights` | Container Insights | `false` |
| `log_retention_days` | 로그 보관 기간 | `30` |
