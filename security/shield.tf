# AWS Shield Standard (무료 - 자동 활성화)
# 
# Shield Standard는 AWS에서 모든 고객에게 자동으로 제공하는 무료 DDoS 방어 서비스입니다.
# 별도의 Terraform 리소스 생성이나 활성화 작업이 필요하지 않습니다.
#
# Shield Standard 보호 대상:
# - Amazon CloudFront
# - Amazon Route 53
# - Elastic Load Balancing (ALB, CLB, NLB)
# - AWS Global Accelerator
# - Elastic IP addresses
#
# Shield Standard 기능:
# - Layer 3/4 DDoS 공격 자동 탐지 및 완화
# - 항상 활성화된 네트워크 흐름 모니터링
# - 인라인 공격 완화 (지연 시간 최소화)
#
# 참고: Shield Advanced ($3000/month)는 사용하지 않습니다.
# Shield Advanced는 다음을 추가로 제공하지만 비용이 높습니다:
# - DDoS Response Team (DRT) 24/7 지원
# - 비용 보호 (DDoS 공격으로 인한 비용 환불)
# - 고급 공격 탐지 및 실시간 알림
# - Layer 7 (애플리케이션 계층) 공격 방어
