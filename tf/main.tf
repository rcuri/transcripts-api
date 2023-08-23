provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

variable "lambda_root" {
  type        = string
  description = "The relative path to the source of the lambda"
  default     = "../functions"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

resource "aws_s3_bucket" "serverless_deployment_bucket" {
  bucket_prefix = "serverless-deployment-bucket-tf"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "serverless_deployment_bucket_sse" {
  bucket = aws_s3_bucket.serverless_deployment_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

resource "aws_lambda_layer_version" "openai_3_8_layer" {
  filename   = "../layers/openai-aws-lambda-layer-3.8.zip"
  layer_name = "openai-3_8"

  compatible_runtimes = ["python3.8"]
}