# 네트워크 IP 및 CIDR 매핑 문서

CodeCaine 팀의 AWS 네트워크 인프라 IP 주소 및 CIDR 블록 정리

## 문서 개요

이 문서는 Terraform으로 관리되는 모든 네트워크 리소스의 IP 주소와 CIDR 블록을 정리합니다.
모든 리소스명은 **CDCI 네이밍 컨벤션**을 따릅니다.

**환경**: PRD (프로덕션 환경)  
**리전**: ap-northeast-2 (서울)  
**가용영역**: ap-northeast-2a, ap-northeast-2c

---

## 1. VPC 구성

### VPC 기본 정보

| 리소스명 | CIDR 블록 | 설명 |
|---------|----------|------|
| **CDCI-PRD-VPC** | `10.0.0.0/16` | 메인 VPC (65,536개 IP 주소) |
| **CDCI-PRD-IGW** | N/A | Internet Gateway |

**DNS 설정**:
- DNS Hostnames: 활성화
- DNS Support: 활성화

---

## 2. 서브넷 구성

### 2.1 Public Subnets

Public 서브넷은 인터넷에 직접 연결되며, Bastion 호스트와 NAT Gateway가 배치됩니다.

| 리소스명 | CIDR 블록 | 가용영역 | IP 주소 범위 | 사용 가능 IP | 용도 |
|---------|----------|---------|-------------|------------|------|
| **CDCI-PRD-VPC-PUBLIC-2A** | `10.0.0.0/24` | ap-northeast-2a | 10.0.0.0 - 10.0.0.255 | 251개 | Bastion, NAT GW |
| **CDCI-PRD-VPC-PUBLIC-2C** | `10.0.1.0/24` | ap-northeast-2c | 10.0.1.0 - 10.0.1.255 | 251개 | 예비 Public 리소스 |

**라우팅**:
- Route Table: **CDCI-PRD-PUBLIC-RT**
- 기본 라우트: `0.0.0.0/0` → **CDCI-PRD-IGW** (인터넷 게이트웨이)

**특징**:
- `map_public_ip_on_launch = true` (자동 Public IP 할당)
- 인터넷 직접 접근 가능

---

### 2.2 Private Application Subnets

Private App 서브넷은 ECS 태스크(컨테이너)가 실행되는 영역입니다.

| 리소스명 | CIDR 블록 | 가용영역 | IP 주소 범위 | 사용 가능 IP | 용도 |
|---------|----------|---------|-------------|------------|------|
| **CDCI-PRD-VPC-PRIVATE-APP-2A** | `10.0.10.0/24` | ap-northeast-2a | 10.0.10.0 - 10.0.10.255 | 251개 | ECS Tasks |
| **CDCI-PRD-VPC-PRIVATE-APP-2C** | `10.0.11.0/24` | ap-northeast-2c | 10.0.11.0 - 10.0.11.255 | 251개 | ECS Tasks |

**라우팅**:
- Route Table: **CDCI-PRD-PRIVATE-APP-RT-2A**, **CDCI-PRD-PRIVATE-APP-RT-2C**
- 기본 라우트: `0.0.0.0/0` → **CDCI-PRD-NAT-GW** (NAT 게이트웨이)

**특징**:
- 인터넷 직접 접근 불가 (NAT Gateway를 통한 아웃바운드만 가능)
- ECS 태스크가 동적으로 Private IP 할당받음
- ALB를 통해 외부 트래픽 수신

---

### 2.3 Private Database Subnets

Private DB 서브넷은 RDS Aurora 데이터베이스가 배치되는 영역입니다.

| 리소스명 | CIDR 블록 | 가용영역 | IP 주소 범위 | 사용 가능 IP | 용도 |
|---------|----------|---------|-------------|------------|------|
| **CDCI-PRD-VPC-PRIVATE-DB-2A** | `10.0.20.0/24` | ap-northeast-2a | 10.0.20.0 - 10.0.20.255 | 251개 | RDS Aurora |
| **CDCI-PRD-VPC-PRIVATE-DB-2C** | `10.0.21.0/24` | ap-northeast-2c | 10.0.21.0 - 10.0.21.255 | 251개 | RDS Aurora |

**라우팅**:
- Route Table: **CDCI-PRD-PRIVATE-DB-RT** (공유)
- 기본 라우트: 없음 (완전히 격리된 네트워크)

**DB Subnet Group**:
- 이름: **CDCI-PRD-DB-SUBNET-GROUP**
- 포함 서브넷: CDCI-PRD-VPC-PRIVATE-DB-2A, CDCI-PRD-VPC-PRIVATE-DB-2C

**특징**:
- 인터넷 접근 불가 (NAT Gateway 라우트 없음)
- VPC 내부에서만 접근 가능
- Multi-AZ 고가용성 지원

---

## 3. NAT Gateway

NAT Gateway는 Private 서브넷의 리소스가 인터넷에 아웃바운드 연결을 할 수 있도록 합니다.

| 리소스명 | 배치 위치 | Elastic IP | 설명 |
|---------|----------|-----------|------|
| **CDCI-PRD-NAT-GW** | CDCI-PRD-VPC-PUBLIC-2A (10.0.0.0/24) | **CDCI-PRD-NAT-EIP** | 단일 NAT Gateway (Regional, Public) |

**Elastic IP**:
- 리소스명: **CDCI-PRD-NAT-EIP**
- 타입: VPC
- 고정 Public IP (AWS에서 동적 할당)

**NAT Gateway 설정**:
- connectivity_type: public
- 구성: Regional (단일 NAT Gateway)

**연결된 라우트 테이블**:
- CDCI-PRD-PRIVATE-APP-RT-2A
- CDCI-PRD-PRIVATE-APP-RT-2C

**비용 최적화**:
- 단일 NAT Gateway 사용 (Multi-AZ 대신)
- 모든 Private App 서브넷이 하나의 NAT Gateway 공유

---

## 4. Bastion Host

Bastion 호스트는 Private 리소스(RDS, ECS)에 안전하게 접근하기 위한 점프 서버입니다.

| 리소스명 | 배치 위치 | Private IP | Public IP | 인스턴스 타입 |
|---------|----------|-----------|----------|-------------|
| **CDCI-PRD-BASTION** | CDCI-PRD-VPC-PUBLIC-2A | 동적 할당 (10.0.0.x) | **CDCI-PRD-BASTION-EIP** | t3.micro |

**Elastic IP**:
- 리소스명: **CDCI-PRD-BASTION-EIP**
- 타입: VPC
- 고정 Public IP (AWS에서 동적 할당)

**네트워크 설정**:
- VPC: CDCI-PRD-VPC
- Subnet: CDCI-PRD-VPC-PUBLIC-2A (10.0.0.0/24)
- Security Group: **CDCI-PRD-BASTION-SG**

**접근 제어**:
- SSH 포트: 22
- 허용 IP: `1.2.3.4/32` (사무실 IP)
- 키 페어: tera-test.pem

**설치된 소프트웨어**:
- PostgreSQL 15 클라이언트 (RDS 접속용)
- AWS Systems Manager Agent (SSM)

---

## 5. 보안 그룹 (Security Groups)

### 5.1 ALB Security Group

| 리소스명 | VPC | 인바운드 규칙 | 아웃바운드 규칙 |
|---------|-----|-------------|---------------|
| **CDCI-PRD-ALB-SG** | CDCI-PRD-VPC | HTTP (80): `0.0.0.0/0`<br>HTTPS (443): `0.0.0.0/0` | All: `0.0.0.0/0` |

**용도**: Application Load Balancer 보안

---

### 5.2 ECS Tasks Security Group

| 리소스명 | VPC | 인바운드 규칙 | 아웃바운드 규칙 |
|---------|-----|-------------|---------------|
| **CDCI-PRD-ECS-TASKS-SG** | CDCI-PRD-VPC | All TCP (0-65535): CDCI-PRD-ALB-SG<br>All TCP (0-65535): Self (inter-service) | All: `0.0.0.0/0` |

**용도**: ECS 컨테이너 보안
**특징**: 
- ALB에서 오는 트래픽 허용
- 같은 보안 그룹 내 통신 허용 (마이크로서비스 간 통신)

---

### 5.3 RDS Security Group

| 리소스명 | VPC | 인바운드 규칙 | 아웃바운드 규칙 |
|---------|-----|-------------|---------------|
| **CDCI-PRD-RDS-SG** | CDCI-PRD-VPC | PostgreSQL (5432): CDCI-PRD-ECS-TASKS-SG<br>PostgreSQL (5432): `10.0.0.0/24`, `10.0.1.0/24` (Bastion) | All: `0.0.0.0/0` |

**용도**: RDS Aurora 데이터베이스 보안
**접근 허용**:
- ECS Tasks (애플리케이션)
- Bastion Host (관리 목적)

---

### 5.4 Bastion Security Group

| 리소스명 | VPC | 인바운드 규칙 | 아웃바운드 규칙 |
|---------|-----|-------------|---------------|
| **CDCI-PRD-BASTION-SG** | CDCI-PRD-VPC | SSH (22): `1.2.3.4/32` (사무실 IP) | All: `0.0.0.0/0` |

**용도**: Bastion 호스트 보안
**특징**: 특정 IP에서만 SSH 접근 허용

---

### 5.5 VPC Endpoints Security Group

| 리소스명 | VPC | 인바운드 규칙 | 아웃바운드 규칙 |
|---------|-----|-------------|---------------|
| **CDCI-PRD-VPCE-SG** | CDCI-PRD-VPC | HTTPS (443): CDCI-PRD-ECS-TASKS-SG | All: `0.0.0.0/0` |

**용도**: VPC Endpoints (ECR, S3 등) 보안
**특징**: ECS Tasks가 Private 서브넷에서 AWS 서비스 접근 시 사용

---

## 6. 네트워크 아키텍처 다이어그램

```
Internet
    │
    ├─── CDCI-PRD-IGW (Internet Gateway)
    │
    └─── CDCI-PRD-VPC (10.0.0.0/16)
         │
         ├─── Public Subnets (인터넷 직접 연결)
         │    ├─── CDCI-PRD-VPC-PUBLIC-2A (10.0.0.0/24)
         │    │    ├─── CDCI-PRD-BASTION (Bastion Host)
         │    │    │    └─── CDCI-PRD-BASTION-EIP (Public IP)
         │    │    └─── CDCI-PRD-NAT-GW (NAT Gateway)
         │    │         └─── CDCI-PRD-NAT-EIP (Public IP)
         │    │
         │    └─── CDCI-PRD-VPC-PUBLIC-2C (10.0.1.0/24)
         │         └─── (예비 Public 리소스)
         │
         ├─── Private App Subnets (NAT Gateway를 통한 아웃바운드)
         │    ├─── CDCI-PRD-VPC-PRIVATE-APP-2A (10.0.10.0/24)
         │    │    └─── ECS Tasks (동적 IP)
         │    │
         │    └─── CDCI-PRD-VPC-PRIVATE-APP-2C (10.0.11.0/24)
         │         └─── ECS Tasks (동적 IP)
         │
         └─── Private DB Subnets (완전 격리)
              ├─── CDCI-PRD-VPC-PRIVATE-DB-2A (10.0.20.0/24)
              │    └─── RDS Aurora Primary/Replica
              │
              └─── CDCI-PRD-VPC-PRIVATE-DB-2C (10.0.21.0/24)
                   └─── RDS Aurora Replica
```

---

## 7. 네트워크 트래픽 흐름

### 7.1 외부 → 애플리케이션 (인바운드)

```
Internet → ALB (Public) → ECS Tasks (Private App Subnet)
```

1. 사용자가 ALB의 Public IP로 HTTP/HTTPS 요청
2. ALB가 CDCI-DEV-VPC-PRIVATE-APP-2A/2C의 ECS Tasks로 트래픽 전달
3. ECS Tasks가 요청 처리 후 응답

---

### 7.2 애플리케이션 → 인터넷 (아웃바운드)

```
ECS Tasks (Private App Subnet) → NAT Gateway (Public Subnet) → Internet
```

1. ECS Tasks가 외부 API 호출 (예: 결제 게이트웨이)
2. Private App Route Table이 트래픽을 NAT Gateway로 라우팅
3. NAT Gateway가 Public IP로 변환하여 인터넷 접속

---

### 7.3 애플리케이션 → 데이터베이스

```
ECS Tasks (Private App Subnet) → RDS Aurora (Private DB Subnet)
```

1. ECS Tasks가 PostgreSQL 연결 (포트 5432)
2. VPC 내부 라우팅 (인터넷 경유 없음)
3. CDCI-DEV-RDS-SG가 CDCI-DEV-ECS-TASKS-SG에서 오는 트래픽 허용

---

### 7.4 Bastion → 데이터베이스 (관리)

```
개발자 PC → Bastion (Public Subnet) → RDS Aurora (Private DB Subnet)
```

1. 개발자가 SSH로 Bastion 접속 (tera-test.pem 키 사용)
2. Bastion에서 PostgreSQL 클라이언트로 RDS 접속
3. CDCI-DEV-RDS-SG가 Public Subnet CIDR에서 오는 트래픽 허용

---

## 8. IP 주소 할당 현황

### 8.1 CIDR 블록 사용률

| CIDR 블록 | 총 IP | 사용 가능 IP | AWS 예약 IP | 용도 |
|----------|------|------------|-----------|------|
| 10.0.0.0/16 | 65,536 | 65,531 | 5 (VPC) | 전체 VPC |
| 10.0.0.0/24 | 256 | 251 | 5 (서브넷) | Public 2A |
| 10.0.1.0/24 | 256 | 251 | 5 (서브넷) | Public 2C |
| 10.0.10.0/24 | 256 | 251 | 5 (서브넷) | Private App 2A |
| 10.0.11.0/24 | 256 | 251 | 5 (서브넷) | Private App 2C |
| 10.0.20.0/24 | 256 | 251 | 5 (서브넷) | Private DB 2A |
| 10.0.21.0/24 | 256 | 251 | 5 (서브넷) | Private DB 2C |

**AWS 예약 IP 주소** (각 서브넷마다):
- `.0`: 네트워크 주소
- `.1`: VPC 라우터
- `.2`: DNS 서버
- `.3`: 미래 사용을 위해 예약
- `.255`: 브로드캐스트 주소

---

### 8.2 고정 IP 리소스

| 리소스명 | IP 타입 | IP 주소 | 설명 |
|---------|--------|--------|------|
| **CDCI-DEV-NAT-EIP** | Elastic IP (Public) | AWS 동적 할당 | NAT Gateway용 고정 Public IP |
| **CDCI-DEV-BASTION-EIP** | Elastic IP (Public) | AWS 동적 할당 | Bastion Host용 고정 Public IP |

**참고**: Elastic IP는 Terraform apply 시 AWS가 자동으로 할당하며, 리소스가 삭제되기 전까지 유지됩니다.

---

### 8.3 동적 IP 리소스

| 리소스 타입 | 배치 위치 | IP 범위 | 할당 방식 |
|-----------|----------|--------|----------|
| ECS Tasks | Private App Subnets | 10.0.10.0/24, 10.0.11.0/24 | 동적 (ENI) |
| RDS Aurora | Private DB Subnets | 10.0.20.0/24, 10.0.21.0/24 | 동적 (AWS 관리) |
| Bastion Private IP | Public Subnet 2A | 10.0.0.0/24 | 동적 (EC2) |

---

## 9. 네트워크 확장 계획

### 9.1 사용 가능한 CIDR 블록

현재 사용 중인 CIDR: `10.0.0.0/24`, `10.0.1.0/24`, `10.0.10.0/24`, `10.0.11.0/24`, `10.0.20.0/24`, `10.0.21.0/24`

**예약 가능한 CIDR 블록**:
- `10.0.2.0/24` ~ `10.0.9.0/24`: Public 서브넷 확장
- `10.0.12.0/24` ~ `10.0.19.0/24`: Private App 서브넷 확장
- `10.0.22.0/24` ~ `10.0.29.0/24`: Private DB 서브넷 확장
- `10.0.30.0/24` ~ `10.0.255.0/24`: 미래 사용 (캐시, 검색 엔진 등)

---

### 9.2 추가 가용영역 확장

현재 2개 AZ 사용 중 (2a, 2c). 추가 가능한 AZ:
- **ap-northeast-2b**: 세 번째 가용영역 추가 시
- **ap-northeast-2d**: 네 번째 가용영역 추가 시

---

## 10. 보안 고려사항

### 10.1 네트워크 격리

- **Public Subnets**: 인터넷 직접 연결 (Bastion, NAT GW만 배치)
- **Private App Subnets**: NAT Gateway를 통한 아웃바운드만 허용
- **Private DB Subnets**: 완전 격리 (인터넷 접근 불가)

---

### 10.2 최소 권한 원칙

- 각 보안 그룹은 필요한 포트와 소스만 허용
- Bastion은 특정 IP에서만 SSH 접근 가능
- RDS는 ECS Tasks와 Bastion에서만 접근 가능

---

### 10.3 암호화

- VPC 트래픽: AWS 내부 네트워크 암호화
- Bastion Root Volume: EBS 암호화 활성화
- RDS: 저장 데이터 암호화 (별도 설정)

---

## 11. 모니터링 및 로깅

### 11.1 VPC Flow Logs (권장)

VPC Flow Logs를 활성화하여 네트워크 트래픽을 모니터링할 수 있습니다.

```hcl
resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
}
```

---

### 11.2 CloudWatch 메트릭

- NAT Gateway: 바이트 전송량, 연결 수
- Bastion: CPU, 네트워크 사용량
- ECS Tasks: 네트워크 인/아웃바운드

---

## 12. 비용 최적화

### 12.1 NAT Gateway 비용

- **단일 NAT Gateway 사용**: Multi-AZ 대신 단일 NAT Gateway로 비용 절감
- **예상 비용**: 시간당 $0.059 + 데이터 전송 비용

---

### 12.2 Elastic IP 비용

- **사용 중인 EIP**: 무료
- **미사용 EIP**: 시간당 $0.005 (주의: 사용하지 않으면 과금)

---

### 12.3 데이터 전송 비용

- **VPC 내부**: 무료
- **NAT Gateway 경유**: GB당 $0.059
- **인터넷 아웃바운드**: GB당 $0.126 (첫 10TB)

---

## 13. 트러블슈팅

### 13.1 ECS Tasks가 인터넷에 연결되지 않을 때

1. NAT Gateway가 Public Subnet에 배치되었는지 확인
2. Private App Route Table에 `0.0.0.0/0 → NAT Gateway` 라우트 확인
3. NAT Gateway의 Elastic IP가 할당되었는지 확인

---

### 13.2 Bastion에서 RDS 연결 실패

1. RDS Security Group에서 Bastion의 Public Subnet CIDR 허용 확인
2. RDS가 Private DB Subnet에 배치되었는지 확인
3. PostgreSQL 클라이언트 설치 확인: `psql --version`

---

### 13.3 ALB에서 ECS Tasks 연결 실패

1. ECS Tasks Security Group에서 ALB Security Group 허용 확인
2. Target Group Health Check 설정 확인
3. ECS Tasks가 Private App Subnet에 배치되었는지 확인

---

## 14. 참고 문서

- [NAMING_CONVENTION.md](./NAMING_CONVENTION.md): CDCI 네이밍 규칙
- [foundation/vpc.tf](./foundation/vpc.tf): VPC 및 서브넷 정의
- [nat/nat_gateway.tf](./nat/nat_gateway.tf): NAT Gateway 설정
- [compute/bastion.tf](./compute/bastion.tf): Bastion 호스트 설정
- [foundation/security_groups.tf](./foundation/security_groups.tf): 보안 그룹 정의

---

## 15. 변경 이력

| 날짜 | 버전 | 변경 내용 | 작성자 |
|-----|------|----------|--------|
| 2024-01-XX | 1.0 | 초기 문서 작성 | Kiro AI |

---

**문서 작성일**: 2024년  
**마지막 업데이트**: Terraform 인프라 기준  
**문서 관리**: 인프라 변경 시 함께 업데이트 필요
