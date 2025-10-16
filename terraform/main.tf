# CloudFront Signed URLs Demo - Main Terraform Configuration

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Primary AWS Provider (for most resources)
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.tags
  }
}

# AWS Provider for us-east-1 (required for CloudFront ACM certificates)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  
  default_tags {
    tags = var.tags
  }
}

# Data Sources
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Route53 Hosted Zone (if custom domain enabled)
data "aws_route53_zone" "main" {
  count = var.custom_domain_enabled && var.domain_name != "" ? 1 : 0
  
  name         = var.domain_name
  private_zone = false
}

# Local Variables
locals {
  full_domain_name = var.custom_domain_enabled && var.domain_name != "" ? "${var.subdomain}.${var.domain_name}" : ""
  bucket_name      = "${var.project_name}-${data.aws_caller_identity.current.account_id}-${random_string.suffix.result}"
  table_name       = "${var.project_name}-files-metadata"
  function_name    = "${var.project_name}-api"
  
  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Generate CloudFront key pair
resource "tls_private_key" "cloudfront" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Extract public key in PEM format
locals {
  cloudfront_public_key_pem = tls_private_key.cloudfront.public_key_pem
  # Convert to PKCS#1 format (required by CloudFront)
  cloudfront_private_key_pem = tls_private_key.cloudfront.private_key_pem
}

