# Compute Resources

## 리소스
- Bastion Host (Amazon Linux 2023)
- Security Group

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
- `key_name`을 AWS에 생성된 키페어로 변경
- `my_ip`를 본인 IP로 변경 (보안)
