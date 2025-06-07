output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.transcripts_api.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.transcripts_api.arn
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.transcripts_api.name
} 