project_name = "cdci"
environment  = "prd"
region       = "ap-northeast-2"

reminder_days_threshold = 30
schedule_expression     = "cron(0 0 * * ? *)" # KST 09:00 (UTC 00:00)
ses_from_email          = "noreply@codecaine.store"
