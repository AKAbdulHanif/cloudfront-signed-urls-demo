# Lambda Function for Generating CloudFront Signed URLs

# Lambda Function
resource "aws_lambda_function" "main" {
  filename         = "${path.module}/../lambda/lambda.zip"
  function_name    = local.function_name
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.lambda_handler"
  source_code_hash = fileexists("${path.module}/../lambda/lambda.zip") ? filebase64sha256("${path.module}/../lambda/lambda.zip") : null
  runtime         = var.lambda_runtime
  memory_size     = var.lambda_memory_size
  timeout         = var.lambda_timeout
  
  environment {
    variables = {
      BUCKET_NAME              = aws_s3_bucket.main.id
      TABLE_NAME               = aws_dynamodb_table.main.name
      CLOUDFRONT_DOMAIN        = var.custom_domain_enabled && var.domain_name != "" ? local.full_domain_name : aws_cloudfront_distribution.main.domain_name
      CLOUDFRONT_KEY_PAIR_ID   = aws_cloudfront_public_key.main.id
      PRIVATE_KEY_SECRET_ARN   = aws_secretsmanager_secret.cloudfront_private_key.arn
      UPLOAD_EXPIRATION        = tostring(var.upload_expiration)
      DOWNLOAD_EXPIRATION      = tostring(var.download_expiration)
    }
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-function"
    }
  )
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.lambda_policy
  ]
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
  
  tags = local.common_tags
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

