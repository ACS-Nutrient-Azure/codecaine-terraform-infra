# CodeCaine Services

CodeCaine 프로젝트의 마이크로서비스 디렉토리입니다.

## 서비스 목록

### Python 서비스 (4개)

#### 1. Analysis Service
- **경로**: `services/python/analysis/`
- **포트**: 8080
- **설명**: 데이터 분석 서비스
- **엔드포인트**:
  - `GET /health` - 헬스체크
  - `POST /api/analyze` - 분석 실행

#### 2. Chatbot Service
- **경로**: `services/python/chatbot/`
- **포트**: 8080
- **설명**: 챗봇 서비스
- **엔드포인트**:
  - `GET /health` - 헬스체크
  - `POST /api/chat` - 챗봇 대화

#### 3. CODEF Service
- **경로**: `services/python/codef/`
- **포트**: 8080
- **설명**: CODEF API 연동 서비스
- **엔드포인트**:
  - `GET /health` - 헬스체크
  - `GET /api/codef/data` - CODEF 데이터 조회

#### 4. MyPage Service
- **경로**: `services/python/mypage/`
- **포트**: 8080
- **설명**: 마이페이지 서비스
- **엔드포인트**:
  - `GET /health` - 헬스체크
  - `GET /api/mypage/profile` - 프로필 조회

### TypeScript 서비스 (1개)

#### 5. Frontend Service
- **경로**: `services/typescript/frontend/`
- **포트**: 8080
- **설명**: 프론트엔드 서비스
- **엔드포인트**:
  - `GET /health` - 헬스체크
  - `GET /` - 메인 페이지

## 로컬 테스트

### Python 서비스 테스트

```bash
# Analysis 서비스
cd services/python/analysis
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
python app.py

# 테스트
curl http://localhost:8080/health
curl -X POST http://localhost:8080/api/analyze
```

### TypeScript 서비스 테스트

```bash
# Frontend 서비스
cd services/typescript/frontend
npm install
npm run dev

# 테스트
curl http://localhost:8080/health
curl http://localhost:8080/
```

## Docker 빌드 및 실행

### Python 서비스

```bash
# Analysis 예시
cd services/python/analysis
docker build -t codecaine-analysis:latest .
docker run -p 8080:8080 codecaine-analysis:latest

# 테스트
curl http://localhost:8080/health
```

### TypeScript 서비스

```bash
# Frontend
cd services/typescript/frontend
docker build -t codecaine-frontend:latest .
docker run -p 8080:8080 codecaine-frontend:latest

# 테스트
curl http://localhost:8080/health
```

## ECR 푸시 (수동)

```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 365827924759.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 태그 및 푸시
docker tag codecaine-analysis:latest 365827924759.dkr.ecr.ap-northeast-2.amazonaws.com/codecaine-analysis:latest
docker push 365827924759.dkr.ecr.ap-northeast-2.amazonaws.com/codecaine-analysis:latest
```

## GitHub Actions 자동 배포

코드를 `main` 또는 `develop` 브랜치에 푸시하면 자동으로 빌드 및 배포됩니다.

자세한 내용은 `.github/workflows/README.md`를 참조하세요.

## 프로젝트 구조

```
services/
├── python/
│   ├── analysis/
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   ├── chatbot/
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   ├── codef/
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   └── mypage/
│       ├── app.py
│       ├── requirements.txt
│       └── Dockerfile
└── typescript/
    └── frontend/
        ├── src/
        │   └── index.ts
        ├── package.json
        ├── tsconfig.json
        └── Dockerfile
```

## 환경 변수

모든 서비스는 다음 환경 변수를 지원합니다:

- `PORT`: 서비스 포트 (기본값: 8080)

추가 환경 변수는 각 서비스의 ECS Task Definition에서 설정할 수 있습니다.
