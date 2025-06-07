provider "aws" {
  region = "us-west-1"
}

variable "lambda_root" {
  type        = string
  description = "The relative path to the source of the lambda"
  default     = "../functions"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

# S3 bucket for Terraform state storage
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "transcripts-api-terraform-state"
  force_destroy = true

  tags = {
    Name        = "Terraform State Storage"
    Environment = "Infrastructure"
  }
}

# Enable versioning for the state bucket
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for the state bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to the state bucket
resource "aws_s3_bucket_public_access_block" "terraform_state_pab" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_state_locks" {
  name           = "terraform-state-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Locks"
    Environment = "Infrastructure"
  }
}

terraform {
  required_version = ">= 1.0"
  
  # Temporarily commented out for initial bootstrap
  # backend "s3" {
  #   bucket         = "transcripts-api-terraform-state"
  #   key            = "terraform.tfstate"
  #   region         = "us-west-1"
  #   dynamodb_table = "terraform-state-locks"
  #   encrypt        = true
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}