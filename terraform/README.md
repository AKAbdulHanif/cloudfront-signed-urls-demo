# Terraform Infrastructure

This directory contains the Terraform configuration for deploying the CloudFront Signed URLs infrastructure.

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account with necessary permissions

## Quick Start

```bash
# 1. Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# 2. Edit terraform.tfvars with your values
vim terraform.tfvars

# 3. Initialize Terraform
terraform init

# 4. Preview changes
terraform plan

# 5. Deploy
terraform apply
```

## Configuration

### Required Variables

Edit `terraform.tfvars`:

```hcl
project_name = "cloudfront-signedurl-demo"
aws_region   = "us-east-1"
```

### Optional Variables

```hcl
# Custom domain (optional)
custom_domain_enabled = true
domain_name          = "example.com"
subdomain            = "cdn"

# Expiration times
upload_expiration   = 900   # 15 minutes
download_expiration = 3600  # 1 hour
```

## Resources Created

- CloudFront Distribution with custom domain
- CloudFront Public Key and Key Group
- Lambda Function for signed URL generation
- API Gateway REST API
- S3 Bucket for file storage
- DynamoDB Table for metadata
- Secrets Manager Secret for private key
- IAM Roles and Policies
- Route53 Records (if custom domain enabled)
- ACM Certificate (if custom domain enabled)

## Outputs

After deployment, Terraform will output:

- `api_gateway_url` - API Gateway endpoint URL
- `cloudfront_domain` - CloudFront custom domain
- `s3_bucket_name` - S3 bucket name
- `lambda_function_name` - Lambda function name

## Customization

### Change AWS Region

Edit `terraform.tfvars`:
```hcl
aws_region = "eu-west-1"
```

### Disable Custom Domain

Edit `terraform.tfvars`:
```hcl
custom_domain_enabled = false
```

### Change Expiration Times

Edit `terraform.tfvars`:
```hcl
upload_expiration   = 1800  # 30 minutes
download_expiration = 7200  # 2 hours
```

## State Management

### Local State (Default)

Terraform state is stored locally in `terraform.tfstate`.

**⚠️ Warning**: Do not commit `terraform.tfstate` to version control!

### Remote State (Recommended for Teams)

Configure S3 backend in `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "cloudfront-signed-urls/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

Then initialize:
```bash
terraform init -migrate-state
```

## Troubleshooting

### Error: Resource already exists

If resources already exist (e.g., from previous deployment):

```bash
# Import existing resource
terraform import aws_cloudfront_public_key.main K27M0SUQ8BJ2RL
```

### Error: Invalid credentials

Ensure AWS CLI is configured:
```bash
aws configure
aws sts get-caller-identity
```

### Error: Insufficient permissions

Ensure your AWS user/role has these permissions:
- CloudFront (full access)
- Lambda (full access)
- API Gateway (full access)
- S3 (full access)
- DynamoDB (full access)
- Secrets Manager (full access)
- IAM (role creation)
- Route53 (if using custom domain)
- ACM (if using custom domain)

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**⚠️ Warning**: This will delete all data in S3 and DynamoDB!

## Cost Estimation

Use Terraform Cloud or Infracost to estimate costs:

```bash
# Using Infracost
brew install infracost
infracost breakdown --path .
```

## Security

- Private key is stored in AWS Secrets Manager
- S3 bucket is private (no public access)
- CloudFront validates signed URLs
- IAM roles follow least privilege
- Encryption at rest enabled

## Support

For issues or questions, see the main [README](../README.md) or open an issue on GitHub.

