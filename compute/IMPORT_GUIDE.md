# Terraform Import Guide

기존 AWS 리소스를 Terraform state로 가져오는 가이드입니다.

## 1. ALB 및 관련 리소스 Import

```bash
cd compute

# 1. ALB Import
terraform import aws_lb.main arn:aws:elasticloadbalancing:ap-northeast-2:365827924759:loadbalancer/app/cdci-prd-alb/e608329d221edeed

# 2. Listener ARN 조회
aws elbv2 describe-listeners \
  --load-balancer-arn arn:aws:elasticloadbalancing:ap-northeast-2:365827924759:loadbalancer/app/cdci-prd-alb/e608329d221edeed \
  --region ap-northeast-2

# 3. HTTP Listener Import (위에서 조회한 ARN 사용)
# 예시: terraform import aws_lb_listener.http arn:aws:elasticloadbalancing:ap-northeast-2:365827924759:listener/app/cdci-prd-alb/e608329d221edeed/1234567890abcdef

# 4. Target Group ARN 조회
aws elbv2 describe-target-groups \
  --load-balancer-arn arn:aws:elasticloadbalancing:ap-northeast-2:365827924759:loadbalancer/app/cdci-prd-alb/e608329d221edeed \
  --region ap-northeast-2

# 5. Target Group Import (위에서 조회한 ARN 사용)
# 예시: terraform import aws_lb_target_group.app arn:aws:elasticloadbalancing:ap-northeast-2:365827924759:targetgroup/cdci-prd-tg/1234567890abcdef
```

## 2. 자동 Import 스크립트

```bash
#!/bin/bash

cd compute

# ALB ARN
ALB_ARN="arn:aws:elasticloadbalancing:ap-northeast-2:365827924759:loadbalancer/app/cdci-prd-alb/e608329d221edeed"

# 1. ALB Import
echo "Importing ALB..."
terraform import aws_lb.main $ALB_ARN

# 2. Listener Import
echo "Getting Listener ARN..."
LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn $ALB_ARN \
  --region ap-northeast-2 \
  --query 'Listeners[?Port==`80`].ListenerArn' \
  --output text)

if [ -n "$LISTENER_ARN" ]; then
  echo "Importing HTTP Listener: $LISTENER_ARN"
  terraform import aws_lb_listener.http $LISTENER_ARN
else
  echo "HTTP Listener not found"
fi

# 3. Target Group Import
echo "Getting Target Group ARN..."
TG_ARN=$(aws elbv2 describe-target-groups \
  --load-balancer-arn $ALB_ARN \
  --region ap-northeast-2 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

if [ -n "$TG_ARN" ]; then
  echo "Importing Target Group: $TG_ARN"
  terraform import aws_lb_target_group.app $TG_ARN
else
  echo "Target Group not found"
fi

echo "Import completed!"
```

## 3. 또는 기존 리소스 삭제 후 재생성

기존 리소스를 삭제하고 Terraform으로 새로 생성하려면:

```bash
# ALB 삭제 (AWS Console 또는 CLI)
aws elbv2 delete-load-balancer \
  --load-balancer-arn arn:aws:elasticloadbalancing:ap-northeast-2:365827924759:loadbalancer/app/cdci-prd-alb/e608329d221edeed \
  --region ap-northeast-2

# Target Group 삭제 (ALB 삭제 후)
aws elbv2 delete-target-group \
  --target-group-arn <TARGET_GROUP_ARN> \
  --region ap-northeast-2

# Terraform apply
cd compute
terraform apply
```

## 4. 권장 방법

**Import 방법을 권장합니다:**
- 기존 리소스를 유지하면서 Terraform으로 관리 가능
- 서비스 중단 없음
- 설정 변경 사항만 적용

## 5. Import 후 확인

```bash
cd compute

# State 확인
terraform state list

# Plan 확인 (변경사항이 없어야 함)
terraform plan
```

## 6. ECR Repository Import (필요시)

```bash
cd compute

# ECR 레포지토리 import
terraform import 'aws_ecr_repository.repositories["codecaine-analysis"]' codecaine-analysis
terraform import 'aws_ecr_repository.repositories["codecaine-frontend"]' codecaine-frontend
terraform import 'aws_ecr_repository.repositories["codecaine-mypage"]' codecaine-mypage
terraform import 'aws_ecr_repository.repositories["codecaine-chatbot"]' codecaine-chatbot
terraform import 'aws_ecr_repository.repositories["codecaine-codef"]' codecaine-codef
```

## 주의사항

1. Import 전에 반드시 백업:
   ```bash
   cp terraform.tfstate terraform.tfstate.backup
   ```

2. Import는 리소스를 state에만 추가하며, 실제 AWS 리소스는 변경하지 않습니다.

3. Import 후 `terraform plan`으로 변경사항 확인 필수

4. 여러 리소스를 import할 때는 의존성 순서 고려:
   - ALB → Target Group → Listener 순서로 import
