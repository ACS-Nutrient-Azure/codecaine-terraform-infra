# NAT Gateway

Private 서브넷에 아웃바운드 인터넷 연결 제공

## 리소스
- NAT Gateway (1개 또는 2개)
- Elastic IP
- Private Route Tables

## 비용 절감
- `nat_gateway_count = 1`: 단일 NAT (비용 절감)
- `nat_gateway_count = 2`: 이중화 NAT (고가용성)

## 배포
```bash
terraform init
terraform apply
```

## 삭제
```bash
terraform destroy
```
