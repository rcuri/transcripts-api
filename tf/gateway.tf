resource "aws_apigatewayv2_api" "http_api" {
  name = "dev-transcriptai"
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = ["Content-Type","X-Amz-Date","Authorization","X-Api-Key","X-Amz-Security-Token","X-Amz-User-Agent","X-Amzn-Trace-Id"]
    allow_methods = ["OPTIONS","GET","POST"]
    allow_origins = ["*"]
  }
}

resource "aws_apigatewayv2_stage" "dev" {
  api_id = aws_apigatewayv2_api.http_api.id
  name = "$default"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.main_api_gw.arn
    format = "{\"requestTime\":\"$context.requestTime\",\"requestId\":\"$context.requestId\",\"apiId\":\"$context.apiId\",\"resourcePath\":\"$context.routeKey\",\"path\":\"$context.path\",\"httpMethod\":\"$context.httpMethod\",\"stage\":\"$context.stage\",\"status\":\"$context.status\",\"integrationStatus\":\"$context.integrationStatus\",\"integrationLatency\":\"$context.integrationLatency\",\"responseLatency\":\"$context.responseLatency\",\"responseLength\":\"$context.responseLength\",\"errorMessage\":\"$context.error.message\",\"format\":\"SLS_HTTP_API_LOG\",\"version\":\"1.0.0\"}"
  }
}

resource "aws_cloudwatch_log_group" "main_api_gw" {
  name = "/aws/api-gw/${aws_apigatewayv2_api.http_api.name}"

  retention_in_days = 14
}

// get_games
resource "aws_lambda_permission" "get_games_lambda_permission_http_api" {
  function_name = aws_lambda_function.get_games_lambda_function.arn
  action = "lambda:InvokeFunction"
  principal = "apigateway.amazonaws.com"
  source_arn = join("", ["arn:", data.aws_partition.current.partition, ":execute-api:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":", aws_apigatewayv2_api.http_api.id, "/*"])
}

resource "aws_apigatewayv2_integration" "http_api_integration_get_games" {
  api_id = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.get_games_lambda_function.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "http_api_route_get_games" {
  api_id = aws_apigatewayv2_api.http_api.id
  route_key = "GET /games"
  target = join("/", ["integrations", aws_apigatewayv2_integration.http_api_integration_get_games.id])
}


// get_play_by_play
resource "aws_lambda_permission" "get_play_by_play_lambda_permission_http_api" {
  function_name = aws_lambda_function.get_play_by_play_lambda_function.arn
  action = "lambda:InvokeFunction"
  principal = "apigateway.amazonaws.com"
  source_arn = join("", ["arn:", data.aws_partition.current.partition, ":execute-api:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":", aws_apigatewayv2_api.http_api.id, "/*"])
}

resource "aws_apigatewayv2_integration" "http_api_integration_get_play_by_play" {
  api_id = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.get_play_by_play_lambda_function.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "http_api_route_get_play_by_play" {
  api_id = aws_apigatewayv2_api.http_api.id
  route_key = "GET /play_by_play/{game_id}"
  target = join("/", ["integrations", aws_apigatewayv2_integration.http_api_integration_get_play_by_play.id])
}

// get_transcript_status
resource "aws_lambda_permission" "get_transcript_status_lambda_permission_http_api" {
  function_name = aws_lambda_function.get_transcript_status_lambda_function.arn
  action = "lambda:InvokeFunction"
  principal = "apigateway.amazonaws.com"
  source_arn = join("", ["arn:", data.aws_partition.current.partition, ":execute-api:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":", aws_apigatewayv2_api.http_api.id, "/*"])
}

resource "aws_apigatewayv2_integration" "http_api_integration_get_transcript_status" {
  api_id = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.get_transcript_status_lambda_function.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "http_api_route_get_transcript_status" {
  api_id = aws_apigatewayv2_api.http_api.id
  route_key = "GET /transcripts/{transcript_id}"
  target = join("/", ["integrations", aws_apigatewayv2_integration.http_api_integration_get_transcript_status.id])
}

// submit_transcript_request
resource "aws_lambda_permission" "submit_transcript_request_lambda_permission_http_api" {
  function_name = aws_lambda_function.submit_transcript_request_lambda_function.arn
  action = "lambda:InvokeFunction"
  principal = "apigateway.amazonaws.com"
  source_arn = join("", ["arn:", data.aws_partition.current.partition, ":execute-api:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":", aws_apigatewayv2_api.http_api.id, "/*"])
}

resource "aws_apigatewayv2_integration" "http_api_integration_submit_transcript_request" {
  api_id = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.submit_transcript_request_lambda_function.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "http_api_route_submit_transcript_request" {
  api_id = aws_apigatewayv2_api.http_api.id
  route_key = "POST /transcripts"
  target = join("/", ["integrations", aws_apigatewayv2_integration.http_api_integration_submit_transcript_request.id])
}



