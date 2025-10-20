# CloudFront Signed URLs - Complete Deployment Guide

**Author:** Platform Engineering Team  
**Last Updated:** October 19, 2025  
**Version:** 2.0 (Java Lambda + Key Rotation)

---

## Overview

This guide provides complete step-by-step instructions for deploying the CloudFront Signed URLs solution with Java Lambda and zero-downtime key rotation. It covers both fresh deployments and migrations from the Python-based version.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Infrastructure Components](#2-infrastructure-components)
3. [Fresh Deployment](#3-fresh-deployment)
4. [Migration from Python Lambda](#4-migration-from-python-lambda)
5. [Verification and Testing](#5-verification-and-testing)
6. [First Key Rotation](#6-first-key-rotation)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Prerequisites

### 1.1. Required Tools

- **Terraform:** Version 1.0 or higher
- **AWS CLI:** Version 2.x configured with appropriate credentials
- **Java:** JDK 11 or higher
- **Maven:** Version 3.6 or higher
- **Git:** For cloning the repository

### 1.2. AWS Permissions

Your AWS credentials must have permissions to create and manage:

- S3 buckets and bucket policies
- CloudFront distributions, public keys, and key groups
- Lambda functions and execution roles
- DynamoDB tables
- API Gateway REST APIs
- Secrets Manager secrets
- SSM Parameter Store parameters
- IAM roles and policies
- Route53 records (if using custom domain)
- ACM certificates (if using custom domain)

### 1.3. Domain Requirements (Optional)

If using a custom domain:
- Domain registered and managed in Route53 (or ability to create CNAME records)
- ACM certificate in **us-east-1** region for CloudFront

---

## 2. Infrastructure Components

### 2.1. Core Resources

The solution deploys the following AWS resources:

#### S3 Bucket
- **Purpose:** Private storage for uploaded files
- **Configuration:** 
  - Block all public access
  - Server-side encryption (AES-256)
  - Versioning enabled
  - Lifecycle rules for cleanup
- **Access:** Only via CloudFront with Origin Access Control (OAC)

#### CloudFront Distribution
- **Purpose:** Content delivery with signed URL validation
- **Configuration:**
  - Two cache behaviors (uploads and downloads)
  - Trusts both active and inactive key groups
  - Origin Access Control for S3
  - Custom domain support (optional)
  - HTTPS only (redirect HTTP to HTTPS)

#### DynamoDB Table
- **Purpose:** File metadata storage
- **Schema:**
  - Partition Key: `fileId` (String)
  - Attributes: `filename`, `s3Key`, `contentType`, `uploadedAt`
- **Configuration:**
  - On-demand billing mode
  - Point-in-time recovery enabled

#### Lambda Function (Java 11)
- **Purpose:** Generate signed URLs for uploads and downloads
- **Runtime:** Java 11
- **Memory:** 512 MB
- **Timeout:** 30 seconds
- **Handler:** `com.example.CloudFrontSignerHandler::handleRequest`

#### API Gateway
- **Purpose:** HTTP API for Lambda invocation
- **Endpoints:**
  - `POST /api/files/upload` - Generate upload URL
  - `GET /api/files/download/{fileId}` - Generate download URL
  - `GET /api/files` - List files

### 2.2. Key Rotation Resources

#### CloudFront Public Keys (2)
- **Active Key:** Currently used for signing new URLs
- **Inactive Key:** Staged for next rotation

#### CloudFront Key Groups (2)
- **Active Key Group:** Contains active public key
- **Inactive Key Group:** Contains inactive public key
- **Distribution Trust:** CloudFront trusts BOTH groups

#### Secrets Manager Secrets (2)
- **Active Private Key:** Secret for current signing operations
- **Inactive Private Key:** Secret for staged key
- **Configuration:**
  - 7-day recovery window
  - Automatic rotation disabled (manual rotation via script)

#### SSM Parameters (5)
- `/cloudfront-signer/active-key-id` - Active CloudFront public key ID
- `/cloudfront-signer/active-secret-arn` - Active private key secret ARN
- `/cloudfront-signer/inactive-key-id` - Inactive CloudFront public key ID
- `/cloudfront-signer/inactive-secret-arn` - Inactive private key secret ARN
- `/cloudfront-signer/last-rotation` - Timestamp of last rotation

#### IAM Roles and Policies
- **Lambda Execution Role:** Permissions for Lambda to access AWS services
- **Permissions:**
  - DynamoDB: Read/Write on metadata table
  - Secrets Manager: Read both active and inactive secrets
  - SSM Parameter Store: Read key configuration parameters
  - CloudWatch Logs: Write logs
  - S3: Read/Write objects (for metadata, not direct access)

---

## 3. Fresh Deployment

Follow these steps for a new deployment from scratch.

### Step 1: Clone the Repository

```bash
git clone https://github.com/AKAbdulHanif/cloudfront-signed-urls-demo.git
cd cloudfront-signed-urls-demo
```

### Step 2: Build the Java Lambda

```bash
cd lambda-java
./build.sh
```

**Expected Output:**
```
Building CloudFront Signer Lambda (Java)...
Cleaning previous builds...
Building project with Maven...
✅ Build successful!
Lambda JAR location: target/cloudfront-signer-lambda-1.0.0.jar
File size: 18M
```

**Verify the JAR exists:**
```bash
ls -lh target/cloudfront-signer-lambda-1.0.0.jar
```

### Step 3: Configure Terraform Variables

Navigate to the Terraform directory:
```bash
cd ../terraform
```

Create a `terraform.tfvars` file:

```hcl
# Project Configuration
project_name = "cloudfront-signed-urls-demo"
aws_region   = "eu-west-2"  # Change to your preferred region

# Custom Domain (Optional - set to false if not using)
custom_domain_enabled = false
domain_name          = ""  # e.g., "pe-labs.com"
subdomain            = ""  # e.g., "cdn-demo"

# Lambda Configuration
lambda_memory_size = 512
lambda_timeout     = 30

# URL Expiration (in seconds)
upload_expiration   = 900   # 15 minutes
download_expiration = 3600  # 1 hour

# CloudFront Cache Settings
cloudfront_min_ttl     = 0
cloudfront_default_ttl = 0
cloudfront_max_ttl     = 0

# DynamoDB Configuration
dynamodb_billing_mode = "PAY_PER_REQUEST"

# Monitoring
enable_cloudwatch_logs = true
log_retention_days     = 7

# Tags
tags = {
  Environment = "development"
  ManagedBy   = "terraform"
  Project     = "cloudfront-signed-urls"
}
```

**For Custom Domain Setup:**

If using a custom domain, update the variables:

```hcl
custom_domain_enabled = true
domain_name          = "pe-labs.com"
subdomain            = "cdn-demo"
```

**Note:** You must have:
1. A Route53 hosted zone for `pe-labs.com`
2. An ACM certificate in **us-east-1** for `cdn-demo.pe-labs.com` or `*.pe-labs.com`

### Step 4: Initialize Terraform

```bash
terraform init
```

**Expected Output:**
```
Initializing the backend...
Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Finding latest version of hashicorp/tls...
- Finding latest version of hashicorp/random...
...
Terraform has been successfully initialized!
```

### Step 5: Review the Deployment Plan

```bash
terraform plan
```

**Review the resources to be created:**
- 1 S3 bucket with policies
- 1 CloudFront distribution
- 2 CloudFront public keys (active and inactive)
- 2 CloudFront key groups (active and inactive)
- 1 CloudFront Origin Access Control
- 1 DynamoDB table
- 1 Lambda function
- 1 Lambda execution role with policies
- 1 API Gateway REST API with resources and methods
- 2 Secrets Manager secrets (active and inactive private keys)
- 5 SSM parameters (key configuration)
- CloudWatch log groups
- Route53 records (if custom domain enabled)

**Expected resource count:** Approximately 40-50 resources

### Step 6: Deploy the Infrastructure

```bash
terraform apply
```

Type `yes` when prompted.

**Deployment time:** 5-10 minutes (CloudFront distribution takes the longest)

### Step 7: Capture Outputs

After successful deployment, Terraform will output important values:

```bash
terraform output
```

**Example outputs:**
```
api_gateway_url = "https://abc123def.execute-api.eu-west-2.amazonaws.com/prod"
cloudfront_domain = "d1234567890abc.cloudfront.net"
custom_domain_url = "https://cdn-demo.pe-labs.com" (if enabled)
s3_bucket_name = "cloudfront-signed-urls-demo-bucket-xyz123"
dynamodb_table_name = "cloudfront-signed-urls-demo-files"
lambda_function_name = "cloudfront-signed-urls-demo-function"
active_key_pair_id = "K2PNHFE2BDB9MN"
inactive_key_pair_id = "K3QOGIF3CEC0NO"
```

**Save these outputs** - you'll need them for testing and configuration.

### Step 8: Verify Secrets and Parameters

**Check Secrets Manager:**
```bash
# List secrets
aws secretsmanager list-secrets --query "SecretList[?contains(Name, 'cloudfront-signed-urls-demo')]"

# Verify active private key exists (don't retrieve the value)
aws secretsmanager describe-secret --secret-id cloudfront-signed-urls-demo-active-private-key

# Verify inactive private key exists
aws secretsmanager describe-secret --secret-id cloudfront-signed-urls-demo-inactive-private-key
```

**Check SSM Parameters:**
```bash
# List all parameters
aws ssm get-parameters-by-path --path /cloudfront-signer --recursive

# Get active key ID
aws ssm get-parameter --name /cloudfront-signer/active-key-id --query "Parameter.Value" --output text

# Get active secret ARN
aws ssm get-parameter --name /cloudfront-signer/active-secret-arn --query "Parameter.Value" --output text

# Get last rotation timestamp
aws ssm get-parameter --name /cloudfront-signer/last-rotation --query "Parameter.Value" --output text
```

### Step 9: Verify S3 Bucket

```bash
# Get bucket name from Terraform output
BUCKET_NAME=$(terraform output -raw s3_bucket_name)

# Verify bucket exists and is private
aws s3api get-bucket-acl --bucket $BUCKET_NAME
aws s3api get-public-access-block --bucket $BUCKET_NAME

# Check bucket encryption
aws s3api get-bucket-encryption --bucket $BUCKET_NAME
```

**Expected:** Bucket should have:
- Block all public access enabled
- AES-256 encryption
- No public ACLs

### Step 10: Verify Lambda Function

```bash
# Get function name from Terraform output
FUNCTION_NAME=$(terraform output -raw lambda_function_name)

# Get function configuration
aws lambda get-function-configuration --function-name $FUNCTION_NAME

# Verify environment variables
aws lambda get-function-configuration --function-name $FUNCTION_NAME \
  --query "Environment.Variables" --output json
```

**Expected environment variables:**
```json
{
  "BUCKET_NAME": "cloudfront-signed-urls-demo-bucket-xyz123",
  "TABLE_NAME": "cloudfront-signed-urls-demo-files",
  "CLOUDFRONT_DOMAIN": "d1234567890abc.cloudfront.net",
  "UPLOAD_EXPIRATION": "900",
  "DOWNLOAD_EXPIRATION": "3600",
  "ACTIVE_KEY_ID_PARAM": "/cloudfront-signer/active-key-id",
  "ACTIVE_SECRET_ARN_PARAM": "/cloudfront-signer/active-secret-arn"
}
```

---

## 4. Migration from Python Lambda

If you have an existing deployment using the Python Lambda, follow these steps to migrate.

### Step 1: Backup Current State

```bash
cd terraform

# Export current Terraform state
terraform state pull > terraform-state-backup.json

# Export current outputs
terraform output > terraform-outputs-backup.txt
```

### Step 2: Build Java Lambda

```bash
cd ../lambda-java
./build.sh
cd ../terraform
```

### Step 3: Review Migration Plan

```bash
terraform plan
```

**Expected changes:**
- **Replace:** Lambda function (runtime change from Python to Java)
- **Add:** 2 CloudFront public keys (active and inactive)
- **Add:** 2 CloudFront key groups (active and inactive)
- **Add:** 2 Secrets Manager secrets (active and inactive)
- **Add:** 5 SSM parameters
- **Modify:** CloudFront distribution (trusted key groups)
- **Modify:** Lambda IAM role (SSM permissions)
- **Remove:** Old single CloudFront public key and key group

**Important:** The CloudFront distribution will be updated in-place (not replaced), so there should be no downtime.

### Step 4: Apply Migration

```bash
terraform apply
```

**During migration:**
1. New key pairs are created
2. CloudFront distribution is updated to trust both old and new key groups
3. Lambda function is replaced with Java version
4. Old key resources are removed

**Note:** Existing signed URLs will continue to work during migration because CloudFront trusts multiple key groups.

### Step 5: Verify Migration

Follow the verification steps in Section 5.

---

## 5. Verification and Testing

### 5.1. Test Lambda Function Directly

```bash
# Get API Gateway URL
API_URL=$(terraform output -raw api_gateway_url)

# Test upload endpoint
curl -X POST $API_URL/api/files/upload \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.txt","contentType":"text/plain"}'
```

**Expected response:**
```json
{
  "fileId": "550e8400-e29b-41d4-a716-446655440000",
  "uploadUrl": "https://d1234567890abc.cloudfront.net/uploads/550e8400.../test.txt?Policy=...&Signature=...&Key-Pair-Id=K2PNHFE2BDB9MN",
  "filename": "test.txt",
  "expiresIn": "900"
}
```

**Verify the Key-Pair-Id matches the active key:**
```bash
aws ssm get-parameter --name /cloudfront-signer/active-key-id --query "Parameter.Value" --output text
```

### 5.2. Test File Upload

```bash
# Use the uploadUrl from previous response
UPLOAD_URL="<paste uploadUrl here>"

# Upload a test file
echo "Hello, CloudFront!" > test.txt
curl -X PUT "$UPLOAD_URL" \
  -H "Content-Type: text/plain" \
  --upload-file test.txt
```

**Expected:** HTTP 200 response

### 5.3. Test Download

```bash
# Get the fileId from the upload response
FILE_ID="550e8400-e29b-41d4-a716-446655440000"

# Request download URL
curl -X GET $API_URL/api/files/download/$FILE_ID
```

**Expected response:**
```json
{
  "fileId": "550e8400-e29b-41d4-a716-446655440000",
  "downloadUrl": "https://d1234567890abc.cloudfront.net/uploads/550e8400.../test.txt?Expires=...&Signature=...&Key-Pair-Id=K2PNHFE2BDB9MN",
  "filename": "test.txt",
  "expiresIn": "3600"
}
```

**Download the file:**
```bash
DOWNLOAD_URL="<paste downloadUrl here>"
curl "$DOWNLOAD_URL"
```

**Expected:** File contents: "Hello, CloudFront!"

### 5.4. Verify DynamoDB Metadata

```bash
# Get table name
TABLE_NAME=$(terraform output -raw dynamodb_table_name)

# Scan table
aws dynamodb scan --table-name $TABLE_NAME
```

**Expected:** Record with fileId, filename, s3Key, contentType, uploadedAt

### 5.5. Check Lambda Logs

```bash
# Get function name
FUNCTION_NAME=$(terraform output -raw lambda_function_name)

# View recent logs
aws logs tail /aws/lambda/$FUNCTION_NAME --follow
```

**Look for:**
- Successful initialization with active key ID
- Signed URL generation requests
- No errors or exceptions

---

## 6. First Key Rotation

After verifying the deployment, test the key rotation process.

### Step 1: Install Rotation Script Dependencies

```bash
cd ../scripts
pip install boto3 pyopenssl
```

### Step 2: Review Current Key Configuration

```bash
# Check current active key
aws ssm get-parameter --name /cloudfront-signer/active-key-id

# Check last rotation timestamp
aws ssm get-parameter --name /cloudfront-signer/last-rotation
```

### Step 3: Execute Rotation (Dry Run)

**Note:** The provided script performs actual rotation. For a safer first test, you can manually review the steps in `docs/KEY_ROTATION_GUIDE.md`.

### Step 4: Execute Rotation

```bash
python rotate-keys.py
```

**Expected output:**
```
Starting CloudFront key rotation...
Step 1: Fetching current inactive key details from SSM...
  - Inactive Key ID: K3QOGIF3CEC0NO
  - Inactive Secret ARN: arn:aws:secretsmanager:...
Step 2: Generating new RSA-2048 key pair...
  - New key pair generated successfully.
Step 3: Uploading new public key to CloudFront...
  - New Public Key ID: K4RPHJG4DFD1OP
Step 4: Updating inactive key group...
  - Key group updated with new key K4RPHJG4DFD1OP.
Step 5: Storing new private key in Secrets Manager...
  - Secret updated with new private key.
Step 6: Promoting new key to 'active' in SSM Parameter Store...
  - SSM parameters updated. New key is now active.
Step 7: Demoting old active key to 'inactive'...
Step 8: Cleaning up old public key from CloudFront...
  - Old public key K3QOGIF3CEC0NO deleted.
✅ Key rotation completed successfully!
  - New Active Key ID: K4RPHJG4DFD1OP
```

### Step 5: Verify Rotation

```bash
# Check new active key
aws ssm get-parameter --name /cloudfront-signer/active-key-id

# Generate a new signed URL
curl -X POST $API_URL/api/files/upload \
  -H "Content-Type: application/json" \
  -d '{"filename":"post-rotation-test.txt","contentType":"text/plain"}'
```

**Verify:** The new uploadUrl should contain the new Key-Pair-Id (K4RPHJG4DFD1OP)

### Step 6: Verify Old URLs Still Work

If you have a signed URL generated before rotation (within its expiration window), test that it still works:

```bash
# Use a URL generated in Step 5.2 (if still within 15-minute expiration)
curl "$OLD_UPLOAD_URL"
```

**Expected:** Should still work because CloudFront trusts both key groups

---

## 7. Troubleshooting

### Issue: Lambda function fails with "Access Denied" to SSM

**Cause:** IAM role doesn't have SSM permissions

**Solution:**
```bash
# Verify IAM policy
aws iam get-role-policy --role-name cloudfront-signed-urls-demo-lambda-role \
  --policy-name cloudfront-signed-urls-demo-lambda-policy

# Re-apply Terraform to fix
terraform apply
```

### Issue: Lambda function fails with "Signature does not match"

**Cause:** Private key doesn't match public key

**Solution:**
```bash
# Check which key Lambda is using
aws logs tail /aws/lambda/cloudfront-signed-urls-demo-function --since 5m

# Verify SSM parameters point to correct resources
aws ssm get-parameter --name /cloudfront-signer/active-key-id
aws ssm get-parameter --name /cloudfront-signer/active-secret-arn
```

### Issue: CloudFront returns 403 Forbidden

**Possible causes:**
1. Signed URL has expired
2. Key-Pair-Id doesn't match a trusted key
3. Signature is invalid

**Solution:**
```bash
# Verify CloudFront distribution trusts the key group
aws cloudfront get-distribution --id <DISTRIBUTION_ID> \
  --query "Distribution.DistributionConfig.DefaultCacheBehavior.TrustedKeyGroups"

# Check that the key group contains the active key
aws cloudfront get-key-group --id <KEY_GROUP_ID>
```

### Issue: S3 bucket access denied

**Cause:** CloudFront OAC not properly configured

**Solution:**
```bash
# Verify S3 bucket policy allows CloudFront
aws s3api get-bucket-policy --bucket <BUCKET_NAME>

# Re-apply Terraform
terraform apply
```

### Issue: Java Lambda timeout

**Cause:** Cold start or network issues

**Solution:**
```bash
# Increase Lambda timeout
# In terraform.tfvars:
lambda_timeout = 60

# Apply changes
terraform apply
```

---

## Summary

You should now have a fully deployed CloudFront Signed URLs solution with:

✅ S3 bucket for private file storage  
✅ CloudFront distribution with dual-path behaviors  
✅ Java Lambda function for signed URL generation  
✅ DynamoDB table for file metadata  
✅ API Gateway for HTTP access  
✅ Active and inactive key pairs for rotation  
✅ Secrets Manager secrets for private keys  
✅ SSM parameters for key configuration  
✅ IAM roles with least privilege permissions  

**Next Steps:**
1. Set up monitoring and alarms
2. Schedule regular key rotations (every 90 days)
3. Integrate with your application
4. Consider Service Catalog rollout for other teams

For operational procedures, see `docs/KEY_ROTATION_GUIDE.md`.

