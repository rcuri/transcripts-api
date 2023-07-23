output "serverless_deployment_bucket_name" {
  value = aws_s3_bucket.serverless_deployment_bucket.id
}

output "http_api_id" {
  description = "Id of the HTTP API"
  value = aws_apigatewayv2_api.http_api.id
}

output "http_api_base_url" {
  description = "URL of the HTTP API"
  value = join("", ["https://", aws_apigatewayv2_api.http_api.id, ".execute-api.", data.aws_region.current.name, ".", data.aws_partition.current.dns_suffix])
}

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

output "transcripts_sqs_fifo_queue_url" {
  description = "URL of the transcripts SQS FIFO Queue"
  value = aws_sqs_queue.transcripts_queue.url
}
