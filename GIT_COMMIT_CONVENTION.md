# Git Commit Convention

CodeCaine 프로젝트의 Git 커밋 메시지 작성 규칙입니다.

## 기본 구조

```
<type>(<scope>): <subject>

<body>

<footer>
```

## Type (필수)

커밋의 타입을 나타냅니다.

| Type | 설명 | 예시 |
|------|------|------|
| `feat` | 새로운 기능 추가 | `feat(history): 히스토리 조회 API 추가` |
| `fix` | 버그 수정 | `fix(mypage): 프로필 업데이트 오류 수정` |
| `docs` | 문서 수정 | `docs(readme): 설치 가이드 업데이트` |
| `style` | 코드 포맷팅, 세미콜론 누락 등 | `style(analysis): 코드 포맷팅 적용` |
| `refactor` | 코드 리팩토링 | `refactor(chatbot): 응답 로직 개선` |
| `test` | 테스트 코드 추가/수정 | `test(frontend): 로그인 테스트 추가` |
| `chore` | 빌드, 패키지 매니저 설정 | `chore(deps): axios 버전 업데이트` |
| `perf` | 성능 개선 | `perf(analysis): 쿼리 최적화` |
| `ci` | CI/CD 설정 변경 | `ci(github): 배포 워크플로우 수정` |
| `build` | 빌드 시스템 변경 | `build(docker): Dockerfile 최적화` |
| `revert` | 이전 커밋 되돌리기 | `revert: feat(history): 히스토리 API 제거` |

## Scope (선택)

변경 사항의 범위를 나타냅니다.

**서비스별:**
- `history` - 히스토리 서비스
- `mypage` - 마이페이지 서비스
- `analysis` - 분석 서비스
- `chatbot` - 챗봇 서비스
- `frontend` - 프론트엔드

**인프라:**
- `terraform` - Terraform 코드
- `ecs` - ECS 설정
- `alb` - ALB 설정
- `ecr` - ECR 설정
- `rds` - RDS 설정
- `dynamodb` - DynamoDB 설정

**기타:**
- `github` - GitHub Actions
- `docker` - Docker 설정
- `deps` - 의존성

## Subject (필수)

변경 사항을 간결하게 설명합니다.

**규칙:**
- 50자 이내로 작성
- 명령형으로 작성 (예: "추가", "수정", "제거")
- 마침표 없음
- 한글 또는 영어 사용

**좋은 예:**
```
feat(history): 날짜별 히스토리 필터링 기능 추가
fix(mypage): 프로필 이미지 업로드 오류 수정
docs(readme): API 문서 링크 추가
```

**나쁜 예:**
```
update code
fixed bug
히스토리 기능
```

## Body (선택)

변경 사항의 상세 내용을 설명합니다.

**규칙:**
- Subject와 한 줄 띄우기
- 무엇을, 왜 변경했는지 설명
- 어떻게 변경했는지는 코드로 확인 가능하므로 생략 가능

**예시:**
```
feat(history): 날짜별 히스토리 필터링 기능 추가

사용자가 특정 기간의 히스토리만 조회할 수 있도록
날짜 범위 필터링 기능을 추가했습니다.

- 시작일/종료일 파라미터 추가
- 날짜 유효성 검증 로직 추가
- 페이지네이션 유지
```

## Footer (선택)

이슈 트래커 ID, Breaking Change 등을 명시합니다.

**이슈 참조:**
```
Closes #123
Fixes #456
Resolves #789
```

**Breaking Change:**
```
BREAKING CHANGE: API 응답 형식 변경

기존 { data: [] } 형식에서
{ items: [], total: 0 } 형식으로 변경
```

## 전체 예시

### 예시 1: 기능 추가
```
feat(history): 날짜별 히스토리 필터링 기능 추가

사용자가 특정 기간의 히스토리만 조회할 수 있도록
날짜 범위 필터링 기능을 추가했습니다.

Closes #123
```

### 예시 2: 버그 수정
```
fix(mypage): 프로필 이미지 업로드 오류 수정

파일 크기 제한을 5MB로 증가하고
지원 형식에 WebP 추가

Fixes #456
```

### 예시 3: 인프라 변경
```
ci(github): ECS 배포 워크플로우 타임스탬프 태그 추가

이미지 태그에 UTC 타임스탬프를 추가하여
배포 시간 추적이 가능하도록 개선
```

### 예시 4: 리팩토링
```
refactor(chatbot): 응답 생성 로직 모듈화

중복 코드를 제거하고 재사용 가능한
ResponseGenerator 클래스로 분리
```

### 예시 5: 문서 업데이트
```
docs(readme): 로컬 개발 환경 설정 가이드 추가

Docker Compose를 사용한 로컬 개발 환경
설정 방법을 README에 추가
```

## 커밋 메시지 작성 팁

1. **작은 단위로 커밋**
   - 하나의 커밋은 하나의 목적만
   - 여러 변경사항은 여러 커밋으로 분리

2. **명확하고 구체적으로**
   - "코드 수정" ❌
   - "로그인 API 응답 시간 개선" ✅

3. **현재형 사용**
   - "추가했음" ❌
   - "추가" ✅

4. **이슈 번호 연결**
   - GitHub Issues와 연동하여 추적 가능

5. **Breaking Change 명시**
   - API 변경 등 호환성이 깨지는 경우 반드시 명시

## Git Hooks (선택)

커밋 메시지 검증을 자동화할 수 있습니다.

```bash
# .git/hooks/commit-msg
#!/bin/bash

commit_msg=$(cat "$1")
pattern="^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .{1,50}"

if ! echo "$commit_msg" | grep -qE "$pattern"; then
    echo "❌ 커밋 메시지 형식이 올바르지 않습니다."
    echo "형식: <type>(<scope>): <subject>"
    exit 1
fi
```

## 참고 자료

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Angular Commit Guidelines](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit)
- [Semantic Versioning](https://semver.org/)

## 자주 사용하는 커밋 예시

```bash
# 기능 추가
git commit -m "feat(history): 검색 기능 추가"

# 버그 수정
git commit -m "fix(mypage): 프로필 저장 오류 수정"

# 문서 수정
git commit -m "docs(api): API 명세서 업데이트"

# 리팩토링
git commit -m "refactor(chatbot): 코드 구조 개선"

# 테스트 추가
git commit -m "test(analysis): 단위 테스트 추가"

# 의존성 업데이트
git commit -m "chore(deps): axios 버전 업데이트"

# CI/CD 수정
git commit -m "ci(github): 배포 워크플로우 개선"

# 인프라 변경
git commit -m "feat(terraform): ALB 경로 기반 라우팅 추가"
```
