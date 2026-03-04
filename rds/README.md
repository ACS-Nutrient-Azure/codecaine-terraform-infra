# RDS MySQL

## 리소스
- RDS MySQL 8.0
- Security Group

## 설정
- `multi_az = false`: Single-AZ (비용 절감)
- `multi_az = true`: Multi-AZ (고가용성)
- `skip_final_snapshot = true`: 삭제시 스냅샷 생략
- `backup_retention_period = 0`: 백업 비활성화

## 배포
```bash
terraform init
terraform apply
```

## 삭제
```bash
terraform destroy
```

## 주의
- `db_password`를 반드시 변경하세요
