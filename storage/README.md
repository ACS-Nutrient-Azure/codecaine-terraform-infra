# Storage Infrastructure

ECR 및 GitHub Actions 연동 설정

## 포함 리소스

- ECR Repository (컨테이너 이미지 저장소)
- ECR Lifecycle Policy (이미지 자동 정리)
- GitHub OIDC Provider (선택)
- GitHub Actions IAM Role (선택)

## 배포

```bash
cd storage
# terraform.tfvars에서 github_repo 수정
terraform init
terraform plan
terraform apply
```

## GitHub Actions 워크플로우 예제

```yaml
name: Deploy to ECR

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
```

## 주의사항

- GitHub OIDC를 사용하지 않으려면 `create_github_oidc = false` 설정
- ECR은 비용이 거의 없지만 저장 용량에 따라 과금됨
