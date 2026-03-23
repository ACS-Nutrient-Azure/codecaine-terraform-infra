# Security Infrastructure

보안 관련 리소스 (Route53, ACM, WAF, Cognito)

## 포함 리소스

- **Route53**: DNS 관리 (기존 Zone 사용 또는 신규 생성)
- **ACM**: SSL/TLS 인증서 (무료)
- **WAF**: Web Application Firewall (비용 발생)
- **Shield**: DDoS 보호 (Standard는 무료, Advanced는 $3000/month)
- **Cognito**: 사용자 인증/인가 (MAU 기반 과금)

## ⚠️ Route53 Zone ID 필수 설정

ACM 인증서를 발급받으려면 **Route53 Zone ID가 반드시 필요**합니다.

### 🚀 빠른 시작

**Zone ID를 모르시나요?** 자동으로 찾아주는 스크립트를 실행하세요:

```bash
# Linux/Mac
./find_zone_id.sh

# Windows PowerShell
.\find_zone_id.ps1
```

**자세한 설명이 필요하신가요?**
👉 **[ROUTE53_ZONE_ID_가이드.md](./ROUTE53_ZONE_ID_가이드.md)** - 초보자를 위한 완벽 가이드

### 왜 필요한가?
ACM 인증서는 DNS 검증 방식을 사용하며, Route53에 자동으로 검증 레코드를 생성합니다.
Zone ID가 없으면 검증 레코드를 생성할 수 없어 **인증서 발급이 실패**합니다.

### 빠른 해결 방법

#### 옵션 1: 기존 Route53 Zone 사용 (권장)
이미 도메인을 Route53에서 관리하고 있다면 이 방법을 사용하세요.

1. Zone ID 찾기:
```bash
# AWS CLI 사용
aws route53 list-hosted-zones --query "HostedZones[?Name=='www.codecaine.store.'].Id" --output text | cut -d'/' -f3
```

2. `terraform.tfvars` 설정:
```hcl
create_route53_zone = false
route53_zone_id     = "Z1234567890ABC"  # 실제 Zone ID 입력
domain_name         = "www.codecaine.store"
```

#### 옵션 2: 신규 Route53 Zone 생성
도메인을 Route53에서 관리하지 않는다면 새로 생성할 수 있습니다.

1. `terraform.tfvars` 설정:
```hcl
create_route53_zone = true
route53_zone_id     = ""  # 비워두기
domain_name         = "www.codecaine.store"
```

2. Terraform 배포 후 Name Server 확인:
```bash
terraform output route53_name_servers
```

3. 도메인 등록 업체(가비아, Route53 등)에서 Name Server 변경:
```
ns-123.awsdns-12.com
ns-456.awsdns-45.net
ns-789.awsdns-78.org
ns-012.awsdns-01.co.uk
```

### Zone ID를 설정하지 않으면?
```
Error: route53_zone_id must be provided when create_route53_zone is false
```
위와 같은 에러가 발생하며 ACM 인증서 발급이 실패합니다.

**📚 더 자세한 설명**: [ROUTE53_ZONE_ID_가이드.md](./ROUTE53_ZONE_ID_가이드.md)

## WAF 비용

- Web ACL: $5/month
- Rule: $1/month per rule
- Request: $0.60 per 1M requests

## Cognito 비용

- MAU (Monthly Active Users) 기반
- 처음 50,000 MAU: 무료
- 이후: $0.0055 per MAU

## Shield (DDoS 보호)

### Shield Standard (무료 - 자동 활성화)
AWS Shield Standard는 모든 AWS 고객에게 자동으로 제공되는 무료 DDoS 방어 서비스입니다.

**보호 대상:**
- Amazon CloudFront
- Amazon Route 53
- Elastic Load Balancing (ALB, CLB, NLB)
- AWS Global Accelerator
- Elastic IP addresses

**기능:**
- Layer 3/4 DDoS 공격 자동 탐지 및 완화
- 항상 활성화된 네트워크 흐름 모니터링
- 인라인 공격 완화 (지연 시간 최소화)
- 별도 설정 불필요 (자동 활성화)

**비용:** 무료

### Shield Advanced (사용 안 함)
Shield Advanced는 $3,000/month의 높은 비용으로 인해 사용하지 않습니다.
대부분의 애플리케이션은 Shield Standard로 충분한 보호를 받을 수 있습니다.

## Cognito 사용 예제

```javascript
// AWS Amplify 사용
import { Amplify, Auth } from 'aws-amplify';

Amplify.configure({
  Auth: {
    region: 'ap-northeast-2',
    userPoolId: 'ap-northeast-2_XXXXXXXXX',
    userPoolWebClientId: 'XXXXXXXXXXXXXXXXXXXXXXXXXX',
  }
});

// 로그인
await Auth.signIn(username, password);

// 로그아웃
await Auth.signOut();
```
