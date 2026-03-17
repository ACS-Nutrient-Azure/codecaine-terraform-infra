# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  count = var.enable_cognito ? 1 : 0

  name = upper("${var.project_name}-${var.environment}-USER-POOL")

  # Username configuration
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password policy
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 3
  }

  # MFA configuration
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # User attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = false
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # Lambda triggers (선택)
  # lambda_config {
  #   pre_sign_up = aws_lambda_function.pre_signup[0].arn
  # }

  tags = {
    Name = upper("${var.project_name}-${var.environment}-USER-POOL")
  }
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "main" {
  count = var.enable_cognito ? 1 : 0

  name         = upper("${var.project_name}-${var.environment}-CLIENT")
  user_pool_id = aws_cognito_user_pool.main[0].id

  generate_secret = false

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  callback_urls = var.cognito_callback_urls
  logout_urls   = var.cognito_logout_urls

  supported_identity_providers = ["COGNITO"]

  # Token validity
  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  # Read/Write attributes
  read_attributes = [
    "email",
    "email_verified",
    "name"
  ]

  write_attributes = [
    "email",
    "name"
  ]
}

# Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "main" {
  count = var.enable_cognito ? 1 : 0

  domain       = "${var.project_name}-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main[0].id
}

# Cognito Identity Pool
resource "aws_cognito_identity_pool" "main" {
  count = var.enable_cognito ? 1 : 0

  identity_pool_name               = upper("${var.project_name}-${var.environment}-IDENTITY-POOL")
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.main[0].id
    provider_name           = aws_cognito_user_pool.main[0].endpoint
    server_side_token_check = false
  }

  tags = {
    Name = upper("${var.project_name}-${var.environment}-IDENTITY-POOL")
  }
}

# IAM Role for authenticated users
resource "aws_iam_role" "cognito_authenticated" {
  count = var.enable_cognito ? 1 : 0

  name = upper("${var.project_name}-${var.environment}-COGNITO-AUTHENTICATED-ROLE")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main[0].id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = {
    Name = upper("${var.project_name}-${var.environment}-COGNITO-AUTHENTICATED-ROLE")
  }
}

# Attach role to identity pool
resource "aws_cognito_identity_pool_roles_attachment" "main" {
  count = var.enable_cognito ? 1 : 0

  identity_pool_id = aws_cognito_identity_pool.main[0].id

  roles = {
    authenticated = aws_iam_role.cognito_authenticated[0].arn
  }
}
