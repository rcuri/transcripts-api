resource "null_resource" "install_dependencies_get_games" {
  provisioner "local-exec" {
    command = "pip install -r ${var.lambda_root}/get_games/requirements.txt -t ${var.lambda_root}/get_games"
  }
  triggers  =  {
    dependencies_versions = filemd5("${var.lambda_root}/get_games/requirements.txt")
    handler_versions = filemd5("${var.lambda_root}/get_games/handler.py")    
    index_versions = filemd5("${var.lambda_root}/get_games/index.py")    
  }
}

data "archive_file" "lambda_get_games" {
  type = "zip"
  depends_on = [null_resource.install_dependencies_get_games]
  excludes   = [
    "__pycache__",
    "venv",
  ]
  source_dir  = "${var.lambda_root}/get_games"
  output_path = "${var.lambda_root}/get_games.zip"
}

resource "aws_s3_object" "lambda_get_games" {
  bucket = aws_s3_bucket.serverless_deployment_bucket.id

  key    = "get_games.zip"
  source = data.archive_file.lambda_get_games.output_path

  etag = data.archive_file.lambda_get_games.output_md5
}

resource "aws_lambda_function" "get_games_lambda_function" {
  function_name = "transcriptai-dev-getGames"
  memory_size = 512
  timeout = 6
  image_uri = "571830630900.dkr.ecr.us-east-1.amazonaws.com/drigo/transcripts:latest"
  package_type = "Image"
  image_config {
    command = ["handlers.get_games_handler"]
  }

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
    }
  }
  role = aws_iam_role.get_games_lambda_function_role.arn
}

resource "aws_iam_role_policy_attachment" "get_games_lambda_policy" {
  role       = aws_iam_role.get_games_lambda_function_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "get_games_lambda_function_role" {
  name = "get_games_lambda_function_role"
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

resource "aws_cloudwatch_log_group" "get_games" {
  name = "/aws/lambda/${aws_lambda_function.get_games_lambda_function.function_name}"

  retention_in_days = 14
}