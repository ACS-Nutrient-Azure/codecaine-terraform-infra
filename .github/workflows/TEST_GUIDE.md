# GitHub Actions 워크플로우 테스트 가이드

## 1. 워크플로우 작동 방식

### 배포 프로세스
```
코드 변경 → GitHub Push → Actions 트리거 → Docker 빌드 → ECR 푸시 → ECS 배포
```

### 자동 트리거 조건
- **Python 워크플로우**: `services/python/**` 경로의 파일이 변경되면 자동 실행
- **TypeScript 워크플로우**: `services/typescript/**` 경로의 파일이 변경되면 자동 실행
- **브랜치**: `main` 또는 `develop` 브랜치에 푸시할 때만 실행

## 2. 로컬 테스트 방법

### 2.1 Docker 빌드 테스트

```bash
# Python 서비스 테스트 (예: analysis)
cd services/python/analysis
docker build -t test-analysis .
docker run -p 8080:8080 test-analysis

# 다른 터미널에서 테스트
curl http://localhost:8080/health
curl -X POST http://localhost:8080/api/analyze

# TypeScript 서비스 테스트 (frontend)
cd services/typescript/frontend
docker build -t test-frontend .
docker run -p 8080:8080 test-frontend

# 테스트
curl http://localhost:8080/health
curl http://localhost:8080/
```

### 2.2 Act를 사용한 로컬 워크플로우 테스트

Act는 GitHub Actions를 로컬에서 실행할 수 있는 도구입니다.

```bash
# Act 설치 (Windows - Chocolatey)
choco install act-cli

# Act 설치 (macOS - Homebrew)
brew install act

# Act 설치 (Linux)
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# 워크플로우 테스트 (dry-run)
act -n

# 특정 워크플로우 실행
act -W .github/workflows/deploy-python.yml

# 수동 트리거 이벤트 시뮬레이션
act workflow_dispatch -W .github/workflows/deploy-python.yml
```

## 3. GitHub에서 수동 테스트

### 3.1 수동 워크플로우 실행

1. GitHub 레포지토리로 이동
2. **Actions** 탭 클릭
3. 왼쪽에서 워크플로우 선택:
   - `Deploy Python Service to ECS`
   - `Deploy TypeScript Service to ECS`
4. **Run workflow** 버튼 클릭
5. 서비스 선택:
   - Python: analysis, chatbot, codef
   - TypeScript: frontend, mypage
6. **Run workflow** 실행

### 3.2 워크플로우 로그 확인

1. Actions 탭에서 실행 중인 워크플로우 클릭
2. 각 단계별 로그 확인:
   - ✅ Checkout code
   - ✅ Configure AWS credentials
   - ✅ Login to Amazon ECR
   - ✅ Build, tag, and push image
   - ✅ Deploy to ECS
   - ✅ Verify deployment

## 4. 실제 배포 테스트 시나리오

### 시나리오 1: Python 서비스 배포 (Analysis)

```bash
# 1. 코드 수정
cd services/python/analysis
echo "# Updated" >> app.py

# 2. Git 커밋 및 푸시
git add .
git commit -m "Update analysis service"
git push origin main

# 3. GitHub Actions에서 자동 배포 확인
# - GitHub > Actions 탭에서 진행 상황 확인

# 4. 배포 완료 후 ECS 확인
aws ecs describe-services \
  --cluster cdci-prd-cluster \
  --services cdci-prd-analysis-service \
  --region ap-northeast-2

# 5. 실행 중인 태스크 확인
aws ecs list-tasks \
  --cluster cdci-prd-cluster \
  --service-name cdci-prd-analysis-service \
  --region ap-northeast-2
```

### 시나리오 2: TypeScript 서비스 배포 (Frontend)

```bash
# 1. 코드 수정
cd services/typescript/frontend
echo "// Updated" >> src/index.ts

# 2. Git 커밋 및 푸시
git add .
git commit -m "Update frontend service"
git push origin main

# 3. GitHub Actions에서 자동 배포 확인

# 4. 배포 완료 후 확인
aws ecs describe-services \
  --cluster cdci-prd-cluster \
  --services cdci-prd-frontend-service \
  --region ap-northeast-2
```

## 5. 워크플로우 디버깅

### 5.1 일반적인 문제 해결

**문제: ECR 로그인 실패**
```yaml
# 해결: AWS 자격 증명 확인
# GitHub > Settings > Secrets and variables > Actions
# AWS_ACCESS_KEY_ID와 AWS_SECRET_ACCESS_KEY 확인
```

**문제: Docker 빌드 실패**
```bash
# 로컬에서 빌드 테스트
cd services/python/analysis
docker build -t test .

# Dockerfile 문법 확인
# requirements.txt 또는 package.json 확인
```

**문제: ECS 배포 타임아웃**
```bash
# Task Definition 확인
aws ecs describe-task-definition \
  --task-definition cdci-prd-analysis \
  --region ap-northeast-2

# 컨테이너 로그 확인
aws logs tail /ecs/cdci-prd --follow --region ap-northeast-2
```

### 5.2 워크플로우 로그 분석

```bash
# GitHub CLI 설치 후
gh run list
gh run view <run-id>
gh run view <run-id> --log
```

## 6. 배포 검증

### 6.1 ECS 서비스 상태 확인

```bash
# 모든 서비스 상태 확인
aws ecs list-services \
  --cluster cdci-prd-cluster \
  --region ap-northeast-2

# 특정 서비스 상세 정보
aws ecs describe-services \
  --cluster cdci-prd-cluster \
  --services cdci-prd-analysis-service \
  --region ap-northeast-2 \
  --query 'services[0].[serviceName,status,runningCount,desiredCount,deployments]'
```

### 6.2 컨테이너 로그 확인

```bash
# CloudWatch Logs 확인
aws logs tail /ecs/cdci-prd --follow --region ap-northeast-2

# 특정 서비스 로그만 필터링
aws logs tail /ecs/cdci-prd --follow \
  --filter-pattern "analysis" \
  --region ap-northeast-2
```

### 6.3 헬스체크 확인

```bash
# ALB를 통한 헬스체크
curl http://cdci-prd-alb-XXXXXXXX.ap-northeast-2.elb.amazonaws.com/health

# 또는 ECS Task의 Private IP로 직접 확인 (Bastion 통해)
ssh -i codecaine.pem ec2-user@<BASTION_IP>
curl http://<TASK_PRIVATE_IP>:8080/health
```

## 7. 워크플로우 수정 및 개선

### 7.1 알림 추가 (Slack)

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Deployment ${{ job.status }}'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### 7.2 롤백 기능 추가

```yaml
- name: Rollback on failure
  if: failure()
  run: |
    aws ecs update-service \
      --cluster cdci-prd-cluster \
      --service cdci-prd-${{ steps.service.outputs.name }}-service \
      --force-new-deployment \
      --region ap-northeast-2
```

## 8. 베스트 프랙티스

1. **브랜치 전략**
   - `develop` 브랜치: 개발 환경 자동 배포
   - `main` 브랜치: 프로덕션 환경 수동 승인 후 배포

2. **이미지 태깅**
   - Git SHA를 이미지 태그로 사용 (추적 가능)
   - `latest` 태그도 함께 푸시 (빠른 롤백용)

3. **배포 검증**
   - 헬스체크 통과 확인
   - 서비스 안정성 대기 (wait-for-service-stability)
   - 배포 후 자동 테스트 실행

4. **시크릿 관리**
   - GitHub Secrets에 민감 정보 저장
   - AWS IAM 최소 권한 원칙 적용
   - 정기적인 자격 증명 로테이션

## 9. 트러블슈팅 체크리스트

- [ ] GitHub Secrets 설정 확인
- [ ] Dockerfile 문법 확인
- [ ] requirements.txt / package.json 의존성 확인
- [ ] ECS Task Definition 존재 확인
- [ ] ECS Service 존재 확인
- [ ] ECR 레포지토리 존재 확인
- [ ] IAM 권한 확인
- [ ] VPC/Subnet/Security Group 설정 확인
- [ ] ALB Target Group 헬스체크 설정 확인
- [ ] CloudWatch Logs 확인

## 10. 참고 자료

- [GitHub Actions 문서](https://docs.github.com/en/actions)
- [AWS ECS 배포 가이드](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/)
- [Act 문서](https://github.com/nektos/act)
