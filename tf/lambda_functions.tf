# Locals for common Lambda configuration
locals {
  lambda_image_uri = "${data.aws_ecr_repository.transcripts_api.repository_url}:${var.image_tag}"
  
  common_environment_vars = {
    STAGE                    = var.environment
    # RDS Database Information
    RDS_DB_NAME             = aws_db_instance.transcripts_postgres.db_name
    RDS_DB_PORT             = tostring(aws_db_instance.transcripts_postgres.port)
    RDS_DB_HOST             = split(":", aws_db_instance.transcripts_postgres.endpoint)[0]
    RDS_DB_USERNAME         = aws_db_instance.transcripts_postgres.username
    # Secrets Manager ARN for database credentials
    DB_SECRET_ARN           = aws_secretsmanager_secret.rds_credentials.arn
    # OpenAI API Key
    OPENAI_KEY              = local.openai_api_key
  }

  lambda_functions = {
    generate_transcript = {
      handler     = "functions.generate_transcript.handler.handler"
      timeout     = 120
      memory_size = 512
      environment_vars = {}
    }
    get_games = {
      handler     = "functions.get_games.handler.handler"
      timeout     = 6
      memory_size = 512
      environment_vars = {}
    }
    get_play_by_play = {
      handler     = "functions.get_play_by_play.handler.handler"
      timeout     = 6
      memory_size = 512
      environment_vars = {}
    }
    get_transcript_status = {
      handler     = "functions.get_transcript_status.handler.handler"
      timeout     = 6
      memory_size = 512
      environment_vars = {}
    }
    process_sqs_queue = {
      handler     = "functions.process_sqs_queue.handler.handler"
      timeout     = 6
      memory_size = 512
      environment_vars = {
      }
    }
    submit_transcript_request = {
      handler     = "functions.submit_transcript_request.handler.handler"
      timeout     = 6
      memory_size = 512
      environment_vars = {
        TRANSCRIPTS_SQS_URL = aws_sqs_queue.transcripts_queue.url
      }
    }
    update_generate_transcript_status = {
      handler     = "functions.update_generate_transcript_status.handler.handler"
      timeout     = 6
      memory_size = 512
      environment_vars = {}
    }
  }
}

# Lambda Functions
resource "aws_lambda_function" "functions" {
  for_each = var.deploy_lambda_functions ? local.lambda_functions : {}

  function_name = "${var.app_name}-${var.environment}-${replace(each.key, "_", "-")}"
  role         = aws_iam_role.lambda_execution_role[each.key].arn
  
  package_type = "Image"
  image_uri    = local.lambda_image_uri
  
  timeout     = each.value.timeout
  memory_size = each.value.memory_size
  
  image_config {
    command = [each.value.handler]
  }
  
  environment {
    variables = merge(local.common_environment_vars, each.value.environment_vars)
  }

  # VPC Configuration for database access
  vpc_config {
    subnet_ids         = aws_subnet.private_subnets_lambda[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_vpc_execution,
    aws_cloudwatch_log_group.lambda_logs,
  ]

  tags = {
    Name        = "${var.app_name}-${var.environment}-${each.key}"
    Environment = var.environment
    Function    = each.key
    ManagedBy   = "terraform"
  }
}

# Update process_sqs_queue function with state machine ARN
resource "aws_lambda_function" "process_sqs_queue_updated" {
  count = var.deploy_lambda_functions ? 1 : 0
  
  function_name = aws_lambda_function.functions["process_sqs_queue"].function_name
  role         = aws_lambda_function.functions["process_sqs_queue"].role
  
  package_type = "Image"
  image_uri    = local.lambda_image_uri
  
  timeout     = 6
  memory_size = 512
  
  image_config {
    command = ["functions.process_sqs_queue.handler.handler"]
  }
  
  environment {
    variables = merge(local.common_environment_vars, {
      TRANSCRIPTS_STATE_MACHINE = aws_sfn_state_machine.transcripts_sfn_state_machine[0].arn
    })
  }

  vpc_config {
    subnet_ids         = aws_subnet.private_subnets_lambda[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  depends_on = [
    aws_lambda_function.functions,
  ]

  tags = {
    Name        = "${var.app_name}-${var.environment}-process-sqs-queue"
    Environment = var.environment
    Function    = "process_sqs_queue"
    ManagedBy   = "terraform"
  }
}

# IAM Roles for Lambda Functions
resource "aws_iam_role" "lambda_execution_role" {
  for_each = var.deploy_lambda_functions ? local.lambda_functions : {}

  name = "${var.app_name}-${var.environment}-${replace(each.key, "_", "-")}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-${var.environment}-${each.key}-role"
    Environment = var.environment
    Function    = each.key
    ManagedBy   = "terraform"
  }
}

# Basic execution policy attachment
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  for_each = var.deploy_lambda_functions ? local.lambda_functions : {}

  role       = aws_iam_role.lambda_execution_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC execution policy attachment for Lambda functions in VPC
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  for_each = var.deploy_lambda_functions ? local.lambda_functions : {}

  role       = aws_iam_role.lambda_execution_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# IAM policy for Secrets Manager access
resource "aws_iam_policy" "lambda_secrets_manager_policy" {
  count = var.deploy_lambda_functions ? 1 : 0
  
  name = "${var.app_name}-${var.environment}-lambda-secrets-manager-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.rds_credentials.arn,
          data.aws_secretsmanager_secret.openai_api_key.arn
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-${var.environment}-lambda-secrets-manager-policy"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Attach Secrets Manager policy to all Lambda roles
resource "aws_iam_role_policy_attachment" "lambda_secrets_manager" {
  for_each = var.deploy_lambda_functions ? local.lambda_functions : {}

  role       = aws_iam_role.lambda_execution_role[each.key].name
  policy_arn = aws_iam_policy.lambda_secrets_manager_policy[0].arn
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = var.deploy_lambda_functions ? local.lambda_functions : {}

  name              = "/aws/lambda/${var.app_name}-${var.environment}-${replace(each.key, "_", "-")}"
  retention_in_days = 14

  tags = {
    Name        = "${var.app_name}-${var.environment}-${each.key}-logs"
    Environment = var.environment
    Function    = each.key
    ManagedBy   = "terraform"
  }
}

# Additional IAM policies for specific functions
resource "aws_iam_role_policy_attachment" "submit_transcript_request_sfn" {
  count = var.deploy_lambda_functions ? 1 : 0
  
  role       = aws_iam_role.lambda_execution_role["submit_transcript_request"].name
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"
}

resource "aws_iam_role_policy_attachment" "submit_transcript_request_sqs" {
  count = var.deploy_lambda_functions ? 1 : 0
  
  role       = aws_iam_role.lambda_execution_role["submit_transcript_request"].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_role_policy_attachment" "process_sqs_queue_sfn" {
  count = var.deploy_lambda_functions ? 1 : 0
  
  role       = aws_iam_role.lambda_execution_role["process_sqs_queue"].name
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"
}

# Custom policy for SQS processing
resource "aws_iam_policy" "process_sqs_lambda_policy" {
  count = var.deploy_lambda_functions ? 1 : 0
  
  name = "${var.app_name}-${var.environment}-process-sqs-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.transcripts_queue.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "process_sqs_queue_policy" {
  count = var.deploy_lambda_functions ? 1 : 0
  
  role       = aws_iam_role.lambda_execution_role["process_sqs_queue"].name
  policy_arn = aws_iam_policy.process_sqs_lambda_policy[0].arn
}

# Event source mapping to trigger Lambda function from SQS queue
resource "aws_lambda_event_source_mapping" "process_sqs_queue_trigger" {
  count = var.deploy_lambda_functions ? 1 : 0
  
  event_source_arn = aws_sqs_queue.transcripts_queue.arn
  function_name    = aws_lambda_function.process_sqs_queue_updated[0].function_name
  batch_size       = 10
  
  depends_on = [
    aws_lambda_function.process_sqs_queue_updated,
    aws_iam_role_policy_attachment.process_sqs_queue_policy
  ]

  tags = {
    Name        = "${var.app_name}-${var.environment}-process-sqs-trigger"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}