# CodeCaine Frontend Service

## 🚀 빠른 시작

### 1. 의존성 설치 (필수!)
```bash
cd services/typescript/frontend
npm install
```

### 2. 개발 서버 실행
```bash
npm run dev
```

### 3. 프로덕션 빌드
```bash
npm run build
npm start
```

## ⚠️ 문제 해결

### TypeScript 에러가 발생하는 경우
```bash
# node_modules 삭제 후 재설치
rm -rf node_modules package-lock.json
npm install
```

### 포트가 이미 사용 중인 경우
```bash
# 다른 포트로 실행하려면 환경변수 설정
PORT=3001 npm run dev
```

## 📦 설치된 패키지
- `express`: 웹 서버 프레임워크
- `typescript`: TypeScript 컴파일러
- `@types/node`: Node.js 타입 정의
- `@types/express`: Express 타입 정의
- `ts-node`: TypeScript 직접 실행
