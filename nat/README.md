# NAT Gateway Module

Private 서브넷의 아웃바운드 인터넷 연결을 위한 NAT Gateway 모듈입니다.

## 리소스

- NAT Gateway (리전당 1개 - 비용 최적화)
- Elastic IP (1개)
- Route Table 업데이트 (모든 Private App 서브넷이 단일 NAT Gateway 사용)

## 배포

```bash
cd nat
terraform init
terraform apply
```

## 비용

- NAT Gateway: ~$32/month (리전당 1개)
- 데이터 전송: 사용량 기반

## 주의사항

NAT Gateway는 시간당 과금되므로 사용하지 않을 때는 삭제하는 것이 좋습니다.

```bash
terraform destroy
```

## 아키텍처

**비용 최적화 구성**: 리전당 1개의 NAT Gateway를 첫 번째 가용영역(AZ)에 배치하여 비용을 절감합니다. 모든 Private App 서브넷이 이 단일 NAT Gateway를 공유합니다.

- AZ-1: Public Subnet → NAT Gateway (단일)
- AZ-2: Private App Subnet → NAT Gateway (AZ-1)
- 모든 Private 서브넷 → 단일 NAT Gateway

**참고**: 고가용성이 필요한 프로덕션 환경에서는 각 AZ마다 NAT Gateway를 배치하는 것을 권장합니다.
