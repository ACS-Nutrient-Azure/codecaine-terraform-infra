# FIS (AWS Fault Injection Simulator) 카오스 엔지니어링

## 1. 개요

### 목적

이 모듈은 **cdci-prd** 프로덕션 환경의 복원력(Resilience)을 검증하기 위한 AWS FIS 실험 템플릿을 관리합니다.
14개의 시나리오를 통해 개별 컴포넌트 장애부터 리전 수준 DR 전환까지 단계적으로 검증합니다.

### 인프라 구성 요약

| 구분 | 구성 |
|------|------|
| **프로젝트** | cdci-prd |
| **Primary 리전** | ap-northeast-2 (서울) |
| **DR 리전** | ap-northeast-1 (도쿄) |
| **ECS Fargate 서비스** | users, history, chatbot, analysis, frontend (5개) |
| **Aurora Global DB** | users-cluster, history-cluster, analysis-cluster, chatbot-cluster (PostgreSQL Serverless v2) |
| **ElastiCache Redis** | chatbot 전용 (cache.t3.micro 단일 노드) |
| **NAT Gateway** | 단일 (ap-northeast-2a) |
| **AgentCore Runtime** | analysis, chatbot, summary (3개) |

**VPC 서브넷 구성**

| 유형 | 2a | 2c |
|------|----|----|
| Public | 10.0.1.0/24 | 10.0.2.0/24 |
| Private App | 10.0.11.0/24 | 10.0.12.0/24 |
| Private DB | 10.0.21.0/24 | 10.0.22.0/24 |

### DR 트리거 조건

DR Composite Alarm(`cdci-prd-DR-TRIGGER`)은 **2개 레이어 이상 동시 ALARM** 시 발화합니다.

| 레이어 | 알람 조건 | 감지 시간 |
|--------|-----------|-----------|
| **ECS 레이어** | users + history + chatbot 동시 UnhealthyHostCount ≥ 1 | ALB 헬스체크 30초 × 3회 = **90초** |
| **Aurora 레이어** | 4개 클러스터 중 2개 이상 DatabaseConnections = 0 | 60초 × 2회 = **120초** |
| **AgentCore 레이어** | Health Check Lambda 3회 연속 실패 | 1분 × 3회 = **3분** |

DR Composite Alarm 발화 → EventBridge → Step Functions DR Orchestrator 자동 실행

DR Composite Alarm OK 전환 → EventBridge → Step Functions DR Failback Orchestrator 자동 실행 (서울 자동 복구)

---

## 2. 시나리오 전체 요약

| # | 시나리오명 | 대상 레이어 | DR 트리거 | 예상 RTO | 예상 RPO | 위험도 |
|---|-----------|------------|----------|---------|---------|--------|
| 01 | ECS 태스크 강제 종료 | ECS | ❌ | 30~90초 | 0 | 🟢 낮음 |
| 02 | ECS CPU 부하 주입 | ECS | ❌ | 2~5분 | 0 | 🟢 낮음 |
| 03 | Aurora 클러스터 강제 페일오버 | Aurora | ❌ | 30~60초 | < 1초 | 🟡 중간 |
| 04 | Aurora Reader 재부팅 | Aurora | ❌ | 1~2분 | 0 (Writer 유지) | 🟢 낮음 |
| 05 | ElastiCache Redis 장애 시뮬레이션 | Cache | ❌ | 실험 종료 즉시 | 0 | 🟢 낮음 |
| 06 | AZ 장애 시뮬레이션 | ECS + Network | ❌ | 2~4분 | 0 | 🟡 중간 |
| 07 | NAT Gateway 장애 | Network | ❌ | 실험 종료 즉시 | 0 | 🟡 중간 |
| 08 | DR 트리거 시뮬레이션 | ECS + Aurora | ✅ | **≤ 15분** | < 1초 | 🔴 높음 |
| 09 | ECS 메모리 부하 주입 | ECS | ❌ | 2~5분 | 0 | 🟢 낮음 |
| 10 | 멀티 서비스 연쇄 장애 | ECS (다중) | ❌ | 3~8분 | 0 | 🟡 중간 |
| 11 | Aurora Global DB Primary 격리 | Aurora + AgentCore | ✅ | **≤ 15분** | < 1초 | 🔴 높음 |
| 12 | AgentCore 레이어 장애 | AgentCore + Network | ⚠️ 조건부 | 3~5분 | 0 | 🟡 중간 |
| 13 | 점진적 ECS 서비스 저하 | ECS | ⚠️ 조건부 | 5~15분 | 0 | 🟡 중간 |
| 14 | 리전 수준 장애 시뮬레이션 | ECS + Aurora + Network | ✅ | **≤ 15분** | < 1초 | 🔴 높음 |

> ⚠️ **조건부**: 다른 레이어 장애와 동시 발생 시 DR 트리거 가능

---

## 3. 시나리오 상세

### 시나리오 01: ECS 태스크 강제 종료

**목적**
ECS 서비스의 `desired_count` 유지 메커니즘과 ALB 헬스체크 기반 트래픽 재라우팅을 검증합니다.

**장애 주입 방식**
- users 서비스 태스크 50% 강제 종료 (`aws:ecs:stop-task`)
- 완료 후 chatbot 서비스 태스크 50% 강제 종료 (순차)

**예상 타임라인**

| 시간 | 이벤트 |
|------|--------|
| T+0:00 | users 태스크 50% 종료 |
| T+0:30 | ALB 헬스체크 실패 감지 시작 |
| T+1:30 | ALB가 unhealthy 태스크 제외, 정상 태스크로만 라우팅 |
| T+1:30 | ECS가 새 태스크 자동 재시작 시작 |
| T+2:00 | chatbot 태스크 50% 종료 (users 액션 완료 후) |
| T+3:00 | 모든 태스크 정상 복구 완료 |

**예상 RTO / RPO**
- **RTO: 30~90초**
  - ECS 태스크 재시작: ~30초 (Fargate 콜드스타트 포함)
  - ALB 헬스체크 통과 후 트래픽 복구: +30~60초
- **RPO: 0** (태스크 종료는 데이터 손실 없음, DB는 정상 유지)

**검증 포인트**
- [ ] ECS 서비스 `RunningCount`가 `desired_count`로 복구되는지 확인
- [ ] ALB `UnhealthyHostCount` 알람이 ALARM → OK로 복구되는지 확인
- [ ] `deployment_circuit_breaker` 미발동 확인 (50% 종료이므로 롤백 불필요)
- [ ] 서비스 응답 지연(P99) 측정 및 SLA 내 복구 확인

**실험 후 복구 절차**
ECS 자동 복구 (별도 조치 불필요). CloudWatch에서 `RunningCount` 정상화 확인 후 완료.

---

### 시나리오 02: ECS CPU 부하 주입

**목적**
analysis 서비스의 CPU 기반 Auto Scaling 동작을 검증합니다. Scale-out 트리거(70%) 및 부하 해제 후 Scale-in 동작을 확인합니다.

**장애 주입 방식**
- analysis 서비스 전체 태스크에 CPU 90% 부하 10분간 주입 (`aws:ecs:task-cpu-stress`)

**예상 타임라인**

| 시간 | 이벤트 |
|------|--------|
| T+0:00 | CPU 90% 부하 주입 시작 |
| T+1:00 | CPUUtilization > 70% 지속 → Scale-out 정책 평가 |
| T+2:00 | Auto Scaling Scale-out 발동, 신규 태스크 기동 시작 |
| T+3:00 | 신규 태스크 ALB 헬스체크 통과, 부하 분산 |
| T+10:00 | 부하 주입 종료 |
| T+15:00 | Scale-in cooldown(300초) 후 태스크 수 정상화 |

**예상 RTO / RPO**
- **RTO: 2~5분** (Scale-out 정책 평가 1분 + Fargate 콜드스타트 ~90초 + 헬스체크 통과 ~30초)
- **RPO: 0** (CPU 부하는 데이터 손실 없음)

**검증 포인트**
- [ ] `CPUUtilization` 70% 초과 시 Scale-out 발동 확인
- [ ] Scale-out cooldown(60초) 내 신규 태스크 기동 확인
- [ ] 부하 해제 후 Scale-in cooldown(300초) 후 정상 태스크 수 복구 확인
- [ ] 부하 중 API 응답 오류율 측정

**실험 후 복구 절차**
부하 자동 해제 후 Scale-in cooldown 대기(5분). ECS 서비스 태스크 수 정상화 확인.

---

### 시나리오 03: Aurora 클러스터 강제 페일오버

**목적**
Aurora Writer → Reader 자동 승격 및 ECS 서비스의 DB 재연결 복구력을 검증합니다.

**장애 주입 방식**
- users-cluster 페일오버 (`aws:rds:failover-db-cluster`)
- 3분 후 history-cluster 페일오버 (순차 실행)

**예상 타임라인**

| 시간 | 이벤트 |
|------|--------|
| T+0:00 | users-cluster 페일오버 시작 |
| T+0:10 | Writer 인스턴스 교체 시작, 기존 연결 끊김 |
| T+0:30 | Reader → Writer 승격 완료, 클러스터 DNS 업데이트 |
| T+0:45 | ECS 서비스 DB 재연결 완료 (연결 풀 재시도) |
| T+3:00 | history-cluster 페일오버 시작 |
| T+3:45 | history-cluster 복구 완료 |

**예상 RTO / RPO**
- **RTO: 30~60초**
  - Aurora 페일오버 완료: ~30초
  - 앱 연결 풀 재연결: +15~30초 (클러스터 DNS 기반이므로 앱 코드 변경 불필요)
- **RPO: < 1초** (Aurora 클러스터 내 동기 복제, 데이터 손실 없음)

**검증 포인트**
- [ ] Aurora `DatabaseConnections` 메트릭 일시 0 후 복구 확인
- [ ] ECS 서비스 에러율 일시 증가 후 정상화 확인
- [ ] Secrets Manager 클러스터 엔드포인트 DNS 자동 전환 확인
- [ ] 페일오버 중 쓰기 트랜잭션 실패 건수 측정

**실험 후 복구 절차**
Aurora 자동 복구 (별도 조치 불필요). `aws rds describe-db-clusters`로 Writer 인스턴스 정상화 확인.

---

### 시나리오 04: Aurora Reader 재부팅

**목적**
DB 인스턴스 재부팅 시 ECS 서비스의 연결 풀 복구력을 검증합니다. Writer는 정상 유지되므로 쓰기 트래픽 영향 없이 읽기 경로만 검증합니다.

**장애 주입 방식**
- analysis-cluster Reader 인스턴스 재부팅 (`aws:rds:reboot-db-instances`)

**예상 타임라인**

| 시간 | 이벤트 |
|------|--------|
| T+0:00 | Reader 인스턴스 재부팅 시작 |
| T+0:10 | Reader 연결 끊김, 읽기 쿼리 실패 시작 |
| T+1:30 | Reader 재부팅 완료 |
| T+2:00 | 연결 풀 재연결 완료, 읽기 쿼리 정상화 |

**예상 RTO / RPO**
- **RTO: 1~2분** (재부팅 완료 ~90초 + 연결 풀 재연결 ~30초)
- **RPO: 0** (Writer 인스턴스 정상 유지, 데이터 손실 없음)

**검증 포인트**
- [ ] 재부팅 중 읽기 쿼리 실패 시 앱 레벨 retry 동작 확인
- [ ] Writer 인스턴스 정상 유지 확인 (쓰기 트래픽 영향 없음)
- [ ] 재부팅 완료 후 연결 풀 자동 재연결 확인
- [ ] analysis 서비스 에러율 측정 (읽기 실패 허용 범위 내인지 확인)

**실험 후 복구 절차**
자동 복구. `aws rds describe-db-instances`로 Reader 상태 `available` 확인.

---

### 시나리오 05: ElastiCache Redis 장애 시뮬레이션

**목적**
Redis 장애 시 chatbot 서비스의 세션/캐시 접근 불가에 대한 Graceful Degradation을 검증합니다.

**장애 주입 방식**
- Private App Subnet 2a egress 차단 8분 (`aws:network:disrupt-connectivity`, scope=egress)
- 이어서 Private App Subnet 2c egress 차단 7분 (순차)
- ECS → Redis 방향 연결 차단 (Redis 자체는 정상, 접근만 불가)

> ⚠️ **FIS 제약**: `cache.t3.micro` 단일 노드는 Replication Group이 없어 FIS ElastiCache 액션 사용 불가. 네트워크 차단 방식으로 대체.
> Redis 자체 재부팅이 필요하면 CLI로 수동 수행:
> ```bash
> aws elasticache reboot-cache-cluster \
>   --cache-cluster-id cdci-prd-chatbot-redis \
>   --cache-node-ids-to-reboot 0001
> ```

**예상 타임라인**

| 시간 | 이벤트 |
|------|--------|
| T+0:00 | Private App Subnet 2a egress 차단 시작 |
| T+0:30 | Private App Subnet 2c egress 차단 시작 |
| T+0:30 | chatbot 서비스 Redis 연결 불가 |
| T+0:30 | 세션 조회 실패 → 사용자 재인증 필요 (401 반환) |
| T+8:00 | 실험 종료, NACL 자동 복구 |
| T+8:30 | Redis 재연결, 세션 정상화 |

**예상 RTO / RPO**
- **RTO: 실험 종료 즉시** (NACL 복구 후 ~30초 내 Redis 재연결)
- **RPO: 0** (Redis 자체는 정상 동작 중, 데이터 손실 없음)

**검증 포인트**
- [ ] Redis 연결 실패 시 chatbot이 500이 아닌 401/503 반환 확인 (Graceful Degradation)
- [ ] 세션 소실 시 사용자 재로그인 유도 로직 동작 확인
- [ ] 실험 종료 후 Redis 재연결 및 세션 정상화 확인
- [ ] VPC 내부 통신(ECS ↔ RDS) 정상 유지 확인

**실험 후 복구 절차**
실험 종료 시 NACL 자동 복구. Redis 재연결 정상화 확인.

---

### 시나리오 06: AZ 장애 시뮬레이션

**목적**
ap-northeast-2a AZ 장애 시 ap-northeast-2c로의 자동 트래픽 전환 및 멀티-AZ 복원력을 검증합니다.

**장애 주입 방식**
- Private App Subnet 2a (10.0.11.0/24) 네트워크 완전 차단 15분 (`aws:network:disrupt-connectivity`, scope=all)
- NACL 기반 차단으로 실험 종료 시 자동 복구

**예상 타임라인**

| 시간 | 이벤트 |
|------|--------|
| T+0:00 | Private App Subnet 2a 차단 시작 |
| T+0:30 | ALB가 2a 태스크 헬스체크 실패 감지 시작 |
| T+1:30 | ALB가 2a 태스크 unhealthy 처리, 2c로만 라우팅 |
| T+2:00 | ECS Auto Scaling이 2c에 추가 태스크 기동 시작 |
| T+3:30 | 2c 추가 태스크 ALB 헬스체크 통과, 정상 서비스 |
| T+15:00 | 실험 종료, NACL 자동 복구 |
| T+15:30 | 2a 태스크 재기동, 정상 멀티-AZ 구성 복구 |

**예상 RTO / RPO**
- **RTO: 2~4분**
  - ALB 헬스체크 실패 감지: 90초 (30초 × 3회)
  - 2c 추가 태스크 기동 및 헬스체크 통과: +90초
- **RPO: 0** (DB Subnet은 정상, Aurora 2c 인스턴스 유지)

**검증 포인트**
- [ ] ALB가 2a 태스크 제외 후 2c로만 라우팅하는지 확인
- [ ] ECS Auto Scaling이 2c에 추가 태스크 기동하는지 확인
- [ ] Aurora가 2a Writer 장애 시 2c Reader로 자동 페일오버하는지 확인
- [ ] 전체 서비스 가용성 유지 확인 (일부 지연 허용)
- [ ] DR Composite Alarm 미발화 확인 (2c 정상이므로 ECS 레이어 조건 미충족)

**실험 후 복구 절차**
실험 종료 시 NACL 자동 복구. 2a 태스크 재기동 후 멀티-AZ 구성 정상화 확인.

---

### 시나리오 07: NAT Gateway 장애

**목적**
단일 NAT Gateway 장애 시 ECS 서비스의 외부 통신 의존성(ECR, Bedrock, Secrets Manager 등)과 VPC Endpoint 우회 경로를 검증합니다.

**장애 주입 방식**
- Private App Subnet 2a egress 차단 10분 (`aws:network:disrupt-connectivity`, scope=egress)
- 이어서 Private App Subnet 2c egress 차단 10분 (순차)
- VPC 내부 통신(ECS ↔ RDS, ECS ↔ Redis)은 유지

**예상 타임라인**

| 시간 | 이벤트 |
|------|--------|
| T+0:00 | 2a egress 차단 시작 |
| T+0:30 | 2c egress 차단 시작 |
| T+1:00 | Bedrock API 호출 실패 (ConnectionTimeout) |
| T+1:00 | ECR 이미지 pull 실패 (신규 태스크 기동 불가) |
| T+3:00 | AgentCore 헬스체크 3회 연속 실패 → agentcore_health ALARM |
| T+10:00 | 실험 종료, NACL 자동 복구 |
| T+10:30 | 외부 통신 정상화 |
| T+13:00 | AgentCore 알람 OK 전환 (~3분 소요) |

**예상 RTO / RPO**
- **RTO: 실험 종료 즉시** (NACL 복구 후 ~30초 내 외부 통신 정상화)
- **RPO: 0** (VPC 내부 DB 통신 유지, 데이터 손실 없음)

**검증 포인트**
- [ ] 실행 중인 ECS 태스크 정상 동작 확인 (이미 기동된 컨테이너는 영향 없음)
- [ ] 신규 태스크 기동 시 ECR pull 실패 확인
- [ ] Bedrock API 호출 실패 → analysis/chatbot 서비스 fallback 응답 확인
- [ ] VPC Endpoint 경유 서비스(S3, SSM 등) 정상 유지 확인
- [ ] Secrets Manager 캐시된 값 유지 확인

**실험 후 복구 절차**
실험 종료 시 NACL 자동 복구. AgentCore 알람 OK 전환까지 최대 3분 대기.

---

### 시나리오 08: DR 트리거 시뮬레이션 (복합 장애)

> ⚠️ **이 시나리오는 실제 DR을 트리거합니다. `dr/` 모듈 배포 완료 후에만 실행하세요.**

**목적**
ECS 레이어 + Aurora 레이어 동시 장애로 DR Composite Alarm을 트리거하고, Step Functions DR Orchestrator 자동 실행 전체 파이프라인을 검증합니다.

**장애 주입 방식**
1. users → history → chatbot 전체 태스크 순차 종료 (ECS 레이어 장애)
2. DB Subnet 2a → 2c 순차 차단 20분 (Aurora 레이어 장애)

**예상 타임라인**

| 시간 | 이벤트 |
|------|--------|
| T+0:00 | users 전체 태스크 종료 |
| T+0:30 | history 전체 태스크 종료 |
| T+1:00 | chatbot 전체 태스크 종료 |
| T+1:30 | ALB UnhealthyHostCount 알람 3개 동시 ALARM → ecs_layer_failure ALARM |
| T+1:30 | DB Subnet 2a 차단 시작 |
| T+2:00 | DB Subnet 2c 차단 시작 |
| T+3:30 | DatabaseConnections=0 알람 2개 이상 ALARM → aurora_layer_failure ALARM |
| T+3:30 | DR Composite Alarm ALARM → EventBridge 트리거 |
| T+3:35 | Step Functions DR Orchestrator 실행 시작 |
| T+4:35 | Aurora Global DB Failover 완료 (도쿄 Secondary → Primary, ~60초) |
| T+4:45 | SSM 파라미터 업데이트 완료 (~10초) |
| T+6:15 | DR ECS 서비스 활성화 완료 (desired_count 0→2, ~90초) |
| T+8:15 | AgentCore Runtime 프로비저닝 완료 (도쿄, ~120초) |
| T+8:45 | Route53 Failover Record 전환 완료 (~30초) |
| T+9:45 | TTL 60초 반영 완료, 도쿄 서비스 정상 수신 |
| T+18:35 | 총 DR 완료 (목표: 15분 이내) |

**예상 RTO / RPO**
- **RTO: ≤ 15분**
  - 장애 감지: ~3분 30초 (ECS 90초 + Aurora 120초 중 최대값)
  - Step Functions 실행: ~6분 15초 (Aurora Failover 60초 + SSM 10초 + ECS 활성화 90초 + AgentCore 120초 + Route53 30초)
  - DNS TTL 반영: ~60초
  - 총합: ~11분 (목표 15분 대비 여유 있음)
- **RPO: < 1초** (Aurora Global DB 동기 복제, 도쿄 Secondary는 서울과 거의 실시간 동기화)

**검증 포인트**
- [ ] DR Composite Alarm ALARM 전환 시간 측정
- [ ] Step Functions 각 단계 실행 시간 측정
- [ ] Aurora Global DB 도쿄 Secondary → Primary 승격 완료 확인
- [ ] Route53 Failover Record 도쿄 ALB로 전환 확인
- [ ] 도쿄 ECS 서비스 정상 응답 확인
- [ ] 전체 DR 완료 시간 15분 이내 달성 여부 확인

**실험 후 복구 절차**
DR Composite Alarm이 OK로 전환되면 `dr-failback-orchestrator` Step Functions가 자동 실행됩니다.

자동 Failback 단계: 서울 ALB 헬스체크 확인 → Aurora Global DB 서울 재승격 → SSM 파라미터 복구 → 서울 ECS 활성화 → 도쿄 ECS 비활성화 → 도쿄 AgentCore 삭제

자동 Failback이 실패한 경우 수동 복구:
```bash
# 1. 서울 ECS 서비스 재시작
aws ecs update-service --cluster cdci-prd --service users --desired-count 2 --region ap-northeast-2
aws ecs update-service --cluster cdci-prd --service history --desired-count 2 --region ap-northeast-2
aws ecs update-service --cluster cdci-prd --service chatbot --desired-count 2 --region ap-northeast-2

# 2. Aurora Global DB 서울 재동기화 (도쿄 → 서울 방향 역전)
# AWS 콘솔 또는 CLI로 Global DB Failback 수행

# 3. DR ECS 서비스 비활성화 (도쿄)
aws ecs update-service --cluster cdci-prd-dr --service users --desired-count 0 --region ap-northeast-1
```

---

### 시나리오 09: ECS 메모리 부하 주입

**목적**
chatbot 서비스의 메모리 기반 Auto Scaling 동작과 OOM Kill 발생 시 ECS 태스크 자동 재시작을 검증합니다.

**장애 주입 방식**
- chatbot 서비스 전체 태스크에 메모리 90% 부하 8분간 주입 (`aws:ecs:task-memory-stress`)
- 태스크 메모리 512MB 기준 90% = ~460MB 점유

**예상 타임라인**

| 시간 | 이벤트 |
|------|--------|
| T+0:00 | 메모리 90% 부하 주입 시작 |
| T+1:00 | MemoryUtilization > 80% → Scale-out 정책 평가 |
| T+2:00 | Auto Scaling Scale-out 발동, 신규 태스크 기동 |
| T+3:00 | OOM Kill 발생 가능 (메모리 한계 초과 시) |
| T+3:30 | ECS 자동 태스크 재시작 |
| T+4:00 | 신규 태스크 ALB 헬스체크 통과 |
| T+8:00 | 부하 주입 종료 |
| T+13:00 | Scale-in cooldown 후 태스크 수 정상화 |

**예상 RTO / RPO**
- **RTO: 2~5분** (Scale-out 정책 평가 1분 + Fargate 콜드스타트 ~90초 + 헬스체크 통과 ~30초)
- **RPO: 0** (메모리 부하는 데이터 손실 없음. Redis 세션은 태스크 재시작과 무관하게 유지)

**검증 포인트**
- [ ] `MemoryUtilization` 80% 초과 시 Scale-out 발동 확인
- [ ] OOM Kill 발생 시 ECS 자동 재시작 확인
- [ ] WebSocket 연결 끊김 후 클라이언트 재연결 로직 동작 확인
- [ ] Redis 세션 유지 확인 (태스크 재시작과 무관)

**실험 후 복구 절차**
자동 복구. Scale-in cooldown(300초) 후 태스크 수 정상화 확인.

---

### 시나리오 10: 멀티 서비스 연쇄 장애

**목적**
서비스 간 의존성 체인(analysis → chatbot → users)에서 연쇄 장애 전파를 시뮬레이션하고 Circuit Breaker 및 Graceful Degradation 동작을 검증합니다.

**장애 주입 방식**
1. analysis 전체 태스크 종료 (AI 분석 불가)
2. 2분 후: chatbot CPU 100% 부하 6분 (분석 결과 대기 타임아웃)
3. 2분 후: users 태스크 50% 종료 (인증 부하 증가)

**예상 타임라인**

| 시간 | 이벤트 |
|------|--------|
| T+0:00 | analysis 전체 태스크 종료 |
| T+0:30 | chatbot이 analysis 호출 실패, fallback 응답 시작 |
| T+2:00 | chatbot CPU 100% 부하 주입 시작 |
| T+3:00 | chatbot Scale-out 발동 |
| T+4:00 | users 태스크 50% 종료 |
| T+4:30 | ALB가 users 정상 태스크로만 라우팅 |
| T+6:00 | analysis ECS 자동 재시작 완료 |
| T+8:00 | chatbot CPU 부하 종료, 정상화 시작 |
| T+10:00 | 전체 서비스 정상 복구 |

**예상 RTO / RPO**
- **RTO: 3~8분** (analysis 재시작 ~60초 + chatbot Scale-out ~2분 + users 재라우팅 ~90초)
- **RPO: 0** (태스크 종료/CPU 부하는 데이터 손실 없음)

**검증 포인트**
- [ ] analysis 장애 시 chatbot이 500이 아닌 503 반환 확인 (Circuit Breaker)
- [ ] chatbot CPU 급증 시 Auto Scaling 발동 확인
- [ ] users 50% 종료 시 ALB 정상 라우팅 확인
- [ ] 전체 서비스 완전 중단 없이 부분 기능 저하로 유지 확인
- [ ] DR Composite Alarm 미발화 확인 (users 50% 종료이므로 ECS 레이어 조건 미충족)

**실험 후 복구 절차**
ECS 자동 복구. 모든 서비스 `RunningCount` 정상화 확인.

---

### 시나리오 11: Aurora Global DB Primary 격리

> ⚠️ **이 시나리오는 실제 DR을 트리거할 수 있습니다. `dr/` 모듈 배포 완료 후에만 실행하세요.**

**목적**
Aurora Global DB Primary(서울) 클러스터 연결을 네트워크 격리로 차단하여 Aurora 레이어 장애 감지 → DR Composite Alarm 발화 경로를 검증합니다.

**장애 주입 방식**
- DB Subnet 2a 완전 차단 15분 (`aws:network:disrupt-connectivity`, scope=all)
- 30초 후 DB Subnet 2c 완전 차단 14분 (순차)
- 모든 Aurora 클러스터 `DatabaseConnections=0` 유도

**예상 타임라인**

| 시간 | 이벤트 |
|------|--------|
| T+0:00 | DB Subnet 2a 완전 차단 |
| T+0:30 | DB Subnet 2c 완전 차단 |
| T+0:30 | 모든 Aurora 클러스터 연결 불가, DatabaseConnections=0 |
| T+1:00 | NAT 차단으로 Bedrock 접근 불가 → AgentCore 헬스체크 실패 시작 |
| T+2:00 | DatabaseConnections=0 알람 2개 이상 ALARM (60초 × 2회) |
| T+2:00 | aurora_layer_failure Composite Alarm ALARM |
| T+3:00 | AgentCore 헬스체크 3회 연속 실패 → agentcore_health ALARM |
| T+3:00 | DR Composite Alarm ALARM (Aurora + AgentCore 동시 장애) |
| T+3:05 | Step Functions DR Orchestrator 자동 실행 |
| T+15:00 | 실험 종료, NACL 자동 복구 |
| T+15:30 | Aurora 재연결 시작 (30~60초 소요) |

**예상 RTO / RPO**
- **RTO: ≤ 15분** (DR Orchestrator 실행 기준, 시나리오 08과 동일한 Step Functions 파이프라인)
- **RPO: < 1초** (Aurora Global DB 동기 복제)

**검증 포인트**
- [ ] `DatabaseConnections=0` 알람 4개 클러스터 중 2개 이상 ALARM 확인
- [ ] `aurora_layer_failure` Composite Alarm ALARM 전환 시간 측정
- [ ] DR Composite Alarm ALARM 전환 확인
- [ ] Step Functions DR Orchestrator 자동 실행 확인
- [ ] 실험 종료 후 Aurora 재연결 시간 측정

**실험 후 복구 절차**
DR Composite Alarm이 OK로 전환되면 `dr-failback-orchestrator`가 자동 실행됩니다. 실험 종료 시 NACL이 자동 복구되고, Aurora/ECS 레이어가 정상화되면 Failback이 트리거됩니다.

자동 Failback이 실패한 경우 수동 복구:
```bash
# 1. NACL 복구 확인 (실험 종료 시 자동)
aws ec2 describe-network-acls --region ap-northeast-2

# 2. Aurora Global DB 재동기화 확인
aws rds describe-global-clusters --region ap-northeast-2

# 3. DR 실행된 경우 시나리오 08 복구 절차 동일하게 수행
```

---

### 시나리오 12: AgentCore 레이어 장애

**목적**
NAT Gateway egress 차단으로 Bedrock API 접근을 불가하게 하여 AgentCore 헬스체크 실패 → `agentcore_health` 알람 ALARM 전환 경로를 검증합니다. 단독으로는 DR 미트리거.

**장애 주입 방식**
- Private App Subnet 2a egress 차단 12분 (`aws:network:disrupt-connectivity`, scope=egress)
- 30초 후 Private App Subnet 2c egress 차단 11분 (순차)
- VPC 내부 통신(ECS ↔ RDS, ECS ↔ Redis)은 유지

**예상 타임라인**

| 시간 | 이벤트 |
|------|--------|
| T+0:00 | 2a egress 차단 시작 |
| T+0:30 | 2c egress 차단 시작 |
| T+1:00 | Bedrock API 호출 실패 (ConnectionTimeout) |
| T+1:00 | AgentCore Health Check Lambda 첫 번째 실패 |
| T+2:00 | AgentCore Health Check Lambda 두 번째 실패 |
| T+3:00 | AgentCore Health Check Lambda 세 번째 실패 → agentcore_health ALARM |
| T+3:00 | analysis/chatbot AI 기능 저하 (fallback 응답) |
| T+12:00 | 실험 종료, NACL 자동 복구 |
| T+12:30 | Bedrock API 접근 정상화 |
| T+15:00 | agentcore_health 알람 OK 전환 (~3분 소요) |

**예상 RTO / RPO**
- **RTO: 3~5분** (NACL 복구 즉시 + AgentCore 알람 OK 전환 ~3분)
- **RPO: 0** (네트워크 차단은 데이터 손실 없음)

**검증 포인트**
- [ ] Bedrock API 호출 실패 확인 (ConnectionTimeout)
- [ ] `AgentCoreHealthy` 메트릭 0 발행 3회 연속 확인
- [ ] `agentcore_health` 알람 ALARM 전환 시간 측정 (목표: 3분)
- [ ] analysis/chatbot 서비스 AI 기능 저하 시 fallback 응답 확인
- [ ] ECS 태스크 자체 정상 동작 확인 (VPC 내부 통신 유지)
- [ ] 단독 실행 시 DR Composite Alarm 미발화 확인

**DR 트리거 병행 실행 방법**
시나리오 11(Aurora 격리)과 동시 실행 시 DR Composite Alarm 트리거 가능:
```
agentcore_health ALARM + aurora_layer_failure ALARM → DR Composite Alarm ALARM
```

**실험 후 복구 절차**
자동 복구. AgentCore 알람 OK 전환까지 최대 3분 대기.

---

### 시나리오 13: 점진적 ECS 서비스 저하

**목적**
즉각적인 태스크 종료가 아닌 CPU/메모리 부하 → ALB 헬스체크 실패 → ECS 레이어 장애 트리거 경로를 검증합니다. 현실적인 서비스 저하 패턴으로 DR 감지 시간을 측정합니다.

**장애 주입 방식**
- Phase 1 (T+0): users CPU 95% + history CPU 95% + chatbot 메모리 95% 동시 주입 (12분)
- Phase 2 (T+3분): users 태스크 50% 종료
- Phase 3 (T+5분): history 태스크 50% 종료

**예상 타임라인**

| 시간 | 이벤트 |
|------|--------|
| T+0:00 | CPU/메모리 부하 주입 시작 (3개 서비스 동시) |
| T+0:30 | ALB 헬스체크 실패 시작 (응답 지연으로 타임아웃) |
| T+1:30 | ALB 헬스체크 3회 연속 실패 → UnhealthyHostCount 알람 ALARM |
| T+2:00 | ECS Auto Scaling Scale-out 발동 (신규 태스크 기동 시도) |
| T+3:00 | users 태스크 50% 종료 (Phase 2) |
| T+5:00 | history 태스크 50% 종료 (Phase 3) |
| T+5:30 | users + history + chatbot 모두 UnhealthyHostCount ≥ 1 |
| T+5:30 | ecs_layer_failure Composite Alarm ALARM |
| T+6:00 | DR Composite Alarm 조건 평가 (Aurora/AgentCore 상태에 따라 트리거) |
| T+12:00 | 부하 주입 종료, ECS 자동 복구 시작 |

**예상 RTO / RPO**
- **RTO: 5~15분**
  - ECS 레이어 장애 감지: ~5분 30초 (부하 주입 → 헬스체크 실패 → 알람 → Phase 3 완료)
  - DR 트리거 시: Step Functions 실행 추가 ~10분
  - DR 미트리거 시: ECS Auto Scaling 복구 ~5분
- **RPO: 0** (CPU/메모리 부하는 데이터 손실 없음)

**검증 포인트**
- [ ] CPU/메모리 부하로 ALB 헬스체크 타임아웃 발생 확인
- [ ] `ecs_layer_failure` Composite Alarm ALARM 전환 시간 측정
- [ ] ECS Auto Scaling Scale-out 발동 확인
- [ ] Aurora/AgentCore 정상 시 DR 미트리거 확인
- [ ] 부하 해제 후 자동 복구 시간 측정

**실험 후 복구 절차**
부하 자동 해제 후 ECS Auto Scaling 정상화 대기. DR 트리거된 경우 시나리오 08 복구 절차 수행.

---

### 시나리오 14: 리전 수준 장애 시뮬레이션

> ⚠️ **가장 강력한 시나리오입니다. 팀 전체 공지 및 온콜 엔지니어 대기 후 실행하세요.**

**목적**
서울 리전 전체 장애를 모사하여 전체 DR 파이프라인(Aurora Failover → ECS 활성화 → AgentCore 프로비저닝 → Route53 전환)을 검증합니다.

**장애 주입 방식**
- T+0: Public Subnet 2a + DB Subnet 2a 동시 완전 차단 20분
- T+30초: Public Subnet 2c + DB Subnet 2c 동시 완전 차단 19분

**예상 타임라인**

| 시간 | 이벤트 |
|------|--------|
| T+0:00 | Public 2a + DB 2a 동시 차단 |
| T+0:30 | Public 2c + DB 2c 동시 차단 |
| T+1:00 | ALB 헬스체크 실패 시작 (Public Subnet 차단으로 ALB → ECS 통신 불가) |
| T+1:30 | ALB UnhealthyHostCount 알람 3개 ALARM → ecs_layer_failure ALARM |
| T+2:00 | DatabaseConnections=0 알람 2개 이상 ALARM → aurora_layer_failure ALARM |
| T+2:00 | DR Composite Alarm ALARM (ECS + Aurora 동시 장애) |
| T+2:05 | EventBridge → Step Functions DR Orchestrator 실행 |
| T+3:05 | Aurora Global DB Failover 완료 (도쿄 Secondary → Primary) |
| T+3:15 | SSM 파라미터 업데이트 완료 |
| T+4:45 | DR ECS 서비스 활성화 완료 (도쿄, desired_count 0→2) |
| T+6:45 | AgentCore Runtime 프로비저닝 완료 (도쿄) |
| T+7:15 | Route53 Failover Record 전환 완료 |
| T+8:15 | DNS TTL 반영 완료, 도쿄 서비스 정상 수신 |
| T+20:00 | 실험 종료, NACL 자동 복구 |

**예상 RTO / RPO**
- **RTO: ≤ 15분**
  - 장애 감지: ~2분 (ECS 90초 + Aurora 120초 중 최대값, 동시 발생으로 단축)
  - Step Functions 실행: ~6분 10초
  - DNS TTL 반영: ~60초
  - 총합: ~9분 10초 (목표 15분 대비 충분한 여유)
- **RPO: < 1초** (Aurora Global DB 동기 복제)

**검증 포인트**
- [ ] DR Composite Alarm ALARM 전환 시간 측정 (목표: 2분 이내)
- [ ] Step Functions 각 단계 실행 시간 측정
- [ ] Aurora Global DB 도쿄 Secondary → Primary 승격 확인
- [ ] 도쿄 ECS 서비스 정상 응답 확인
- [ ] Route53 Failover Record 도쿄 ALB로 전환 확인
- [ ] 전체 DR 완료 시간 15분 이내 달성 여부 확인
- [ ] 실험 종료 후 서울 복구 절차 전체 수행 시간 측정

**실험 후 복구 절차 (수동, 전체 복구)**
DR Composite Alarm이 OK로 전환되면 `dr-failback-orchestrator`가 자동 실행됩니다.

자동 Failback이 실패한 경우 수동 복구:
```bash
# 1. NACL 복구 확인 (실험 종료 시 자동)
aws ec2 describe-network-acls --region ap-northeast-2

# 2. Aurora Global DB 서울 재동기화
# 도쿄 Primary → 서울 Secondary 방향으로 재동기화 후 Failback

# 3. 서울 ECS 서비스 재시작
aws ecs update-service --cluster cdci-prd --service users --desired-count 2 --region ap-northeast-2
aws ecs update-service --cluster cdci-prd --service history --desired-count 2 --region ap-northeast-2
aws ecs update-service --cluster cdci-prd --service chatbot --desired-count 2 --region ap-northeast-2
aws ecs update-service --cluster cdci-prd --service analysis --desired-count 2 --region ap-northeast-2
aws ecs update-service --cluster cdci-prd --service frontend --desired-count 2 --region ap-northeast-2

# 4. DR ECS 서비스 비활성화 (도쿄)
for svc in users history chatbot analysis frontend; do
  aws ecs update-service --cluster cdci-prd-dr --service $svc --desired-count 0 --region ap-northeast-1
done

# 5. AgentCore Runtime 삭제 (도쿄 DR 환경)
# Terraform destroy 또는 AWS 콘솔에서 수동 삭제
```

---

## 4. RTO/RPO 계산 기준

### 정의

| 지표 | 정의 |
|------|------|
| **RTO** (Recovery Time Objective) | 장애 발생 시점부터 서비스가 정상 수준으로 복구되기까지의 목표 시간 |
| **RPO** (Recovery Point Objective) | 마지막 정상 데이터 시점부터 장애 시점까지 허용 가능한 데이터 손실 범위 |

### 컴포넌트별 기준값

**ECS Fargate**

| 항목 | 시간 | 근거 |
|------|------|------|
| 태스크 자동 재시작 | 30~60초 | Fargate 콜드스타트 + 컨테이너 초기화 |
| ALB 헬스체크 통과 | +30~60초 | 헬스체크 간격 30초, 2회 연속 성공 |
| Scale-out 발동 | 1~2분 | CloudWatch 알람 평가 주기 + Auto Scaling 정책 |
| Scale-out 완료 | +90초 | Fargate 콜드스타트 포함 |

**Aurora Global DB**

| 항목 | 시간 | 근거 |
|------|------|------|
| 클러스터 내 페일오버 | < 30초 | Writer → Reader 승격, DNS 업데이트 |
| 앱 재연결 | +15~30초 | 연결 풀 재시도, 클러스터 DNS 기반 |
| Global DB Failover | ~60초 | Secondary → Primary 승격 (리전 간) |
| RPO | < 1초 | Aurora Global DB 동기 복제 (일반적으로 1초 미만 lag) |

**DR 감지 (Composite Alarm)**

| 레이어 | 감지 시간 | 근거 |
|--------|-----------|------|
| ECS 레이어 | 90초 | ALB 헬스체크 30초 × 3회 연속 실패 |
| Aurora 레이어 | 120초 | DatabaseConnections=0, 60초 × 2회 연속 |
| AgentCore 레이어 | 3분 | Health Check Lambda 1분 주기 × 3회 연속 실패 |

**DR Step Functions 오케스트레이터**

| 단계 | 소요 시간 | 누적 시간 |
|------|-----------|-----------|
| Aurora Global DB Failover | ~60초 | 1분 |
| SSM 파라미터 업데이트 | ~10초 | 1분 10초 |
| DR ECS 서비스 활성화 | ~90초 | 2분 40초 |
| AgentCore Runtime 프로비저닝 | ~120초 | 4분 40초 |
| Route53 Failover Record 전환 | ~30초 | 5분 10초 |
| DNS TTL 반영 | ~60초 | 6분 10초 |
| SNS 완료 알림 | ~5초 | 6분 15초 |

**전체 DR RTO 계산**

```
DR 감지 시간 (최대): 120초 (Aurora 레이어 기준)
+ Step Functions 실행: 375초 (6분 15초)
+ 버퍼 (네트워크 지연 등): 120초
= 총 615초 ≈ 10분 15초

목표 RTO: 15분 이내 ✅ (여유 약 5분)
```

---

## 5. 실험 실행 가이드

### 사전 조건 체크리스트

```
[ ] AWS FIS 서비스 역할(CDCI-PRD-FIS-ROLE) 배포 완료
[ ] CloudWatch 알람 정상 동작 확인 (OK 상태)
[ ] Grafana 대시보드 모니터링 준비
[ ] SNS 알림 이메일 구독 확인 (terraform.tfvars의 notification_email)
[ ] stop_condition_alarm_arn 실제 ARN으로 업데이트 완료
[ ] FIS 실험 로그 그룹(/fis/cdci-prd) 생성 확인
```

**DR 트리거 시나리오(08, 11, 14) 추가 확인사항**
```
[ ] dr/ 모듈 Terraform 배포 완료 (도쿄 DR 인프라)
[ ] Step Functions DR Orchestrator 정상 배포 확인
[ ] Aurora Global DB Secondary(도쿄) 동기화 상태 확인
[ ] Route53 Failover Record 설정 확인
[ ] 팀 전체 공지 및 온콜 엔지니어 대기
[ ] 실험 후 수동 복구 절차 숙지
```

### 위험도별 실행 순서 권장

**1단계: 낮음 🟢 (단독 컴포넌트 검증)**

| 순서 | 시나리오 | 목적 |
|------|---------|------|
| 1 | 01 ECS 태스크 강제 종료 | ECS 자동 복구 기본 검증 |
| 2 | 02 ECS CPU 부하 주입 | Auto Scaling 기본 검증 |
| 3 | 09 ECS 메모리 부하 주입 | OOM 복구 검증 |
| 4 | 04 Aurora Reader 재부팅 | DB 연결 풀 기본 검증 |
| 5 | 05 ElastiCache Redis 재부팅 | 세션 복구 검증 |

**2단계: 중간 🟡 (복합 컴포넌트 검증)**

| 순서 | 시나리오 | 목적 |
|------|---------|------|
| 6 | 03 Aurora 클러스터 페일오버 | DB 페일오버 검증 |
| 7 | 06 AZ 장애 시뮬레이션 | 멀티-AZ 복원력 검증 |
| 8 | 07 NAT Gateway 장애 | 외부 통신 의존성 검증 |
| 9 | 10 멀티 서비스 연쇄 장애 | 의존성 체인 검증 |
| 10 | 12 AgentCore 레이어 장애 | AgentCore 알람 검증 |
| 11 | 13 점진적 ECS 서비스 저하 | 현실적 장애 패턴 검증 |

**3단계: 높음 🔴 (DR 전체 파이프라인 검증)**

| 순서 | 시나리오 | 목적 |
|------|---------|------|
| 12 | 11 Aurora Global DB Primary 격리 | Aurora 레이어 DR 트리거 검증 |
| 13 | 08 DR 트리거 시뮬레이션 | ECS+Aurora 복합 DR 검증 |
| 14 | 14 리전 수준 장애 시뮬레이션 | 전체 DR 파이프라인 최종 검증 |

### 실험 실행 방법

AWS 콘솔에서 실행:
```
AWS Console → FIS → Experiment templates → 해당 템플릿 선택 → Start experiment
```

AWS CLI로 실행:
```bash
# 실험 템플릿 ID 확인 (Terraform output)
terraform output experiment_template_ids

# 실험 시작
aws fis start-experiment \
  --experiment-template-id <TEMPLATE_ID> \
  --region ap-northeast-2

# 실험 상태 확인
aws fis get-experiment \
  --id <EXPERIMENT_ID> \
  --region ap-northeast-2
```

### 실험 후 복구 공통 절차

```bash
# 1. CloudWatch 알람 상태 확인
aws cloudwatch describe-alarms \
  --alarm-name-prefix "cdci-prd" \
  --region ap-northeast-2 \
  --query 'MetricAlarms[?StateValue!=`OK`].[AlarmName,StateValue]' \
  --output table

# 2. ECS 서비스 상태 확인
aws ecs describe-services \
  --cluster cdci-prd \
  --services users history chatbot analysis frontend \
  --region ap-northeast-2 \
  --query 'services[*].[serviceName,runningCount,desiredCount]' \
  --output table

# 3. Aurora 클러스터 상태 확인
aws rds describe-db-clusters \
  --region ap-northeast-2 \
  --query 'DBClusters[*].[DBClusterIdentifier,Status,MultiAZ]' \
  --output table

# 4. FIS 실험 로그 확인
aws logs filter-log-events \
  --log-group-name /fis/cdci-prd \
  --region ap-northeast-2 \
  --start-time $(date -d '1 hour ago' +%s000)
```

---

## 6. Terraform 사용법

### 초기화

```bash
cd fis/
terraform init
```

### 변수 설정

`terraform.tfvars`에서 실제 값으로 업데이트:

```hcl
# terraform.tfvars
project_name = "cdci"
environment  = "prd"
region       = "ap-northeast-2"

# DR Composite Alarm ARN (실제 ARN으로 교체)
stop_condition_alarm_arn = "arn:aws:cloudwatch:ap-northeast-2:620758375333:alarm:cdci-prd-DR-TRIGGER"

# 실험 결과 알림 이메일
notification_email = "your-team@example.com"
```

### 배포

```bash
# 변경 사항 미리 확인
terraform plan

# 실험 템플릿 배포
terraform apply
```

### 실험 템플릿 ID 확인

```bash
terraform output experiment_template_ids
```

### 특정 시나리오만 배포

```bash
# 예: 시나리오 01만 배포
terraform apply -target=aws_fis_experiment_template.ecs_task_kill
```

### 삭제

```bash
# 모든 FIS 실험 템플릿 삭제
terraform destroy
```

> **참고**: FIS 실험 템플릿 삭제는 실행 중인 실험에 영향을 주지 않습니다. 실험 종료 후 삭제하세요.
