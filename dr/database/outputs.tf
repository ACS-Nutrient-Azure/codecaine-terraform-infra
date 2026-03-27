output "dr_cluster_endpoints" {
  value = {
    cluster1 = aws_rds_cluster.dr_cluster1.endpoint
    cluster2 = aws_rds_cluster.dr_cluster2.endpoint
    cluster3 = aws_rds_cluster.dr_cluster3.endpoint
    cluster4 = aws_rds_cluster.dr_cluster4.endpoint
  }
}

output "dr_cluster_arns" {
  value = {
    cluster1 = aws_rds_cluster.dr_cluster1.arn
    cluster2 = aws_rds_cluster.dr_cluster2.arn
    cluster3 = aws_rds_cluster.dr_cluster3.arn
    cluster4 = aws_rds_cluster.dr_cluster4.arn
  }
}
