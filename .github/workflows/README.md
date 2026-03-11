# GitHub Actions Workflows

CodeCaine 프로젝트의 CI/CD 파이프라인 워크플로우입니다.

## 워크플로우 목록

### 1. deploy-python.yml
Python 기반 서비스를 ECR에 빌드하고 ECS에 배포합니다.

**대상 서비스:**
- codecaine-history (히스토리 서비스)
- codecaine-mypage (마이페이지 서비스)
- codecaine-analysis (분석 서비스)
- codecaine-codef (CODEF API 서비스)

**트리거:**
- `main`, `develop` 브랜치에 `services/python/**` 경로 변경 시 자동 실행
- 수동 실행 (workflow_dispatch)

### 2. deploy-typescript.yml
TypeScript 기반 서비스를 ECR에 빌드하고 ECS에 배포합니다.

**대상 서비스:**
- codecaine-frontend (프론트엔드)

**트리거:**
- `main`, `develop` 브랜치에 `services/typescript/**` 경로 변경 시 자동 실행
- 수동 실행 (workflow_dispatch)

## 사전 요구사항

### GitHub Secrets 설정
다음 시크릿을 GitHub 레포지토리에 추가해야 합니다:

```
AWS_ACCESS_KEY_ID: AWS IAM 액세스 키
AWS_SECRET_ACCESS_KEY: AWS IAM 시크릿 키
```

### IAM 권한
GitHub Actions에서 사용하는 IAM 사용자는 다음 권한이 필요합니다:

- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:GetDownloadUrlForLayer`
- `ecr:BatchGetImage`
- `ecr:PutImage`
- `ecr:InitiateLayerUpload`
- `ecr:UploadLayerPart`
- `ecr:CompleteLayerUpload`
- `ecs:DescribeTaskDefinition`
- `ecs:RegisterTaskDefinition`
- `ecs:UpdateService`
- `ecs:DescribeServices`
- `ecs:ListTasks`
- `ecs:DescribeTasks`
- `iam:PassRole`

## 프로젝트 구조

```
services/
├── python/
│   ├── history/
│   │   ├── Dockerfile
│   │   └── ...
│   ├── mypage/
│   │   ├── Dockerfile
│   │   └── ...
│   ├── analysis/
│   │   ├── Dockerfile
│   │   └── ...
│   └── codef/
│       ├── Dockerfile
│       └── ...
└── typescript/
    └── frontend/
        ├── Dockerfile
        └── ...
```

## 수동 배포 방법

1. GitHub 레포지토리의 "Actions" 탭으로 이동
2. 배포할 워크플로우 선택 (deploy-python 또는 deploy-typescript)
3. "Run workflow" 버튼 클릭
4. 배포할 서비스 선택
5. "Run workflow" 실행

## 배포 확인

워크플로우는 다음 정보를 출력합니다:

- 배포된 이미지 태그
- ECS 서비스 상태 (serviceName, status, runningCount, desiredCount)
- 실행 중인 태스크 정보 (taskArn, lastStatus, healthStatus, image)

## ECR 레포지토리

| 레포지토리 | 서비스 | 언어 |
|-----------|--------|------|
| codecaine-history | 히스토리 서비스 | Python |
| codecaine-mypage | 마이페이지 서비스 | Python |
| codecaine-analysis | 분석 서비스 | Python |
| codecaine-codef | CODEF API | Python |
| codecaine-frontend | 프론트엔드 | TypeScript |

## 트러블슈팅

### 배포 실패 시
1. GitHub Actions 로그 확인
2. ECS 서비스 이벤트 확인: `aws ecs describe-services --cluster cdci-prd-cluster --services <service-name>`
3. CloudWatch Logs 확인

### ECR 로그인 실패
- AWS 자격 증명 확인
- IAM 권한 확인

### ECS 배포 타임아웃
- 태스크 정의의 헬스체크 설정 확인
- 컨테이너 로그 확인
