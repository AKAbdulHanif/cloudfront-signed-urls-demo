# AWS Secrets Manager for CloudFront Private Key

resource "aws_secretsmanager_secret" "cloudfront_private_key" {
  name        = "${var.project_name}-cloudfront-private-key"
  description = "CloudFront private key for signed URLs (PKCS#1 format)"
  
  recovery_window_in_days = 7
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-key"
    }
  )
}

resource "aws_secretsmanager_secret_version" "cloudfront_private_key" {
  secret_id     = aws_secretsmanager_secret.cloudfront_private_key.id
  secret_string = local.cloudfront_private_key_pem
}

