# API Gateway REST API

# REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "API for ${var.project_name}"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  tags = local.common_tags
}

# API Gateway Resource: /api
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "api"
}

# API Gateway Resource: /api/files
resource "aws_api_gateway_resource" "files" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "files"
}

# API Gateway Resource: /api/files/{proxy+}
resource "aws_api_gateway_resource" "files_proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.files.id
  path_part   = "{proxy+}"
}

# API Gateway Method: ANY /api/files/{proxy+}
resource "aws_api_gateway_method" "files_proxy" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.files_proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

# API Gateway Integration: Lambda Proxy
resource "aws_api_gateway_integration" "files_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.files_proxy.id
  http_method             = aws_api_gateway_method.files_proxy.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.main.invoke_arn
}

# API Gateway Method: OPTIONS /api/files/{proxy+} (CORS)
resource "aws_api_gateway_method" "files_proxy_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.files_proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# API Gateway Integration: OPTIONS (CORS)
resource "aws_api_gateway_integration" "files_proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.files_proxy.id
  http_method = aws_api_gateway_method.files_proxy_options.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# API Gateway Method Response: OPTIONS
resource "aws_api_gateway_method_response" "files_proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.files_proxy.id
  http_method = aws_api_gateway_method.files_proxy_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  
  response_models = {
    "application/json" = "Empty"
  }
}

# API Gateway Integration Response: OPTIONS
resource "aws_api_gateway_integration_response" "files_proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.files_proxy.id
  http_method = aws_api_gateway_method.files_proxy_options.http_method
  status_code = aws_api_gateway_method_response.files_proxy_options.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  
  depends_on = [aws_api_gateway_integration.files_proxy_options]
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.files_proxy.id,
      aws_api_gateway_method.files_proxy.id,
      aws_api_gateway_integration.files_proxy.id,
      aws_api_gateway_method.files_proxy_options.id,
      aws_api_gateway_integration.files_proxy_options.id,
    ]))
  }
  
  lifecycle {
    create_before_destroy = true
  }
  
  depends_on = [
    aws_api_gateway_integration.files_proxy,
    aws_api_gateway_integration.files_proxy_options
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.api_gateway_stage_name
  
  # Throttling settings
  throttle_settings {
    burst_limit = var.api_gateway_throttle_burst_limit
    rate_limit  = var.api_gateway_throttle_rate_limit
  }
  
  tags = local.common_tags
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = var.log_retention_days
  
  tags = local.common_tags
}

# API Gateway Method Settings (for logging)
resource "aws_api_gateway_method_settings" "main" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"
  
  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

