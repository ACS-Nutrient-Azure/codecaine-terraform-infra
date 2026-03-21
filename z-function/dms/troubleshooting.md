# DMS Troubleshooting

---

## 1. pglogical is not in shared_preload_libraries

**증상**
```
ERROR: pglogical is not in shared_preload_libraries
ERROR: relation "pglogical.replication_set" does not exist
```

**원인**
Source endpoint의 `extra_connection_attributes`에 `pluginName=pglogical`이 설정되어 있지만, RDS에 pglogical 확장이 설치되어 있지 않음.

**해결**
`pluginName`을 RDS에 기본 내장된 `test_decoding`으로 변경.

```bash
aws dms modify-endpoint \
  --endpoint-arn <source-endpoint-arn> \
  --extra-connection-attributes "heartbeatFrequency=1;pluginName=test_decoding" \
  --region ap-northeast-2
```

`dms.tf` 에도 동일하게 반영:
```hcl
extra_connection_attributes = "heartbeatFrequency=1;pluginName=test_decoding"
```

변경 후 태스크 재시작 필요.

---

## 2. DMS engine version not found

**증상**
```
Error: creating DMS Replication Instance: InvalidParameterValueException: Invalid replication engine version
```

**원인**
`engine_version = "3.5.3"` 이 해당 리전에 없음.

**해결**
`dms.tf`에서 버전을 `3.5.4`로 수정.

```hcl
engine_version = "3.5.4"
```

---

## 3. Full-load 실패 — analysis_userdata 테이블 로드 오류

**증상**
```
Handling End of table 'public'.'analysis_userdata' loading failed by subtask 1 thread 1
Command failed to load data with exit error code 0 and exitwhy 1
```
- DMS 태스크: `TablesErrored = 1` (user_profile), `TablesLoaded = 2`
- 소스에서 3개 행이 전송됐지만 타겟에서 전부 실패

**원인**
`TargetTablePrepMode = "DO_NOTHING"` 설정 시 DMS는 타겟 테이블을 비우지 않고 `INSERT`로 데이터를 적재함.
Analysis 앱이 이미 `analysis_userdata`에 데이터를 직접 기록한 상태였고, 소스에서 온 `cognito_id`와 중복되어 PK 위반 발생.
DMS는 COPY (bulk insert) 방식을 사용하므로, 배치 내 1개 행이라도 실패하면 **전체 배치가 롤백**됨.

**해결**
타겟 테이블의 기존 데이터를 삭제한 후 태스크를 재시작.

```bash
# 1. 타겟 DB에서 기존 데이터 삭제 (SSM 터널 연결 후)
PGPASSWORD='<password>' psql -h localhost -p <local-port> -U vitamin_analysis -d vitamin_analysis \
  -c "DELETE FROM analysis_userdata;"

# 2. DMS 태스크 중지
aws dms stop-replication-task \
  --replication-task-arn <task-arn> \
  --region ap-northeast-2

# 3. reload-target으로 재시작 (full-load 다시 실행)
aws dms start-replication-task \
  --replication-task-arn <task-arn> \
  --start-replication-task-type reload-target \
  --region ap-northeast-2
```

**주의**
- `start-replication` 타입은 태스크 최초 실행 시에만 사용 가능. 이미 한 번 실행된 태스크는 `reload-target` 사용.
- `analysis_userdata`에 Analysis 앱이 직접 쓴 컬럼(`ans_current_conditions` 등)은 소스(`user_profile`)에 없으므로, reload 후 해당 컬럼은 NULL로 초기화됨.

---

## 4. current_ingredients → anaysis_current_ingredients cognito_id 컬럼 오류 (잠재적)

**증상**
소스 `current_ingredients` 테이블에 `cognito_id` 컬럼이 있지만, 타겟 `anaysis_current_ingredients`에는 해당 컬럼이 없음.
현재는 소스 데이터가 0건이라 에러가 발생하지 않았지만, 데이터가 생기면 아래 오류 발생:
```
column "cognito_id" of relation "anaysis_current_ingredients" does not exist
```

**해결**
`dms.tf` table_mappings에 `remove-column` 변환 규칙 추가 (rule-id: 306):
```hcl
{
  rule-type   = "transformation"
  rule-id     = "306"
  rule-name   = "remove-ci-cognito-id"
  rule-action = "remove-column"
  rule-target = "column"
  object-locator = {
    schema-name = "public"
    table-name  = "current_ingredients"
    column-name = "cognito_id"
  }
}
```

변경 후 `terraform apply` 및 태스크 재시작 필요.

---

## SSM 포트 포워딩으로 RDS 접속

```bash
# Analysis DB (port 5434)
aws ssm start-session \
  --target <bastion-instance-id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["cdci-prd-analysis.czywucycklo5.ap-northeast-2.rds.amazonaws.com"],"portNumber":["5432"],"localPortNumber":["5434"]}' \
  --region ap-northeast-2

# Users DB (port 5433)
aws ssm start-session \
  --target <bastion-instance-id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["cdci-prd-users.czywucycklo5.ap-northeast-2.rds.amazonaws.com"],"portNumber":["5432"],"localPortNumber":["5433"]}' \
  --region ap-northeast-2
```
