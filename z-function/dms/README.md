# DMS (Database Migration Service) 가이드

## 개요

현재 구성: `vitamin_user` DB (users-cluster) → `vitamin_analysis` DB (analysis-cluster) 단방향 동기화

동기화 테이블:
| source (vitamin_user) | target (vitamin_analysis) | 비고 |
|---|---|---|
| `user_profile` | `analysis_userdata` | 컬럼명 매핑 (`ans_` 접두사) |
| `current_supplements` | `analysis_supplements` | 컬럼명 매핑 (`ans_` 접두사) |
| `current_ingredients` | `anaysis_current_ingredients` | 컬럼명 매핑 (`ans_` 접두사) |

---

## DMS 개념

### 복제 인스턴스 (Replication Instance)

DMS는 데이터를 직접 DB에서 DB로 전달하지 않는다. 중간에 **중계 서버**가 있다.

```
users-cluster (source)
       ↓
  [DMS 복제 인스턴스]  ← 중계 EC2 서버
       ↓
analysis-cluster (target)
```

복제 인스턴스가 하는 일:
- source에서 데이터 읽어오기
- 컬럼 매핑/변환 처리
- target에 쓰기
- CDC 로그 버퍼링

> `dms.t3.medium` = 중계 서버 스펙. 데이터 양이 적으면 `t3.micro`도 가능하지만 CDC는 메모리를 좀 사용한다.

---

### Full Load vs CDC

**Full Load (전체 복사)**

```
users DB 현재 데이터 전체 → analysis DB에 한번에 복사
```
- 최초 1회만 실행
- 끝나면 종료 (이후 변경사항 반영 안됨)

**CDC (Change Data Capture)**

```
users DB에서 INSERT/UPDATE/DELETE 발생
→ WAL 로그 (PostgreSQL 트랜잭션 로그) 감지
→ 실시간으로 analysis DB에 반영
```
- 지속적으로 동기화
- source DB에 `rds.logical_replication = 1` 필요 (WAL 레벨 상향)

**Full-load-and-cdc (현재 설정)**

```
1단계: 현재 데이터 전체 복사 (full load)
2단계: 이후 변경사항 지속 동기화 (cdc)
```

처음엔 전체 복사하고, 그 이후부터는 변경분만 계속 sync.

| 설정 | 의미 |
|---|---|
| 복제 인스턴스 | 중간에서 데이터 중계하는 EC2 서버 |
| full-load | 현재 데이터 스냅샷 1회 복사 |
| cdc | 이후 변경사항 실시간 동기화 |
| full-load-and-cdc | 둘 다 (권장) |

---

## 최초 배포 순서

### 1. Source DB 사전 설정

users-cluster에 CDC를 위한 logical replication 활성화가 필요하다.

#### 1-1. Logical Replication 파라미터 그룹 적용

terraform apply 후 output으로 출력되는 파라미터 그룹 이름을 확인한다.

```bash
terraform output users_logical_param_group_name
```

해당 이름으로 users-cluster 파라미터 그룹 변경:

```bash
aws rds modify-db-cluster \
  --db-cluster-identifier cdci-prd-users-cluster \
  --db-cluster-parameter-group-name <output값> \
  --apply-immediately \
  --region ap-northeast-2
```

Writer 인스턴스 재시작 (파라미터 `pending-reboot` 적용):

```bash
aws rds reboot-db-instance \
  --db-instance-identifier cdci-prd-users-cluster-wo \
  --region ap-northeast-2
```

> **주의**: 재시작 중 약 1~2분간 users-cluster 쓰기 불가. 배포 전에 팀 공유 필요.

#### 1-2. Source DB 사용자 권한 부여

bastion host를 통해 users DB에 접속 후 실행:

```sql
-- DMS CDC를 위한 replication 권한 부여
GRANT rds_replication TO vitamin_user;

-- DMS가 읽을 테이블에 SELECT 권한 확인 (master user는 이미 보유)
GRANT SELECT ON user_profile TO vitamin_user;
GRANT SELECT ON current_supplements TO vitamin_user;
GRANT SELECT ON current_ingredients TO vitamin_user;
```

#### 1-3. Target DB 사전 설정

analysis DB에 target 테이블이 이미 생성되어 있어야 한다. DMS는 테이블을 자동 생성하지 않는다.

```sql
-- analysis DB에서 target 테이블 존재 여부 확인
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('analysis_userdata', 'analysis_supplements', 'anaysis_current_ingredients');
```

---

### 2. Terraform Apply

```bash
cd z-function/dms

terraform init
terraform plan
terraform apply
```

---

### 3. DMS Endpoint 연결 테스트

AWS Console → DMS → Endpoints 에서 source/target 각각 **Test connection** 실행.
또는 CLI:

```bash
# Source endpoint 테스트
aws dms test-connection \
  --replication-instance-arn <replication_instance_arn output값> \
  --endpoint-arn <source_endpoint_arn output값> \
  --region ap-northeast-2

# Target endpoint 테스트
aws dms test-connection \
  --replication-instance-arn <replication_instance_arn output값> \
  --endpoint-arn <target_endpoint_arn output값> \
  --region ap-northeast-2
```

---

### 4. Replication Task 시작

```bash
aws dms start-replication-task \
  --replication-task-arn <replication_task_arn output값> \
  --start-replication-task-type start-replication \
  --region ap-northeast-2
```

> `start-replication-task-type` 옵션:
> - `start-replication`: 처음 시작 (full-load → cdc)
> - `resume-processing`: 중단된 cdc 재개
> - `reload-target`: target 테이블 초기화 후 full-load 재실행

---

## 운영 중 관리

### Task 상태 확인

```bash
aws dms describe-replication-tasks \
  --filters Name=replication-task-arn,Values=<task_arn> \
  --region ap-northeast-2 \
  --query 'ReplicationTasks[0].{Status:Status,StopReason:StopReason,Stats:ReplicationTaskStats}'
```

### Task 일시정지 / 재시작

```bash
# 정지
aws dms stop-replication-task \
  --replication-task-arn <task_arn> \
  --region ap-northeast-2

# 재개 (cdc 지점부터)
aws dms start-replication-task \
  --replication-task-arn <task_arn> \
  --start-replication-task-type resume-processing \
  --region ap-northeast-2
```

### CloudWatch 로그 확인

AWS Console → CloudWatch → Log groups → `/aws/dms/tasks/<task_id>`

---

## Target에만 존재하는 데이터 처리

### 기본 원칙

DMS는 **source에 있는 것만 처리**한다. target에만 있는 컬럼이나 데이터는 **건드리지 않는다.**

### 컬럼 단위

```
source: user_profile
┌─────────────┬──────────┬────────┐
│ cognito_id  │ birth_dt │ gender │
└─────────────┴──────────┴────────┘

target: analysis_userdata
┌─────────────┬──────────────┬────────────┬───────────────────────┐
│ cognito_id  │ ans_birth_dt │ ans_gender │ ans_current_conditions │  ← source에 없음
└─────────────┴──────────────┴────────────┴───────────────────────┘
```

`ans_current_conditions` 는 source에 없으므로 DMS가 **완전히 무시**.
해당 컬럼은 NULL로 남거나, 기존에 값이 있었으면 그대로 유지된다.

### 행(row) 단위 — UPDATE 발생 시

source에서 UPDATE가 발생하면:
- source에서 온 컬럼만 덮어씀
- target에만 있는 컬럼 값은 **그대로 보존**

### 주의 — Full Load 시 TargetTablePrepMode

Full Load는 기본적으로 INSERT 방식이다. 현재 설정은 `DO_NOTHING`:

| TargetTablePrepMode | 동작 |
|---|---|
| `DO_NOTHING` | target 테이블 건드리지 않고 INSERT 시도 (현재 설정) |
| `DROP_AND_CREATE` | target 테이블 DROP 후 재생성 (**위험 — 기존 데이터 삭제**) |
| `TRUNCATE_BEFORE_LOAD` | 기존 데이터 전부 삭제 후 INSERT |

`DO_NOTHING` 상태에서 PK 충돌 발생 시 해당 row는 skip되고 CloudWatch 에러 로그에 기록된다.

### 우리 케이스 적용

`analysis_userdata.ans_current_conditions` 컬럼은 source `user_profile`에 없다.
→ DMS가 해당 컬럼을 무시하므로, **analysis 서비스가 직접 이 컬럼을 채워 넣는 구조로 사용 가능**.

target 전용 컬럼은 application 레이어에서 별도 관리하면 된다. DMS가 덮어쓰거나 삭제하지 않는다.

---

## 다른 서비스로 DB 확장 시

현재는 `vitamin_user` → `vitamin_analysis` 단방향 동기화이다.
다른 서비스 DB(예: `vitamin_history`)로도 동기화가 필요한 경우 아래 절차를 따른다.

### 1. Target Endpoint 추가

`dms.tf`에 새 target endpoint 리소스 추가:

```hcl
resource "aws_dms_endpoint" "target_history" {
  endpoint_id   = "${local.name_prefix}-tgt-history"
  endpoint_type = "target"
  engine_name   = "aurora-postgresql"

  server_name   = local.history_secret["host"]
  port          = local.history_secret["port"]
  database_name = local.history_secret["dbname"]
  username      = local.history_secret["username"]
  password      = local.history_secret["password"]

  ssl_mode = "require"
}
```

### 2. Replication Task 추가

동기화할 테이블 조합에 맞는 `aws_dms_replication_task` 리소스를 추가한다.
`table_mappings`의 selection/transformation rules 패턴은 기존 task 참고.

### 3. Source는 공유

source endpoint(`src-users`)는 재사용 가능하다.
**복제 인스턴스도 하나로 여러 task를 동시에 돌릴 수 있다.**
단, task 수가 많아지면 인스턴스 스펙(메모리) 업그레이드 필요.

### 4. 컬럼 매핑이 없는 경우 (컬럼명 동일)

source/target 컬럼명이 같다면 transformation rule 없이 selection rule만 작성하면 된다:

```hcl
rules = [
  {
    rule-type   = "selection"
    rule-id     = "1"
    rule-name   = "sel-some-table"
    rule-action = "include"
    object-locator = {
      schema-name = "public"
      table-name  = "some_table"
    }
  }
]
```

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|---|---|---|
| Source endpoint 연결 실패 | 보안그룹 5432 미허용 | `aws_security_group_rule.rds_allow_dms` 적용 확인 |
| CDC 시작 안됨 | Logical replication 미활성화 | 파라미터 그룹 적용 + 재시작 확인 |
| `rds_replication` 권한 오류 | DB 사용자 권한 없음 | 1-2 단계 SQL 재실행 |
| Target에 데이터 없음 | Target 테이블 미생성 | analysis DB schema 확인 |
| Task `failed` 상태 | CloudWatch 로그에서 상세 확인 | `/aws/dms/tasks/<id>` 로그 그룹 |
