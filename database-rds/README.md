# Database RDS Module

이 모듈은 AWS Aurora PostgreSQL 클러스터 3개를 관리합니다. 각 클러스터는 서로 다른 역할을 수행합니다.

## 주요 특징

- **기존 VPC 사용**: foundation 모듈에서 생성된 VPC 리소스 사용
- **VPC 피어링 불필요**: 동일 VPC 내에서 RDS 생성
- **간소화된 네트워크**: 별도 VPC 생성 없이 기존 인프라 활용
- **역할별 클러스터**: users-cluster, history-cluster, analysis-cluster
- **인스턴스 네이밍**: Writer (-wo), Reader (-ro) 접미사
- **비밀번호 관리**: terraform.tfvars에서 직접 지정

## 파일 구조

### Aurora 클러스터별 파일
- `rds-cluster-db1.tf` - Aurora Cluster 1 (users-cluster) - 사용자 데이터
- `rds-cluster-db2.tf` - Aurora Cluster 2 (history-cluster) - 히스토리 데이터
- `rds-cluster-db3.tf` - Aurora Cluster 3 (analysis-cluster) - 분석 데이터

### 공통 파일
- `rds-common.tf` - 공통 리소스 (파라미터 그룹, IAM 역할)
- `main.tf` - Provider 설정 및 foundation 모듈 참조
- `variables.tf` - 변수 정의
- `outputs.tf` - 출력 값
- `network.tf` - 네트워크 리소스 참조 (foundation 모듈)

## 리팩토링 내역

### 최신 변경 사항 (기존 VPC 사용)
1. **VPC 피어링 제거**: 동일 VPC 사용으로 피어링 불필요
2. **네트워크 간소화**: foundation 모듈의 VPC 리소스 직접 참조
3. **변수 정리**: 불필요한 네트워크 관련 변수 제거

### 이전 변경 사항
1. **일반 RDS → Aurora 전환**: 3개의 일반 RDS 인스턴스를 Aurora Cluster로 변경
2. **역할별 클러스터 분리**: 각 Aurora Cluster가 독립적인 역할 수행
3. **고가용성**: Aurora Serverless v2로 자동 스케일링 지원
4. **클러스터별 파일 분리**: 각 Aurora 클러스터를 독립 파일로 분리
5. **공통 리소스 통합**: 파라미터 그룹과 IAM 역할을 rds-common.tf로 통합

### 장점
- 특정 클러스터만 수정 시 영향 범위 최소화
- 코드 가독성 및 유지보수성 향상
- 클러스터별 독립적인 관리 가능
- Aurora의 고가용성 및 자동 백업 기능 활용
- 네트워크 구성 간소화 및 관리 용이성 향상

## 의존성

이 모듈은 다음 모듈에 의존합니다:

1. **foundation 모듈** (필수)
   - VPC ID
   - Private DB Subnet IDs
   - DB Subnet Group Name
   - RDS Security Group ID

```bash
# foundation 모듈을 먼저 배포해야 합니다
cd ../foundation
terraform init
terraform apply

# 그 다음 database-rds 모듈 배포
cd ../database-rds
terraform init
terraform apply
```

## 개별 삭제

클러스터별 파일 분리로 인해 특정 데이터베이스만 삭제할 수 있습니다.

### 삭제 보호 설정

환경별로 다른 삭제 보호 정책이 적용됩니다:

- **prd 환경**
  - `deletion_protection = true` - 삭제 보호 활성화
  - `skip_final_snapshot = false` - 최종 스냅샷 생성
  - `final_snapshot_identifier` - 스냅샷 이름 자동 생성
  
- **dev 환경**
  - `deletion_protection = false` - 삭제 보호 비활성화
  - `skip_final_snapshot = true` - 최종 스냅샷 생성 안 함

### 특정 클러스터 삭제 방법

#### 1. prd 환경에서 Aurora 클러스터 삭제
프로덕션 환경은 삭제 보호가 활성화되어 있으므로 다음 단계를 따라야 합니다:

```bash
# 1단계: 해당 클러스터 파일에서 deletion_protection을 false로 변경
# 예: rds-cluster-db2.tf 파일 수정
# deletion_protection = false

# 2단계: 변경 사항 적용
terraform apply -target=aws_rds_cluster.aurora_cluster2

# 3단계: 리소스 삭제 (인스턴스 먼저, 그 다음 클러스터)
terraform destroy -target=aws_rds_cluster_instance.aurora_cluster2 \
                  -target=aws_rds_cluster.aurora_cluster2 \
                  -target=random_password.aurora_cluster2 \
                  -target=aws_secretsmanager_secret.aurora_cluster2 \
                  -target=aws_secretsmanager_secret_version.aurora_cluster2

# Global Database가 활성화된 경우
terraform destroy -target=aws_rds_global_cluster.aurora_cluster2

# 최종 스냅샷이 자동으로 생성됩니다
```

#### 2. dev 환경에서 Aurora 클러스터 삭제
```bash
# 예: cluster2 Aurora 클러스터만 삭제
terraform destroy -target=aws_rds_cluster_instance.aurora_cluster2 \
                  -target=aws_rds_cluster.aurora_cluster2 \
                  -target=random_password.aurora_cluster2 \
                  -target=aws_secretsmanager_secret.aurora_cluster2 \
                  -target=aws_secretsmanager_secret_version.aurora_cluster2
```

### 주의사항

- **프로덕션 환경**: 삭제 전 반드시 백업 확인
- **최종 스냅샷**: prd 환경에서는 자동으로 생성되며, 스냅샷 이름은 `{project_name}-{environment}-{identifier}-final-snapshot` 형식
- **의존성**: Secrets Manager와 Random Password 리소스도 함께 삭제 필요
- **롤백**: 삭제 후 복구가 필요한 경우 최종 스냅샷에서 복원 가능
- **Aurora 특성**: Aurora는 클러스터 단위로 관리되므로 인스턴스를 먼저 삭제해야 함

## 사용 방법

```bash
# 초기화
terraform init

# 계획 확인
terraform plan

# 적용
terraform apply
```

## Aurora Cluster 역할

각 Aurora Cluster는 다음과 같은 역할을 수행합니다:

- **users-cluster**: 사용자 데이터 저장 및 관리
- **history-cluster**: 히스토리 데이터 저장 및 관리
- **analysis-cluster**: 분석 데이터 저장 및 관리

## 인스턴스 네이밍 규칙

- **Writer 인스턴스**: `-wo` 접미사 (예: cdci-prd-users-cluster-wo)
- **Reader 인스턴스**: `-ro` 접미사 (예: cdci-prd-users-cluster-ro)

## 비밀번호 관리

비밀번호는 `terraform.tfvars`에서 직접 지정하며, AWS Secrets Manager에 자동으로 저장됩니다:

```hcl
# terraform.tfvars
db_password = "your-secure-password-here"
```

**주의사항**:
- 프로덕션 환경에서는 강력한 비밀번호 사용
- terraform.tfvars 파일은 .gitignore에 추가하여 버전 관리에서 제외
- Secrets Manager에서 비밀번호 조회 가능
