project_name = "cdci"
environment  = "prd"
region       = "ap-northeast-2"

postgres_port     = 5432
postgres_version  = "15.10"
instance_class    = "db.t3.micro"
allocated_storage = 20

multi_az                = false
skip_final_snapshot     = true
deletion_protection     = false
backup_retention_period = 0
