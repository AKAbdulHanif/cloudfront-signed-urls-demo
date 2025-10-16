# Terraform Variables for CloudFront Signed URLs Demo

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "cloudfront-signedurl-demo"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

# Custom Domain Configuration
variable "custom_domain_enabled" {
  description = "Enable custom domain for CloudFront distribution"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Root domain name (must have Route53 hosted zone)"
  type        = string
  default     = ""
}

variable "subdomain" {
  description = "Subdomain for CloudFront distribution"
  type        = string
  default     = "cdn"
}

# CloudFront Signed URL Configuration
variable "upload_expiration" {
  description = "Upload URL expiration time in seconds"
  type        = number
  default     = 900 # 15 minutes
}

variable "download_expiration" {
  description = "Download URL expiration time in seconds"
  type        = number
  default     = 3600 # 1 hour
}

# Lambda Configuration
variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.11"
}

# DynamoDB Configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "dynamodb_ttl_enabled" {
  description = "Enable TTL for DynamoDB table"
  type        = bool
  default     = true
}

variable "dynamodb_ttl_attribute" {
  description = "TTL attribute name for DynamoDB"
  type        = string
  default     = "ttl"
}

# S3 Configuration
variable "s3_versioning_enabled" {
  description = "Enable versioning for S3 bucket"
  type        = bool
  default     = true
}

variable "s3_lifecycle_enabled" {
  description = "Enable lifecycle policies for S3 bucket"
  type        = bool
  default     = false
}

variable "s3_lifecycle_expiration_days" {
  description = "Number of days before objects expire"
  type        = number
  default     = 30
}

# CloudFront Configuration
variable "cloudfront_price_class" {
  description = "CloudFront distribution price class"
  type        = string
  default     = "PriceClass_100" # US, Canada, Europe
}

variable "cloudfront_min_ttl" {
  description = "Minimum TTL for CloudFront cache"
  type        = number
  default     = 0
}

variable "cloudfront_default_ttl" {
  description = "Default TTL for CloudFront cache"
  type        = number
  default     = 0
}

variable "cloudfront_max_ttl" {
  description = "Maximum TTL for CloudFront cache"
  type        = number
  default     = 0
}

# API Gateway Configuration
variable "api_gateway_stage_name" {
  description = "API Gateway deployment stage name"
  type        = string
  default     = "prod"
}

variable "api_gateway_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 5000
}

variable "api_gateway_throttle_rate_limit" {
  description = "API Gateway throttle rate limit"
  type        = number
  default     = 10000
}

# Security Configuration
variable "enable_waf" {
  description = "Enable AWS WAF for CloudFront distribution"
  type        = bool
  default     = false
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP ranges for API Gateway (empty = allow all)"
  type        = list(string)
  default     = []
}

# Monitoring Configuration
variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs for Lambda and API Gateway"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# Tags
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "CloudFront Signed URLs Demo"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}

# Advanced Configuration
variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB"
  type        = bool
  default     = false
}

variable "enable_s3_encryption" {
  description = "Enable server-side encryption for S3 bucket"
  type        = bool
  default     = true
}

variable "cloudfront_geo_restriction_type" {
  description = "CloudFront geo restriction type (none, whitelist, blacklist)"
  type        = string
  default     = "none"
}

variable "cloudfront_geo_restriction_locations" {
  description = "List of country codes for geo restriction"
  type        = list(string)
  default     = []
}

