# Key Rotation Infrastructure for CloudFront Signed URLs
# This file manages the dual-key architecture for zero-downtime key rotation

# Generate Active Key Pair
resource "tls_private_key" "active" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate Inactive Key Pair (for rotation)
resource "tls_private_key" "inactive" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# CloudFront Public Key - Active
resource "aws_cloudfront_public_key" "active" {
  name        = "${var.project_name}-active-key"
  encoded_key = tls_private_key.active.public_key_pem
  comment     = "Active public key for CloudFront signed URLs"
}

# CloudFront Public Key - Inactive (staged for rotation)
resource "aws_cloudfront_public_key" "inactive" {
  name        = "${var.project_name}-inactive-key"
  encoded_key = tls_private_key.inactive.public_key_pem
  comment     = "Inactive public key for CloudFront signed URLs (staged for rotation)"
}

# CloudFront Key Group - Active
resource "aws_cloudfront_key_group" "active" {
  name    = "${var.project_name}-active-key-group"
  comment = "Active key group for CloudFront signed URLs"
  items   = [aws_cloudfront_public_key.active.id]
}

# CloudFront Key Group - Inactive
resource "aws_cloudfront_key_group" "inactive" {
  name    = "${var.project_name}-inactive-key-group"
  comment = "Inactive key group for CloudFront signed URLs (staged for rotation)"
  items   = [aws_cloudfront_public_key.inactive.id]
}

# Secrets Manager Secret - Active Private Key
resource "aws_secretsmanager_secret" "active_private_key" {
  name                    = "${var.project_name}-active-private-key"
  description             = "Active private key for CloudFront signed URLs"
  recovery_window_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name     = "${var.project_name}-active-private-key"
      KeyType  = "Active"
      Rotation = "Enabled"
    }
  )
}

resource "aws_secretsmanager_secret_version" "active_private_key" {
  secret_id     = aws_secretsmanager_secret.active_private_key.id
  secret_string = tls_private_key.active.private_key_pem
}

# Secrets Manager Secret - Inactive Private Key
resource "aws_secretsmanager_secret" "inactive_private_key" {
  name                    = "${var.project_name}-inactive-private-key"
  description             = "Inactive private key for CloudFront signed URLs (staged for rotation)"
  recovery_window_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name     = "${var.project_name}-inactive-private-key"
      KeyType  = "Inactive"
      Rotation = "Enabled"
    }
  )
}

resource "aws_secretsmanager_secret_version" "inactive_private_key" {
  secret_id     = aws_secretsmanager_secret.inactive_private_key.id
  secret_string = tls_private_key.inactive.private_key_pem
}

# SSM Parameter - Active Key Pair ID
resource "aws_ssm_parameter" "active_key_id" {
  name        = "/cloudfront-signer/active-key-id"
  description = "CloudFront active public key ID"
  type        = "String"
  value       = aws_cloudfront_public_key.active.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-active-key-id"
    }
  )
}

# SSM Parameter - Active Secret ARN
resource "aws_ssm_parameter" "active_secret_arn" {
  name        = "/cloudfront-signer/active-secret-arn"
  description = "ARN of the Secrets Manager secret containing the active private key"
  type        = "String"
  value       = aws_secretsmanager_secret.active_private_key.arn

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-active-secret-arn"
    }
  )
}

# SSM Parameter - Inactive Key Pair ID (for rotation scripts)
resource "aws_ssm_parameter" "inactive_key_id" {
  name        = "/cloudfront-signer/inactive-key-id"
  description = "CloudFront inactive public key ID (staged for rotation)"
  type        = "String"
  value       = aws_cloudfront_public_key.inactive.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-inactive-key-id"
    }
  )
}

# SSM Parameter - Inactive Secret ARN (for rotation scripts)
resource "aws_ssm_parameter" "inactive_secret_arn" {
  name        = "/cloudfront-signer/inactive-secret-arn"
  description = "ARN of the Secrets Manager secret containing the inactive private key"
  type        = "String"
  value       = aws_secretsmanager_secret.inactive_private_key.arn

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-inactive-secret-arn"
    }
  )
}

# SSM Parameter - Last Rotation Timestamp
resource "aws_ssm_parameter" "last_rotation" {
  name        = "/cloudfront-signer/last-rotation"
  description = "Timestamp of the last key rotation"
  type        = "String"
  value       = timestamp()

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-last-rotation"
    }
  )

  lifecycle {
    ignore_changes = [value]
  }
}

# Outputs for key rotation
output "active_key_pair_id" {
  description = "CloudFront active public key ID"
  value       = aws_cloudfront_public_key.active.id
}

output "inactive_key_pair_id" {
  description = "CloudFront inactive public key ID"
  value       = aws_cloudfront_public_key.inactive.id
}

output "active_key_group_id" {
  description = "CloudFront active key group ID"
  value       = aws_cloudfront_key_group.active.id
}

output "inactive_key_group_id" {
  description = "CloudFront inactive key group ID"
  value       = aws_cloudfront_key_group.inactive.id
}

output "active_secret_arn" {
  description = "ARN of the active private key secret"
  value       = aws_secretsmanager_secret.active_private_key.arn
  sensitive   = true
}

output "inactive_secret_arn" {
  description = "ARN of the inactive private key secret"
  value       = aws_secretsmanager_secret.inactive_private_key.arn
  sensitive   = true
}

