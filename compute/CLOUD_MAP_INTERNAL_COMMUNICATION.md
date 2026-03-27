# ECS 서비스 간 내부 통신 설정 — AWS Cloud Map

> Analysis Backend → User 서비스 VPC 내부 직접 호출을 위한 인프라 변경사항

---

## 배경

Analysis Backend(`codecaine-python-analysis`)의 `/chat-calculate` 엔드포인트에서
User 서비스의 `/users/codef/internal-service/{cognito_id}`를 JWT 없이 VPC 내부에서 호출해야 함.

기존에는 internet-facing ALB를 통해 JWT와 함께 호출하는 방식이었으나,
내부 서비스 간 통신은 VPC 내부로 격리하여 JWT 없이 처리하는 구조로 변경.

---

## 개념 설명

### Private DNS Namespace란?

AWS Cloud Map에서 **VPC 내부 전용 DNS 도메인**을 만드는 리소스.

일반 인터넷 DNS와 달리 해당 VPC 안에서만 resolve되는 도메인으로,
외부에서는 존재 자체를 알 수 없음.

```
codecaine-prd.internal   ← 이 도메인은 VPC 내부에서만 존재
```

**왜 namespace로 추가하는가 — ECS 내부 구조 관점**

ECS Fargate는 `awsvpc` 네트워크 모드를 사용한다. 이 모드에서는 각 태스크가
**고유한 ENI(Elastic Network Interface)** 와 **private IP** 를 독립적으로 할당받는다.

문제는 이 IP가 태스크가 재시작될 때마다 바뀐다는 것이다.

```
태스크 재시작 전: users 태스크 IP = 10.0.1.45
태스크 재시작 후: users 태스크 IP = 10.0.2.83  ← 바뀜
```

따라서 IP를 직접 사용하는 방식은 불가능하고, **DNS 이름으로 찾아가는 구조**가 필요하다.
Private DNS Namespace는 이 DNS 이름의 루트 도메인(`codecaine-prd.internal`)을 정의하는 역할이다.
서비스 디스커버리 서비스들은 이 namespace 아래에 등록된다.

---

### Service Discovery란?

**ECS 태스크가 시작/종료될 때 DNS 레코드를 자동으로 등록/해제**해주는 메커니즘.

```
태스크 시작 → Cloud Map이 자동으로 DNS 등록
  users.codecaine-prd.internal  A  10.0.1.45

태스크 재시작 → Cloud Map이 자동으로 DNS 갱신
  users.codecaine-prd.internal  A  10.0.2.83
```

`routing_policy = "MULTIVALUE"`는 users 태스크가 2개 이상 떠 있을 때
두 IP를 모두 반환하여 클라이언트 사이드 로드밸런싱이 가능하게 한다.

```
태스크 2개 실행 중:
users.codecaine-prd.internal  A  10.0.1.45
users.codecaine-prd.internal  A  10.0.2.83  ← 둘 다 반환
```

즉 Service Discovery는 "이 서비스의 이름(users)과 namespace(codecaine-prd.internal)를
조합하면 현재 살아있는 태스크 IP를 찾을 수 있다"는 매핑 정보를 관리하는 레지스트리다.

---

### service_registries란?

ECS 서비스 리소스에 추가하는 블록으로, **이 ECS 서비스를 어떤 Service Discovery에 연결할지** 지정한다.

```hcl
service_registries {
  registry_arn = aws_service_discovery_service.users.arn
}
```

이 블록이 있어야 ECS가 태스크를 시작/종료할 때 Cloud Map에 자동으로 DNS 레코드를 등록/해제한다.
없으면 Service Discovery 리소스를 만들어도 DNS에 아무것도 등록되지 않는다.

세 가지 리소스의 관계 요약:

```
Private DNS Namespace   → 도메인 공간 정의 (codecaine-prd.internal)
        ↓
Service Discovery       → "users"라는 이름으로 이 namespace에 등록
        ↓
service_registries      → ECS 태스크가 뜰 때 위 Service Discovery에 IP 자동 등록
```

---

## 변경 내용 (`compute/ecs.tf`)

### 1. AWS Cloud Map — Private DNS 네임스페이스 추가

```hcl
resource "aws_service_discovery_private_dns_namespace" "internal" {
  name = "${var.project_name}-${var.environment}.internal"
  vpc  = local.vpc_id
}
```

VPC 내부 전용 DNS 도메인 생성.
예: `codecaine-prd.internal`

---

### 2. 전체 서비스 Service Discovery 등록

`for_each`로 모든 서비스에 대해 일괄 생성:

```hcl
resource "aws_service_discovery_service" "services" {
  for_each = local.services

  name = each.value.name

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.internal.id
    routing_policy = "MULTIVALUE"
    dns_records { type = "A"; ttl = 10 }
  }
  health_check_custom_config { failure_threshold = 1 }
}
```

생성되는 내부 DNS:

| 서비스 | 내부 DNS |
|---|---|
| users | `users.codecaine-prd.internal:8000` |
| analysis | `analysis.codecaine-prd.internal:8000` |
| chatbot | `chatbot.codecaine-prd.internal:8000` |
| history | `history.codecaine-prd.internal:8000` |
| frontend | `frontend.codecaine-prd.internal:8080` |

---

### 3. 전체 ECS 서비스에 service_registries 추가

모든 서비스에 일괄 적용:

```hcl
service_registries {
  registry_arn = aws_service_discovery_service.services[each.key].arn
}
```

---

### 4. 전체 서비스 공통 환경변수에 각 서비스 URL 추가

모든 서비스에 아래 env 일괄 주입. 사용하지 않는 서비스는 무시.

```hcl
{ name = "USER_SERVICE_URL",     value = "http://users.${project}-${env}.internal:8000" },
{ name = "ANALYSIS_SERVICE_URL", value = "http://analysis.${project}-${env}.internal:8000" },
{ name = "CHATBOT_SERVICE_URL",  value = "http://chatbot.${project}-${env}.internal:8000" },
{ name = "HISTORY_SERVICE_URL",  value = "http://history.${project}-${env}.internal:8000" },
```

현재 실제 사용 중인 서비스:
- Analysis Backend → `USER_SERVICE_URL` (`user_client.py` 내부 호출)

---

## 호출 흐름

```
Analysis Backend ECS
    ↓ http://users.codecaine-prd.internal:8000/users/codef/internal-service/{id}
    ↓ VPC 내부 DNS resolve (Cloud Map)
    ↓ users ECS 태스크 private IP:8000
User 서비스 ECS
```

---

## Security Group

**별도 변경 없음.** 기존 룰이 이미 커버함.

```hcl
# foundation/security_groups.tf — 기존 존재
resource "aws_security_group_rule" "ecs_ingress_self" {
  description = "Inter-service communication"
  from_port   = 8000
  to_port     = 8000
  self        = true  # 같은 SG 내 ECS 태스크끼리 8000 포트 허용
  ...
}
```

모든 ECS 서비스가 동일한 `ecs_tasks` SG를 사용하므로 포트 8000 내부 통신은 이미 허용.

---

## 인증 방식

| 구분 | 방식 |
|---|---|
| 외부 → User 서비스 | internet-facing ALB + JWT (기존 동일) |
| Analysis Backend → User 서비스 (내부) | Cloud Map DNS + JWT 없음 |

내부 엔드포인트(`/internal-service`)는 VPC 네트워크 격리로 보호.
외부 노출 차단은 **API Gateway에서 해당 경로 차단**으로 처리 (별도 작업 필요).

---

## 고려해야 할 문제점 및 대응 방안

현재 방식의 핵심 리스크: **신뢰 경계가 VPC 네트워크에 과하게 의존한다.**

---

### 1. "VPC 내부 = 안전"이라는 가정이 너무 강함

**문제**
지금 구조는 같은 VPC 안에서 온 요청이면 trusted로 처리한다.
서비스가 늘어나거나 배치/테스트 태스크가 붙으면, 원래 internal API를 호출하면 안 되는 태스크도 같은 SG 안에 있다는 이유만으로 호출 가능해진다.

**대응**
- 우선: API Gateway에서 `/internal-service/*` 경로 차단 확실히 완료
- 중기: Shared Secret(`X-Internal-Token` 헤더) 추가로 최소한의 앱 레벨 인증 보강
- 장기: SigV4 / mTLS 도입 검토

---

### 2. API Gateway 차단 누락 시 외부 노출 위험

**문제**
`/internal-service` 엔드포인트는 JWT가 없다. API Gateway 차단이 실수로 누락되거나 라우팅에 포함되면, 인증 없는 엔드포인트가 외부에 노출된다.

**대응**
- API Gateway에서 해당 경로 차단은 **이 구조의 필수 전제조건**으로 반드시 완료 필요 (현재 미완료)
- 차단 설정 후 외부에서 실제로 막히는지 검증

---

### 3. 서비스 compromise 시 횡적 이동(lateral movement) 취약

**문제**
서비스 간 인증이 없으므로 한 서비스가 침해되면, 해당 서비스에서 다른 internal API를 자유롭게 호출 가능하다.

**대응**
- 최소: 서비스별 Shared Secret으로 "누가 보냈는지" 확인
- 추가: SG를 서비스별로 분리하여 불필요한 east-west traffic 차단

---

### 4. Cloud Map 직접 호출은 ALB 보호막 없음

**문제**
Cloud Map은 태스크 private IP로 직접 연결된다. ALB가 제공하는 아래 기능이 없다:
- Connection draining (배포 시 기존 연결 정리)
- 중앙화된 access log
- 세밀한 health check 및 routing

**대응**
- 트래픽이 늘거나 운영 복잡도가 높아지면 internal ALB로 전환 검토
- 현재 규모에서는 Cloud Map으로 충분하지만, 배포 빈도 많아지면 재검토

---

### 5. DNS 캐싱으로 인한 stale 연결 가능성

**문제**
Cloud Map은 DNS 기반이라 태스크 재배포 직후 일시적으로 예전 IP를 바라볼 수 있다.
TTL을 10초로 설정했지만, 애플리케이션 HTTP client가 DNS를 자체 캐싱하면 완전히 해결되지 않는다.

**대응**
- HTTP client의 connection pool / DNS 캐시 TTL 설정 확인
- 배포 시 graceful shutdown + 재시도 로직 추가

---

### 6. 같은 SG self 허용은 서비스 증가 시 과도하게 열림

**문제**
현재는 모든 ECS 서비스가 동일한 `ecs_tasks` SG를 공유하고 `self` 룰로 8000 포트를 허용한다.
서비스가 5~6개로 늘면 필요 없는 서비스 간 통신까지 모두 열려 있는 구조가 된다.

**대응**
- 현재 규모에서는 허용 가능
- 서비스 수 증가 시 서비스별 SG 분리 후 필요한 방향만 허용 (`analysis SG → users SG 8000` 등)

---

### 7. 공통 env 주입으로 인한 경계 희석

**문제**
모든 서비스에 `USER_SERVICE_URL`, `ANALYSIS_SERVICE_URL` 등을 일괄 주입하면, 호출하면 안 되는 서비스도 해당 URL 정보를 알게 된다. 서비스가 늘어날수록 "누가 누구를 호출해야 하는지"가 코드에서 불명확해진다.

**대응**
- 현재 규모에서는 실용적인 선택
- 장기적으로는 호출 관계를 `docs/service-dependency.md` 등으로 명시적으로 관리

---

### 8. Observability 미비 시 장애 원인 파악 어려움

**문제**
ALB 없는 직접 호출 구조에서 "users가 느린지, DNS가 꼬인 건지, analysis timeout이 짧은 건지" 구분이 어렵다.

**대응 (현재 OTEL 설정이 있으므로 아래 항목 확인)**
- 서비스 간 request ID 전파
- 서비스 간 호출 로그 (호출 대상 URL, 응답 시간, 상태 코드)
- timeout / retry 설정 명시
- X-Ray trace에서 서비스 간 span 연결 확인

---

### 9. 장애 전파 — timeout / retry 미설계 시 연쇄 지연

**문제**
`analysis → users` 호출 timeout이 길거나 retry가 과하면, users 하나 느려진 게 analysis task까지 잡아먹고 전체 서비스 지연으로 번진다.

**대응**
- 내부 호출 timeout 짧게 설정 (예: 3~5초)
- retry는 idempotent한 GET에만 적용, POST는 신중하게
- Circuit Breaker 패턴 도입 검토

---

### 우선순위 요약

| 우선순위 | 항목 | 상태 |
|---|---|---|
| 즉시 | API Gateway `/internal-service/*` 경로 차단 | 미완료 |
| 단기 | timeout / retry / tracing 설정 | 확인 필요 |
| 중기 | Shared Secret 내부 인증 추가 | 선택사항 |
| 장기 | SG 서비스별 분리 | 서비스 수 증가 시 |
| 장기 | Cloud Map → internal ALB 전환 검토 | 트래픽 증가 시 |

---

## User 서비스 코드 변경사항

`codecaine-python-users` 레포에 신규 엔드포인트 추가됨:

```
GET /users/codef/internal-service/{cognito_id}
```

- JWT 인증 없음
- VPC 내부 전용 (API Gateway에서 외부 차단 필요)
- 기존 `/internal-call/{cognito_id}`와 동일한 응답 구조

담당: User 서비스 팀원 확인 필요.
