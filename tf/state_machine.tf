resource "aws_sfn_state_machine" "transcripts_sfn_state_machine" {
  name     = "generate-transcripts-state-machine"
  role_arn = aws_iam_role.transcripts_state_machine_role.arn

  definition = <<EOF
{
     "Comment": "Calls OpenAI's API to generate transcript",
     "StartAt": "GenerateTranscript",
     "States": {
       "GenerateTranscript": {
         "Type": "Task",
         "TimeoutSeconds": 3000,
         "Resource": "${aws_lambda_function.generate_transcript_lambda_function.arn}",
         "ResultPath": "$.transcript_data",
         "InputPath": "$",
         "Parameters": {
           "transcript_input.$": "$",
           "execution_id.$": "$$.Execution.Id"
         },
         "Next": "UpdateTranscriptStatus"
       },
       "UpdateTranscriptStatus": {
         "Type": "Task",
         "TimeoutSeconds": 300,
         "Resource": "${aws_lambda_function.update_generate_transcript_status_lambda_function.arn}",
         "ResultPath": "$.transcript_data",
         "InputPath": "$",
         "Parameters": {
           "transcript_input.$": "$",
           "execution_id.$": "$$.Execution.Id"
         },
         "End": true
       }
    }
}
EOF
}

resource "aws_iam_role" "transcripts_state_machine_role" {
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
    "sc:service:name": "transcriptai-api"
    }
  name = "transcripts-state-machine-role"
}

data "aws_iam_policy_document" "sfn_lambda_policy_document" {
  statement {
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "sfn_lambda_policy" {
  name        = "sfn-lambda_invoke-policy"
  policy      = data.aws_iam_policy_document.sfn_lambda_policy_document.json
}

resource "aws_iam_role_policy_attachment" "sfn_lambda_attach" {
  role       = aws_iam_role.transcripts_state_machine_role.name
  policy_arn = aws_iam_policy.sfn_lambda_policy.arn
}