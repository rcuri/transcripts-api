resource "aws_sfn_state_machine" "transcripts_sfn_state_machine" {
  count = var.deploy_lambda_functions ? 1 : 0
  
  name     = "${var.app_name}-${var.environment}-generate-transcripts"
  role_arn = aws_iam_role.transcripts_state_machine_role[0].arn

  definition = jsonencode({
    Comment = "Calls OpenAI's API to generate transcript"
    StartAt = "GenerateTranscript"
    States = {
      GenerateTranscript = {
        Type           = "Task"
        TimeoutSeconds = 3000
        Resource       = aws_lambda_function.functions["generate_transcript"].arn
        ResultPath     = "$.transcript_data"
        InputPath      = "$"
        Parameters = {
          "transcript_input.$" = "$"
          "execution_id.$"     = "$$.Execution.Id"
        }
        Next = "UpdateTranscriptStatus"
      }
      UpdateTranscriptStatus = {
        Type           = "Task"
        TimeoutSeconds = 300
        Resource       = aws_lambda_function.functions["update_generate_transcript_status"].arn
        ResultPath     = "$.transcript_data"
        InputPath      = "$"
        Parameters = {
          "transcript_input.$" = "$"
          "execution_id.$"     = "$$.Execution.Id"
        }
        End = true
      }
    }
  })

  tags = {
    Name        = "${var.app_name}-${var.environment}-state-machine"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role" "transcripts_state_machine_role" {
  count = var.deploy_lambda_functions ? 1 : 0
  
  name = "${var.app_name}-${var.environment}-state-machine-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-${var.environment}-state-machine-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "sfn_lambda_policy_document" {
  count = var.deploy_lambda_functions ? 1 : 0
  
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      aws_lambda_function.functions["generate_transcript"].arn,
      aws_lambda_function.functions["update_generate_transcript_status"].arn
    ]
  }
}

resource "aws_iam_policy" "sfn_lambda_policy" {
  count = var.deploy_lambda_functions ? 1 : 0
  
  name   = "${var.app_name}-${var.environment}-sfn-lambda-policy"
  policy = data.aws_iam_policy_document.sfn_lambda_policy_document[0].json

  tags = {
    Name        = "${var.app_name}-${var.environment}-sfn-lambda-policy"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "sfn_lambda_attach" {
  count = var.deploy_lambda_functions ? 1 : 0
  
  role       = aws_iam_role.transcripts_state_machine_role[0].name
  policy_arn = aws_iam_policy.sfn_lambda_policy[0].arn
}