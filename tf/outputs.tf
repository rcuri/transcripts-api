# ECR Repository
output "ecr_repository_url" {
  description = "ECR Repository URL"
  value       = data.aws_ecr_repository.transcripts_api.repository_url
}

# API Gateway
output "api_gateway_url" {
  description = "Base URL of the API Gateway"
  value       = aws_apigatewayv2_stage.dev.invoke_url
}

output "http_api_id" {
  description = "Id of the HTTP API"
  value = aws_apigatewayv2_api.http_api.id
}

output "http_api_base_url" {
  description = "URL of the HTTP API"
  value = join("", ["https://", aws_apigatewayv2_api.http_api.id, ".execute-api.", data.aws_region.current.name, ".", data.aws_partition.current.dns_suffix])
}

# API Endpoints
output "http_api_get_games_url" {
  description = "URL of the HTTP API get_games endpoint"
  value = join("", [aws_apigatewayv2_stage.dev.invoke_url, "games"])
}

output "http_api_get_play_by_play_url" {
  description = "URL of the HTTP API get_play_by_play endpoint"
  value = join("", [aws_apigatewayv2_stage.dev.invoke_url, "play_by_play/{game_id}"])
}

output "http_api_get_transcript_status_url" {
  description = "URL of the HTTP API get_transcript endpoint"
  value = join("", [aws_apigatewayv2_stage.dev.invoke_url, "transcripts/{transcript_id}"])
}

output "http_api_submit_transcript_request_url" {
  description = "URL of the HTTP API submit_transcript_request endpoint"
  value = join("", [aws_apigatewayv2_stage.dev.invoke_url, "transcripts"])
}

# SQS Queue
output "transcripts_sqs_fifo_queue_url" {
  description = "URL of the transcripts SQS FIFO Queue"
  value = aws_sqs_queue.transcripts_queue.url
}

# State Machine
output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = var.deploy_lambda_functions ? aws_sfn_state_machine.transcripts_sfn_state_machine[0].arn : null
}

# Lambda Functions
output "lambda_function_names" {
  description = "Names of all Lambda functions"
  value       = var.deploy_lambda_functions ? { for k, v in aws_lambda_function.functions : k => v.function_name } : {}
}

# RDS Database
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.transcripts_postgres.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.transcripts_postgres.port
}

output "rds_database_name" {
  description = "RDS PostgreSQL database name"
  value       = aws_db_instance.transcripts_postgres.db_name
}

output "rds_username" {
  description = "RDS PostgreSQL username"
  value       = aws_db_instance.transcripts_postgres.username
  sensitive   = true
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS credentials"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

# VPC and Networking
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.transcripts_vpc.id
}

output "lambda_security_group_id" {
  description = "ID of the Lambda security group"
  value       = aws_security_group.lambda_sg.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public_subnets[*].id
}

output "lambda_private_subnet_ids" {
  description = "IDs of the private subnets for Lambda functions"
  value       = aws_subnet.private_subnets_lambda[*].id
}

output "rds_private_subnet_ids" {
  description = "IDs of the private subnets for RDS"
  value       = aws_subnet.private_subnets[*].id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.nat_gw[*].id
}

# Bastion Host (Dev environment only)
output "bastion_public_ip" {
  description = "Public IP of the bastion host (dev environment only)"
  value       = var.environment == "dev" && length(aws_instance.bastion) > 0 ? aws_instance.bastion[0].public_ip : null
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion host"
  value       = var.environment == "dev" && length(aws_instance.bastion) > 0 ? "ssh -i ~/.ssh/transcripts-bastion ec2-user@${aws_instance.bastion[0].public_ip}" : null
}

output "bastion_instance_id" {
  description = "Instance ID of the bastion host (for stopping/starting)"
  value       = var.environment == "dev" && length(aws_instance.bastion) > 0 ? aws_instance.bastion[0].id : null
}
