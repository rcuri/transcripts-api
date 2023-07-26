
resource "aws_iam_policy" "process_sqs_lambda_policy" {
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Effect": "Allow",
      "Resource": "${aws_sqs_queue.transcripts_queue.arn}"
    }
  ]
}
EOF
}

# Lambda function role
resource "aws_iam_role" "process_sqs_queue_lambda_function_role" {
    name = "process_sqs_queue_lambda_function_role"
    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
        Effect = "Allow"
        Principal = {
            Service = [
            "lambda.amazonaws.com"
            ]
        }
        Action = [
            "sts:AssumeRole"
        ]
        }
    ]
    })
}
# Role to Policy attachment
resource "aws_iam_role_policy_attachment" "process_sqs_lambda_iam_policy_basic_execution" {
    role = aws_iam_role.process_sqs_queue_lambda_function_role.id
    policy_arn = aws_iam_policy.process_sqs_lambda_policy.arn
}

resource "null_resource" "install_dependencies_process_sqs_queue" {
  provisioner "local-exec" {
    command = "pip install -r ${var.lambda_root}/process_sqs_queue/requirements.txt -t ${var.lambda_root}/process_sqs_queue"
  }
  triggers  =  {
    dependencies_versions = filemd5("${var.lambda_root}/process_sqs_queue/requirements.txt")
    index_versions = filemd5("${var.lambda_root}/process_sqs_queue/index.py")    
  }
}

data "archive_file" "lambda_process_sqs_queue" {
  type = "zip"
  depends_on = [null_resource.install_dependencies_process_sqs_queue]
  excludes   = [
    "__pycache__",
    "venv",
  ]
  source_dir  = "${var.lambda_root}/process_sqs_queue"
  output_path = "${var.lambda_root}/process_sqs_queue.zip"
}

resource "aws_s3_object" "lambda_process_sqs_queue" {
  bucket = aws_s3_bucket.serverless_deployment_bucket.id

  key    = "process_sqs_queue.zip"
  source = data.archive_file.lambda_process_sqs_queue.output_path

  etag = data.archive_file.lambda_process_sqs_queue.output_md5
}


resource "aws_lambda_function" "process_sqs_queue_lambda_function" {
  handler = "index.process_sqs_queue"
  runtime = "python3.8"
  function_name = "transcriptai-dev-process_sqs_queue"
  memory_size = 512
  timeout = 6

  s3_bucket = aws_s3_bucket.serverless_deployment_bucket.id
  s3_key    = aws_s3_object.lambda_process_sqs_queue.key

  source_code_hash = data.archive_file.lambda_process_sqs_queue.output_base64sha256
  layers = [
    "arn:aws:lambda:us-east-1:571830630900:layer:psycopg2-layer:1"
  ]
  environment {
    variables = {
      STAGE = "prod"
      POSTGRES_DEV_PASSWORD = local.db_dev_credentials.password
      POSTGRES_DEV_DB = local.db_dev_credentials.db
      POSTGRES_DEV_HOST = local.db_dev_credentials.host
      POSTGRES_DEV_USERNAME = local.db_dev_credentials.username
      POSTGRES_DEV_PORT = local.db_dev_credentials.port    
      POSTGRES_PROD_PASSWORD = local.db_prod_credentials.password
      POSTGRES_PROD_DB = local.db_prod_credentials.db
      POSTGRES_PROD_HOST = local.db_prod_credentials.host
      POSTGRES_PROD_USERNAME = local.db_prod_credentials.username
      POSTGRES_PROD_PORT = local.db_prod_credentials.port
      TRANSCRIPTS_STATE_MACHINE = aws_sfn_state_machine.transcripts_sfn_state_machine.arn      
    }
  }
  role = aws_iam_role.process_sqs_queue_lambda_function_role.arn
}

# Event source from SQS
resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn = aws_sqs_queue.transcripts_queue.arn
  enabled          = true
  function_name    = aws_lambda_function.process_sqs_queue_lambda_function.arn
  batch_size       = 1
}

resource "aws_cloudwatch_log_group" "process_sqs_queue" {
  name = "/aws/lambda/${aws_lambda_function.process_sqs_queue_lambda_function.function_name}"

  retention_in_days = 14
}

resource "aws_iam_role_policy_attachment" "process_sqs_queue_lambda_policy" {
  role       = aws_iam_role.process_sqs_queue_lambda_function_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "execute_sfn_from_sqs_lambda_policy" {
  role       = aws_iam_role.process_sqs_queue_lambda_function_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"
}
