# Keep the OpenAI API key secret (assuming this exists separately)
data "aws_secretsmanager_secret" "openai_api_key" {
 name = "openai_api_key"
}

data "aws_secretsmanager_secret_version" "openai_api_key" {
 secret_id = data.aws_secretsmanager_secret.openai_api_key.id
}

locals {
    openai_api_key = sensitive(
        data.aws_secretsmanager_secret_version.openai_api_key.secret_string
    )
}

# Variables for modernized container setup
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "app_name" {
  description = "Application name used for resource naming"
  type        = string
  default     = "transcripts-api"
}

variable "deploy_lambda_functions" {
  description = "Whether to deploy Lambda functions (set to false for initial ECR-only deployment)"
  type        = bool
  default     = true
}

variable "bastion_key_name" {
  description = "EC2 Key Pair name for bastion host access (required for dev environment if you want database access)"
  type        = string
  default     = null
}