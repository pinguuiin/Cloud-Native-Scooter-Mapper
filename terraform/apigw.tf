# HTTP API for the Lambda-backed service
resource "aws_apigatewayv2_api" "api" {
  name          = "${local.project}-http-api-${local.name_suffix}"
  protocol_type = "HTTP"
}

# Lambda proxy integration for the API
resource "aws_apigatewayv2_integration" "api" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY" # forwards all request details to Lambda
  integration_uri        = aws_lambda_function.api.arn
  payload_format_version = "2.0"
}

# Root route to the API Lambda
resource "aws_apigatewayv2_route" "api_root" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.api.id}"
}

# Catch-all proxy route to the API Lambda
resource "aws_apigatewayv2_route" "api_proxy" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.api.id}"
}

# Default stage with auto-deploy enabled
resource "aws_apigatewayv2_stage" "api" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true # automatically deploy on route/integration changes

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_access.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      requestTime        = "$context.requestTime"
      httpMethod         = "$context.httpMethod"
      routeKey           = "$context.routeKey"
      path               = "$context.path"
      status             = "$context.status"
      protocol           = "$context.protocol"
      responseLength     = "$context.responseLength"
      integrationStatus  = "$context.integration.status"
      integrationError   = "$context.integration.error"
      integrationLatency = "$context.integration.latency"
      responseLatency    = "$context.responseLatency"
    })
  }
}

# Allow API Gateway to invoke the API Lambda
resource "aws_lambda_permission" "api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
