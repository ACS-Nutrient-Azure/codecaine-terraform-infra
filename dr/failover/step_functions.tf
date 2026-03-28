# Failover Lambda
data "archive_file" "failover" {
  type        = "zip"
  source_file = "${path.module}/failover_lambda.py"
  output_path = "${path.module}/files/failover.zip"
}

resource "aws_iam_role" "failover_lambda" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-DR-FAILOVER-LAMBDA-ROLE"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "failover_lambda_basic" {
  role       = aws_iam_role.failover_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "failover_lambda_policy" {
  name = "dr-failover-policy"
  role = aws_iam_role.failover_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Aurora Global Failover
      {
        Effect   = "Allow"
        Action   = ["rds:FailoverGlobalCluster", "rds:DescribeGlobalClusters", "rds:DescribeDBClusters"]
        Resource = "*"
      },
      # ECS 서비스 업데이트
      {
        Effect   = "Allow"
        Action   = ["ecs:UpdateService", "ecs:DescribeServices"]
        Resource = "*"
      },
      # DR AgentCore Provisioner Lambda 호출
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = "arn:aws:lambda:${var.dr_region}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-${var.environment}-dr-agentcore-provisioner"
      },
      # SSM 파라미터 읽기/쓰기
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:PutParameter"]
        Resource = "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
      },
      # SNS 알림
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.dr_alert.arn
      },
      # STS (account ID 조회)
      {
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "failover" {
  function_name    = lower("${var.project_name}-${var.environment}-dr-failover")
  runtime          = "python3.12"
  handler          = "failover_lambda.lambda_handler"
  role             = aws_iam_role.failover_lambda.arn
  timeout          = 300
  memory_size      = 256
  filename         = data.archive_file.failover.output_path
  source_code_hash = data.archive_file.failover.output_base64sha256

  environment {
    variables = {
      PRIMARY_REGION = var.primary_region
      DR_REGION      = var.dr_region
      PROJECT_NAME   = var.project_name
      ENVIRONMENT    = var.environment
      SNS_TOPIC_ARN  = aws_sns_topic.dr_alert.arn
    }
  }
}

# ── Step Functions DR Orchestrator ───────────────────────────────

resource "aws_iam_role" "step_functions" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-DR-STEP-FUNCTIONS-ROLE"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "states.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "step_functions_policy" {
  name = "step-functions-invoke-lambda"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = aws_lambda_function.failover.arn
    }]
  })
}

resource "aws_sfn_state_machine" "dr_orchestrator" {
  name     = "${var.project_name}-${var.environment}-dr-orchestrator"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "DR Failover Orchestrator: 서울 → 도쿄"
    StartAt = "AuroraFailover"

    States = {
      # Step 1: Aurora Global DB Failover
      AuroraFailover = {
        Type       = "Task"
        Resource   = aws_lambda_function.failover.arn
        Parameters = { "action" = "aurora_failover" }
        Retry = [{
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 10
          MaxAttempts     = 2
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "ActivateECS"
      }

      # Step 2: DR ECS 활성화 (desired_count 0 → 2)
      ActivateECS = {
        Type       = "Task"
        Resource   = aws_lambda_function.failover.arn
        Parameters = { "action" = "activate_ecs" }
        Retry = [{
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 5
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "ProvisionAgentCore"
      }

      # Step 3: DR AgentCore Runtime 생성 (analysis → chatbot → summary 순)
      ProvisionAgentCore = {
        Type       = "Task"
        Resource   = aws_lambda_function.failover.arn
        Parameters = { "action" = "provision_agentcore" }
        Retry = [{
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 15
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "UpdateSSMEndpoints"
      }

      # Step 4: DR DB endpoint → SSM 업데이트 (ECS Task 재시작 트리거)
      UpdateSSMEndpoints = {
        Type       = "Task"
        Resource   = aws_lambda_function.failover.arn
        Parameters = { "action" = "update_ssm_endpoints" }
        Retry = [{
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 10
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "NotifySuccess"
      }

      # 완료 알림
      NotifySuccess = {
        Type     = "Task"
        Resource = aws_lambda_function.failover.arn
        Parameters = {
          "action"  = "notify"
          "status"  = "SUCCESS"
          "message" = "DR Failover 완료: 서울 → 도쿄"
        }
        End = true
      }

      # 실패 알림
      NotifyFailure = {
        Type     = "Task"
        Resource = aws_lambda_function.failover.arn
        Parameters = {
          "action"  = "notify"
          "status"  = "FAILED"
          "message" = "DR Failover 실패 - 수동 개입 필요"
        }
        Next = "FailState"
      }

      FailState = {
        Type  = "Fail"
        Error = "DRFailoverFailed"
        Cause = "DR Failover 중 오류 발생. SNS 알림 확인 후 수동 처리 필요."
      }
    }
  })

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-ORCHESTRATOR" }
}

# ── Failback Lambda ──────────────────────────────────────────────

data "archive_file" "failback" {
  type        = "zip"
  source_file = "${path.module}/failback_lambda.py"
  output_path = "${path.module}/files/failback.zip"
}

resource "aws_iam_role" "failback_lambda" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-DR-FAILBACK-LAMBDA-ROLE"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "failback_lambda_basic" {
  role       = aws_iam_role.failback_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "failback_lambda_policy" {
  name = "dr-failback-policy"
  role = aws_iam_role.failback_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Aurora Global Failback (서울 재승격)
      {
        Effect   = "Allow"
        Action   = ["rds:FailoverGlobalCluster", "rds:DescribeGlobalClusters", "rds:DescribeDBClusters"]
        Resource = "*"
      },
      # ECS 서비스 업데이트 (서울 복구 + 도쿄 비활성화)
      {
        Effect   = "Allow"
        Action   = ["ecs:UpdateService", "ecs:DescribeServices"]
        Resource = "*"
      },
      # DR AgentCore Runtime 삭제
      {
        Effect   = "Allow"
        Action   = ["bedrock-agentcore:DeleteAgentRuntime", "bedrock-agentcore:GetAgentRuntime"]
        Resource = "arn:aws:bedrock-agentcore:${var.dr_region}:${data.aws_caller_identity.current.account_id}:agent-runtime/*"
      },
      # SSM 파라미터 읽기/쓰기 (서울 + 도쿄)
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:PutParameter"]
        Resource = "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
      },
      # SNS 알림
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.dr_alert.arn
      },
      # STS (account ID 조회)
      {
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "failback" {
  function_name    = lower("${var.project_name}-${var.environment}-dr-failback")
  runtime          = "python3.12"
  handler          = "failback_lambda.lambda_handler"
  role             = aws_iam_role.failback_lambda.arn
  timeout          = 600 # Failback은 Aurora 재승격 대기로 더 긴 타임아웃 필요
  memory_size      = 256
  filename         = data.archive_file.failback.output_path
  source_code_hash = data.archive_file.failback.output_base64sha256

  environment {
    variables = {
      PRIMARY_REGION  = var.primary_region
      DR_REGION       = var.dr_region
      PROJECT_NAME    = var.project_name
      ENVIRONMENT     = var.environment
      SNS_TOPIC_ARN   = aws_sns_topic.dr_alert.arn
      PRIMARY_ALB_DNS = data.terraform_remote_state.compute.outputs.alb_dns_name
    }
  }
}

# ── Step Functions DR Failback Orchestrator ───────────────────────

resource "aws_iam_role_policy" "step_functions_failback_policy" {
  name = "step-functions-invoke-failback-lambda"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = aws_lambda_function.failback.arn
    }]
  })
}

resource "aws_sfn_state_machine" "dr_failback_orchestrator" {
  name     = "${var.project_name}-${var.environment}-dr-failback-orchestrator"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "DR Failback Orchestrator: 도쿄 → 서울 자동 복구"
    StartAt = "CheckPrimaryHealth"

    States = {
      # Step 1: 서울 ALB 헬스체크 확인 (최대 3회 재시도, 5분 간격)
      CheckPrimaryHealth = {
        Type       = "Task"
        Resource   = aws_lambda_function.failback.arn
        Parameters = { "action" = "check_primary_health" }
        Retry = [{
          ErrorEquals     = ["States.TaskFailed", "RuntimeError"]
          IntervalSeconds = 300 # 5분 대기 후 재시도
          MaxAttempts     = 3
          BackoffRate     = 1 # 고정 간격 (지수 증가 없음)
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "AuroraFailback"
      }

      # Step 2: Aurora Global DB Failback (도쿄 → 서울 재승격)
      AuroraFailback = {
        Type       = "Task"
        Resource   = aws_lambda_function.failback.arn
        Parameters = { "action" = "aurora_failback" }
        Retry = [{
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 30
          MaxAttempts     = 2
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "RestoreSSMEndpoints"
      }

      # Step 3: 서울 원본 SSM 파라미터 복구
      RestoreSSMEndpoints = {
        Type       = "Task"
        Resource   = aws_lambda_function.failback.arn
        Parameters = { "action" = "restore_ssm_endpoints" }
        Retry = [{
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 10
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "ActivatePrimaryECS"
      }

      # Step 4: 서울 ECS 서비스 desired_count 복구 (0 → 2)
      ActivatePrimaryECS = {
        Type       = "Task"
        Resource   = aws_lambda_function.failback.arn
        Parameters = { "action" = "activate_primary_ecs" }
        Retry = [{
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 5
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "DeactivateDRECS"
      }

      # Step 5: 도쿄 DR ECS 비활성화 (서울 복구 확인 후 수행)
      DeactivateDRECS = {
        Type       = "Task"
        Resource   = aws_lambda_function.failback.arn
        Parameters = { "action" = "deactivate_dr_ecs" }
        Retry = [{
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 10
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "CleanupDRAgentCore"
      }

      # Step 6: 도쿄 AgentCore Runtime 삭제
      CleanupDRAgentCore = {
        Type       = "Task"
        Resource   = aws_lambda_function.failback.arn
        Parameters = { "action" = "cleanup_dr_agentcore" }
        Retry = [{
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 10
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "NotifySuccess"
      }

      # 완료 알림
      NotifySuccess = {
        Type     = "Task"
        Resource = aws_lambda_function.failback.arn
        Parameters = {
          "action"  = "notify"
          "status"  = "SUCCESS"
          "message" = "DR Failback 완료: 도쿄 → 서울 복구"
        }
        End = true
      }

      # 실패 알림 (도쿄 서비스 유지 - 안전 우선)
      NotifyFailure = {
        Type     = "Task"
        Resource = aws_lambda_function.failback.arn
        Parameters = {
          "action"  = "notify"
          "status"  = "FAILED"
          "message" = "DR Failback 실패 - 도쿄 서비스 유지 중. 수동 개입 필요"
        }
        Next = "FailState"
      }

      FailState = {
        Type  = "Fail"
        Error = "DRFailbackFailed"
        Cause = "DR Failback 중 오류 발생. 도쿄 서비스는 유지됩니다. SNS 알림 확인 후 수동 처리 필요."
      }
    }
  })

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-FAILBACK-ORCHESTRATOR" }
}

# ── EventBridge: Failback Step Functions 실행 역할 ────────────────

resource "aws_iam_role_policy" "eventbridge_sfn_failback_policy" {
  name = "start-failback-execution"
  role = aws_iam_role.eventbridge_sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = aws_sfn_state_machine.dr_failback_orchestrator.arn
    }]
  })
}

# ── EventBridge: Composite Alarm ALARM 상태 → Step Functions 실행 ──

resource "aws_iam_role" "eventbridge_sfn" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-DR-EVENTBRIDGE-SFN-ROLE"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "events.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "eventbridge_sfn_policy" {
  name = "start-execution"
  role = aws_iam_role.eventbridge_sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = aws_sfn_state_machine.dr_orchestrator.arn
    }]
  })
}

# CloudWatch Alarm 상태 변경 이벤트 → Step Functions
resource "aws_cloudwatch_event_rule" "dr_trigger" {
  name        = "${var.project_name}-${var.environment}-dr-trigger"
  description = "DR Composite Alarm ALARM 상태 → Step Functions 실행"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName = ["${var.project_name}-${var.environment}-DR-TRIGGER"]
      state     = { value = ["ALARM"] }
    }
  })
}

resource "aws_cloudwatch_event_target" "dr_step_functions" {
  rule      = aws_cloudwatch_event_rule.dr_trigger.name
  target_id = "dr-step-functions"
  arn       = aws_sfn_state_machine.dr_orchestrator.arn
  role_arn  = aws_iam_role.eventbridge_sfn.arn
}
