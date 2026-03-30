# AgentCore 배포 가이드

## 구조

```
agentcore/
├── memory/               # AgentCore 공통 메모리 (chatbot 세션 단기 기억)
├── provisioner/          # AgentCore Runtime 생성용 Lambda (공통)
├── analysis-agent/       # 영양소 분석 에이전트
├── chatbot-agent/        # 챗봇 에이전트 (question agent, VPC 모드)
├── summary-agent/        # 요약 에이전트
└── supervisor-agent/     # 하위 에이전트 오케스트레이터 (VPC 모드)
```

## 배포 순서

모듈 간 remote state 의존성이 있으므로 순서를 반드시 지켜야 합니다.

```
1. memory           ← awscc provider 필요 (terraform init 필수)
2. provisioner      ← Runtime 생성 Lambda
3. analysis-agent   ← provisioner 참조
4. chatbot-agent    ← provisioner 참조
5. summary-agent    ← provisioner 참조
6. supervisor-agent ← provisioner + analysis-agent + chatbot-agent 참조
```

```cmd
cd agentcore\memory         && terraform init && terraform apply --auto-approve
cd agentcore\provisioner    && terraform init && terraform apply --auto-approve
cd agentcore\analysis-agent && terraform init && terraform apply --auto-approve
cd agentcore\chatbot-agent  && terraform init && terraform apply --auto-approve
cd agentcore\summary-agent  && terraform init && terraform apply --auto-approve
cd agentcore\supervisor-agent && terraform init && terraform apply --auto-approve
```

> `memory` 모듈은 `awscc` provider를 사용하므로 반드시 `terraform init`을 먼저 실행해야 합니다.

---

## 최초 배포 시 주의사항

### ECR 이미지가 없는 경우
ECR에 이미지가 없으면 provisioner Lambda가 Runtime 생성을 건너뜁니다 (`skipped: True`).
이 경우 apply는 성공하지만 AgentCore Runtime이 생성되지 않습니다.

**해결 방법**: ECR에 이미지 push 후 Lambda를 강제 재실행합니다.

```cmd
cd agentcore\analysis-agent
terraform apply -replace=aws_lambda_invocation.agentcore_runtime --auto-approve
```

### ECR 이미지 자동 선택
provisioner Lambda는 ECR 레포에서 **가장 최근에 push된 이미지**를 자동으로 선택합니다.
`image_tag`를 별도로 지정할 필요 없습니다.

### Memory ID 확인
memory 배포 후 SSM에 저장된 Memory ID를 확인합니다.

```cmd
aws ssm get-parameter --name "/cdci/prd/agentcore/memory-id" --region ap-northeast-2
```

---

## CI/CD 배포 (이미지 업데이트)

이미지 업데이트는 GitHub Actions에서 처리합니다. Terraform 재실행 불필요.

### GitHub Secrets 설정

| Secret | 값 | 확인 방법 |
|--------|-----|-----------|
| `AWS_DEPLOY_ROLE_ARN` | `*-GITHUB-ACTIONS-ROLE` ARN | `terraform output github_actions_role_arn` |
| `AGENTCORE_RUNTIME_ID` | Runtime ID | AWS 콘솔 또는 `terraform output agentcore_runtime_arn` |
| `AGENTCORE_ROLE_ARN` | Runtime 실행 Role ARN | `terraform output agentcore_runtime_role_arn` |

### chatbot-agent GitHub Repo
`codecaine-python-questionagent` (레포명 변경됨)

### Role 구분

| Role | 용도 |
|------|------|
| `*-QUESTION-AGENT-GITHUB-ACTIONS-ROLE` | GitHub Actions가 assume — ECR push + AgentCore Runtime 업데이트 |
| `*-CHATBOT-AGENTCORE-RUNTIME-ROLE` | AgentCore Runtime이 assume — 컨테이너 실행 시 사용 |
| `*-SUPERVISOR-AGENT-GITHUB-ACTIONS-ROLE` | GitHub Actions가 assume — supervisor 배포 |

---

## 삭제 순서 (역순)

```cmd
cd agentcore\supervisor-agent && terraform destroy --auto-approve
cd agentcore\summary-agent    && terraform destroy --auto-approve
cd agentcore\chatbot-agent    && terraform destroy --auto-approve
cd agentcore\analysis-agent   && terraform destroy --auto-approve
cd agentcore\provisioner      && terraform destroy --auto-approve
cd agentcore\memory           && terraform destroy --auto-approve
```

> AgentCore Runtime은 Terraform이 직접 관리하지 않으므로 AWS 콘솔에서 수동 삭제 필요.
