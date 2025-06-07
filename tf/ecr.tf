# Reference the existing ECR repository created by bootstrap
data "aws_ecr_repository" "transcripts_api" {
  name = "transcripts-api"
}

# Note: Lifecycle policy and repository policy are managed in bootstrap configuration
# If you need to modify these policies, update them in tf/bootstrap/main.tf