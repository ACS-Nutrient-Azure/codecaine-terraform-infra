# DynamoDB Module (Global Table 지원)

DynamoDB 테이블과 Global Table을 관리하는 모듈입니다.

## 리소스

- DynamoDB Table
- DynamoDB Streams (Global Table 사용 시)
- Global Table Replicas (다중 리전)
- Auto Scaling (PROVISIONED 모드 시)
- Point-in-Time Recovery
- Server-Side Encryption (KMS)

## 기능

### 단일 리전 테이블
- PAY_PER_REQUEST 또는 PROVISIONED 모드
- Global Secondary Index (GSI)
- TTL 지원
- 암호화 및 백업

### Global Table (다중 리전)
- 자동 다중 리전 복제
- 1초 미만의 복제 지연
- 리전별 읽기/쓰기 가능
- 재해 복구 (DR)

## 배포

### 단일 리전 테이블
```bash
cd database-dynamodb
terraform init
terraform apply
```

### Global Table 활성화
```hcl
# terraform.tfvars
enable_global_table = true
global_table_regions = ["ap-northeast-2", "us-east-1", "eu-west-1"]

# 리전별 KMS 키 (선택)
replica_kms_key_arns = {
  "us-east-1" = "arn:aws:kms:us-east-1:123456789012:key/..."
  "eu-west-1" = "arn:aws:kms:eu-west-1:123456789012:key/..."
}
```

```bash
terraform apply
```

## Global Table 사용 시나리오

### 1. 글로벌 애플리케이션
- 전 세계 사용자에게 낮은 지연시간 제공
- 가장 가까운 리전에서 읽기/쓰기

### 2. 재해 복구 (DR)
- 주 리전 장애 시 자동으로 다른 리전 사용
- 데이터 손실 없음 (RPO ≈ 0)

### 3. 데이터 로컬리티
- 규정 준수를 위한 리전별 데이터 저장
- 각 리전에서 독립적으로 읽기/쓰기

## 테이블 구조 예시

```hcl
dynamodb_tables = {
  users = {
    hash_key         = "userId"
    range_key        = "timestamp"
    billing_mode     = "PAY_PER_REQUEST"
    stream_enabled   = true
    stream_view_type = "NEW_AND_OLD_IMAGES"
    
    attributes = [
      { name = "userId", type = "S" },
      { name = "timestamp", type = "N" },
      { name = "email", type = "S" }
    ]
    
    global_secondary_indexes = [
      {
        name            = "EmailIndex"
        hash_key        = "email"
        range_key       = "timestamp"
        projection_type = "ALL"
      }
    ]
  }
}
```

## 데이터 접근

### AWS CLI
```bash
# 아이템 추가
aws dynamodb put-item \
  --table-name cdci-prd-ChatbotData \
  --item '{"id": {"S": "123"}, "timestamp": {"N": "1234567890"}}'

# 아이템 조회
aws dynamodb get-item \
  --table-name cdci-prd-ChatbotData \
  --key '{"id": {"S": "123"}, "timestamp": {"N": "1234567890"}}'

# 쿼리
aws dynamodb query \
  --table-name cdci-prd-ChatbotData \
  --key-condition-expression "id = :id" \
  --expression-attribute-values '{":id": {"S": "123"}}'
```

### Python (Boto3)
```python
import boto3

dynamodb = boto3.resource('dynamodb', region_name='ap-northeast-2')
table = dynamodb.Table('cdci-prd-ChatbotData')

# 아이템 추가
table.put_item(Item={'id': '123', 'timestamp': 1234567890})

# 아이템 조회
response = table.get_item(Key={'id': '123', 'timestamp': 1234567890})
print(response['Item'])
```

## Global Table 복제 모니터링

### CloudWatch 메트릭
```bash
# 복제 지연 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ReplicationLatency \
  --dimensions Name=TableName,Value=cdci-prd-ChatbotData \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Average
```

### 주요 메트릭
- `ReplicationLatency`: 복제 지연 시간 (밀리초)
- `ConsumedReadCapacityUnits`: 읽기 용량 소비
- `ConsumedWriteCapacityUnits`: 쓰기 용량 소비
- `UserErrors`: 사용자 오류 수

## 백업 및 복구

### Point-in-Time Recovery (PITR)
```bash
# PITR 활성화 (terraform.tfvars)
enable_dynamodb_point_in_time_recovery = true

# 특정 시점으로 복구
aws dynamodb restore-table-to-point-in-time \
  --source-table-name cdci-prd-ChatbotData \
  --target-table-name cdci-prd-ChatbotData-restored \
  --restore-date-time 2024-01-01T12:00:00Z
```

### 온디맨드 백업
```bash
# 백업 생성
aws dynamodb create-backup \
  --table-name cdci-prd-ChatbotData \
  --backup-name cdci-prd-ChatbotData-backup-$(date +%Y%m%d)

# 백업에서 복구
aws dynamodb restore-table-from-backup \
  --target-table-name cdci-prd-ChatbotData-restored \
  --backup-arn arn:aws:dynamodb:ap-northeast-2:123456789012:table/cdci-prd-ChatbotData/backup/...
```

## 성능 최적화

### 읽기 최적화
- 일관된 읽기 vs 최종 일관된 읽기
- GSI 활용
- 배치 읽기 (BatchGetItem)

### 쓰기 최적화
- 배치 쓰기 (BatchWriteItem)
- 조건부 쓰기로 불필요한 쓰기 방지
- TTL로 자동 삭제

### 파티션 키 설계
- 고르게 분산되는 키 선택
- 핫 파티션 방지
- 복합 키 활용

## 비용

### PAY_PER_REQUEST (온디맨드)
- 읽기: $0.25 per million requests
- 쓰기: $1.25 per million requests
- 스토리지: $0.25 per GB/month
- 예상: ~$1-10/month (소규모)

### PROVISIONED (프로비저닝)
- 읽기: $0.00013 per RCU/hour
- 쓰기: $0.00065 per WCU/hour
- 예상: ~$5-50/month (예측 가능한 트래픽)

### Global Table 추가 비용
- 리전 간 복제 쓰기: 쓰기 비용의 100% 추가
- 리전 간 데이터 전송: $0.02/GB
- 예상: 기본 비용의 2-3배

## 비용 최적화 팁

1. **프로덕션 환경**: 트래픽 예측 가능하면 PROVISIONED
2. **개발 환경**: PAY_PER_REQUEST 사용
3. **TTL 활용**: 오래된 데이터 자동 삭제
4. **GSI 최소화**: 필요한 인덱스만 생성
5. **배치 작업**: BatchGetItem, BatchWriteItem 사용

## 삭제

### 단일 테이블 삭제
```bash
terraform destroy -target=aws_dynamodb_table.main[\"ChatbotData\"]
```

### 전체 삭제
```bash
terraform destroy
```

## 보안

- 전송 중 암호화 (HTTPS)
- 저장 시 암호화 (KMS)
- IAM 역할 기반 접근 제어
- VPC 엔드포인트 지원
- CloudTrail 감사 로깅

## 문제 해결

### 복제 지연 증가
- 쓰기 용량 확인
- 네트워크 상태 확인
- CloudWatch 메트릭 분석

### 스로틀링 발생
- 용량 모드 확인 (PAY_PER_REQUEST 권장)
- 파티션 키 분산 확인
- 배치 작업 크기 조정

### 비용 급증
- CloudWatch 메트릭으로 사용량 확인
- 불필요한 GSI 제거
- TTL 설정으로 오래된 데이터 삭제

