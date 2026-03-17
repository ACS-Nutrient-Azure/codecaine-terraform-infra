# Storage Infrastructure

ECR, S3 버킷 및 GitHub Actions 연동 설정

## 포함 리소스

### ECR
- ECR Repository (컨테이너 이미지 저장소)
- ECR Lifecycle Policy (이미지 자동 정리)

### S3 Buckets
- **knowledgebase**: 지식 베이스 데이터 저장
  - Versioning 활성화
  - 90일 후 Standard-IA로 전환
  - 이전 버전 90일 후 삭제
- **codef-api**: Codef API 관련 데이터 저장
  - Versioning 활성화
  - 365일 후 데이터 삭제
  - 이전 버전 30일 후 삭제
- **monitoring**: 모니터링 데이터 저장
  - Versioning 활성화
  - 30일 후 Glacier로 전환
  - 180일 후 데이터 삭제

### GitHub Actions
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
- S3 버킷은 모두 암호화(AES256) 및 Public Access Block 적용됨
- 각 버킷은 용도에 맞는 Lifecycle 정책이 설정되어 있음

## S3 버킷 사용 예시

### Knowledge Base 버킷
```bash
# 파일 업로드
aws s3 cp knowledge-data.json s3://myapp-prd-knowledgebase/data/

# 파일 다운로드
aws s3 cp s3://myapp-prd-knowledgebase/data/knowledge-data.json ./
```

### Codef API 버킷
```bash
# API 응답 저장
aws s3 cp api-response.json s3://myapp-prd-codef-api/responses/$(date +%Y%m%d)/
```

### Monitoring 버킷
```bash
# 로그 업로드
aws s3 cp application.log s3://myapp-prd-monitoring/logs/$(date +%Y%m%d)/
```
