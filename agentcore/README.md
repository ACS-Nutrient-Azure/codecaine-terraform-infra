# AgentCore 배포 가이드

## 구조

```
agentcore/
├── provisioner/          # AgentCore Runtime 생성용 Lambda (공통)
├── analysis-agent/       # 영양소 분석 에이전트
├── chatbot-agent/        # 챗봇 에이전트
└── supervisor-agent/     # 하위 에이전트 오케스트레이터
```

## 배포 순서

supervisor가 analysis/chatbot의 remote state에서 ARN을 읽으므로 순서를 반드시 지켜야 함.

```
1. provisioner
2. analysis-agent
3. chatbot-agent
4. supervisor-agent
```

```cmd
cd agentcore\provisioner      && terraform init && terraform apply --auto-approve
cd agentcore\analysis-agent   && terraform init && terraform apply --auto-approve
cd agentcore\chatbot-agent    && terraform init && terraform apply --auto-approve
cd agentcore\supervisor-agent && terraform init && terraform apply --auto-approve
```

---

## 최초 배포 시 주의사항

### ECR 이미지가 없는 경우
ECR에 이미지가 없으면 provisioner Lambda가 Runtime 생성을 건너뜁니다 (`skipped: True`).
이 경우 apply는 성공하지만 AgentCore Runtime이 생성되지 않습니다.

**해결 방법**: ECR에 이미지 push 후 Lambda를 강제 재실행합니다.

```cmd
# 이미지 push 후
cd agentcore\analysis-agent
terraform apply -replace=aws_lambda_invocation.agentcore_runtime --auto-approve
```

### ECR 이미지 자동 선택
provisioner Lambda는 ECR 레포에서 **가장 최근에 push된 이미지**를 자동으로 선택합니다.
`image_tag`를 별도로 지정할 필요 없습니다.

---

## CI/CD 배포 (이미지 업데이트)

이미지 업데이트는 GitHub Actions에서 처리합니다. Terraform 재실행 불필요.

### GitHub Secrets 설정

| Secret | 값 | 확인 방법 |
|--------|-----|-----------|
| `AWS_DEPLOY_ROLE_ARN` | `*-GITHUB-ACTIONS-ROLE` ARN | `terraform output github_actions_role_arn` |
| `AGENTCORE_RUNTIME_ID` | Runtime ID | AWS 콘솔 또는 `terraform output agentcore_runtime_arn` |
| `AGENTCORE_ROLE_ARN` | Runtime 실행 Role ARN | `terraform output agentcore_runtime_role_arn` |

### Role 구분

| Role | 용도 |
|------|------|
| `*-GITHUB-ACTIONS-ROLE` | GitHub Actions가 assume — ECR push + AgentCore Runtime 업데이트 |
| `*-AGENTCORE-RUNTIME-ROLE` | AgentCore Runtime이 assume — 컨테이너 실행 시 사용 |

---

## 삭제 순서 (역순)

```cmd
cd agentcore\supervisor-agent && terraform destroy --auto-approve
cd agentcore\chatbot-agent    && terraform destroy --auto-approve
cd agentcore\analysis-agent   && terraform destroy --auto-approve
cd agentcore\provisioner      && terraform destroy --auto-approve
```

> AgentCore Runtime은 Terraform이 직접 관리하지 않으므로 AWS 콘솔에서 수동 삭제 필요.
