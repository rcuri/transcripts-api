resource "aws_apigatewayv2_api" "http_api" {
  name = "${var.environment}-transcriptai"
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = ["Content-Type","X-Amz-Date","Authorization","X-Api-Key","X-Amz-Security-Token","X-Amz-User-Agent","X-Amzn-Trace-Id"]
    allow_methods = ["OPTIONS","GET","POST"]
    allow_origins = ["*"]
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-api"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_apigatewayv2_stage" "dev" {
  api_id = aws_apigatewayv2_api.http_api.id
  name = "$default"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.main_api_gw.arn
    format = jsonencode({
      requestTime        = "$context.requestTime"
      requestId          = "$context.requestId"
      apiId              = "$context.apiId"
      resourcePath       = "$context.routeKey"
      path               = "$context.path"
      httpMethod         = "$context.httpMethod"
      stage              = "$context.stage"
      status             = "$context.status"
      integrationStatus  = "$context.integrationStatus"
      integrationLatency = "$context.integrationLatency"
      responseLatency    = "$context.responseLatency"
      responseLength     = "$context.responseLength"
      errorMessage       = "$context.error.message"
      format             = "SLS_HTTP_API_LOG"
      version            = "1.0.0"
    })
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-api-stage"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "main_api_gw" {
  name = "/aws/api-gw/${aws_apigatewayv2_api.http_api.name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.app_name}-${var.environment}-api-logs"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "api_gateway_lambda_permission" {
  for_each = var.deploy_lambda_functions ? {
    get_games                     = "get-games"
    get_play_by_play             = "get-play-by-play" 
    get_transcript_status        = "get-transcript-status"
    submit_transcript_request    = "submit-transcript-request"
  } : {}

  function_name = aws_lambda_function.functions[each.key].arn
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# API Gateway integrations
resource "aws_apigatewayv2_integration" "lambda_integrations" {
  for_each = var.deploy_lambda_functions ? {
    get_games                     = "get-games"
    get_play_by_play             = "get-play-by-play" 
    get_transcript_status        = "get-transcript-status"
    submit_transcript_request    = "submit-transcript-request"
  } : {}

  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.functions[each.key].invoke_arn
  payload_format_version = "2.0"
}

# API Gateway routes
resource "aws_apigatewayv2_route" "api_routes" {
  for_each = var.deploy_lambda_functions ? {
    get_games                     = "GET /games"
    get_play_by_play             = "GET /play_by_play/{game_id}"
    get_transcript_status        = "GET /transcripts/{transcript_id}"
    submit_transcript_request    = "POST /transcripts"
  } : {}

  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integrations[each.key].id}"
}



