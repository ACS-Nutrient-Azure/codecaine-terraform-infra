# DR 클러스터 ARN을 SSM에 저장 → Failover Lambda가 참조
# (failover_lambda.py의 DR_CLUSTER_ARNS_SSM_KEY)

resource "aws_ssm_parameter" "dr_cluster_arns" {
  provider = aws.primary # Primary 리전 SSM에 저장 (Failover Lambda가 Primary에서 실행)
  name     = "/${var.project_name}/${var.environment}/dr/aurora-cluster-arns"
  type     = "String"

  value = jsonencode({
    cluster1 = aws_rds_cluster.dr_cluster1.arn
    cluster2 = aws_rds_cluster.dr_cluster2.arn
    cluster3 = aws_rds_cluster.dr_cluster3.arn
    cluster4 = aws_rds_cluster.dr_cluster4.arn
  })

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-CLUSTER-ARNS" }
}

# DR AgentCore Runtime Role ARN도 SSM에 저장 → Failover Lambda가 참조
# (dr/agentcore 모듈 apply 후 수동으로 채워지거나, 별도 data source로 참조 가능)
# 여기서는 dr/agentcore outputs를 참조하는 별도 SSM 파라미터로 관리
