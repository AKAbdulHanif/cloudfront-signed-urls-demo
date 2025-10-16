# Terraform Outputs for CloudFront Signed URLs Demo

# API Gateway Outputs
output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = aws_api_gateway_deployment.main.invoke_url
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_stage" {
  description = "API Gateway deployment stage"
  value       = var.api_gateway_stage_name
}

# CloudFront Outputs
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = var.custom_domain_enabled && var.domain_name != "" ? "${var.subdomain}.${var.domain_name}" : aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.main.arn
}

output "cloudfront_public_key_id" {
  description = "CloudFront public key ID"
  value       = aws_cloudfront_public_key.main.id
}

output "cloudfront_key_group_id" {
  description = "CloudFront key group ID"
  value       = aws_cloudfront_key_group.main.id
}

# S3 Outputs
output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.main.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.main.arn
}

output "s3_bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

# DynamoDB Outputs
output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.main.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.main.arn
}

# Lambda Outputs
output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.main.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.main.arn
}

output "lambda_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda_role.arn
}

# Secrets Manager Outputs
output "private_key_secret_arn" {
  description = "Secrets Manager secret ARN for private key"
  value       = aws_secretsmanager_secret.cloudfront_private_key.arn
  sensitive   = true
}

# Route53 Outputs (if custom domain enabled)
output "route53_nameservers" {
  description = "Route53 hosted zone nameservers"
  value       = var.custom_domain_enabled && var.domain_name != "" ? data.aws_route53_zone.main[0].name_servers : []
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = var.custom_domain_enabled && var.domain_name != "" ? data.aws_route53_zone.main[0].zone_id : ""
}

# ACM Certificate Outputs (if custom domain enabled)
output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = var.custom_domain_enabled && var.domain_name != "" ? aws_acm_certificate.main[0].arn : ""
}

# Complete API Endpoint Examples
output "api_endpoints" {
  description = "Complete API endpoint URLs"
  value = {
    upload   = "${aws_api_gateway_deployment.main.invoke_url}/api/files/upload"
    list     = "${aws_api_gateway_deployment.main.invoke_url}/api/files"
    download = "${aws_api_gateway_deployment.main.invoke_url}/api/files/download/{fileId}"
    delete   = "${aws_api_gateway_deployment.main.invoke_url}/api/files/{fileId}"
    config   = "${aws_api_gateway_deployment.main.invoke_url}/api/config"
  }
}

# Testing Commands
output "test_commands" {
  description = "Example commands to test the API"
  value = <<-EOT
    # Generate upload URL
    curl -X POST "${aws_api_gateway_deployment.main.invoke_url}/api/files/upload" \
      -H "Content-Type: application/json" \
      -d '{"filename":"test.txt","contentType":"text/plain"}' | jq '.'
    
    # List files
    curl "${aws_api_gateway_deployment.main.invoke_url}/api/files" | jq '.'
    
    # Get configuration
    curl "${aws_api_gateway_deployment.main.invoke_url}/api/config" | jq '.'
  EOT
}

# Deployment Summary
output "deployment_summary" {
  description = "Deployment summary"
  value = {
    project_name      = var.project_name
    environment       = var.environment
    region            = var.aws_region
    custom_domain     = var.custom_domain_enabled && var.domain_name != "" ? "${var.subdomain}.${var.domain_name}" : "Disabled"
    api_gateway_url   = aws_api_gateway_deployment.main.invoke_url
    cloudfront_domain = var.custom_domain_enabled && var.domain_name != "" ? "${var.subdomain}.${var.domain_name}" : aws_cloudfront_distribution.main.domain_name
  }
}

