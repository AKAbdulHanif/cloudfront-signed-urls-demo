# CloudFront Signed URLs - Infrastructure Reference

**Quick reference for all AWS resources deployed by this solution**

---

## Resource Overview

| Resource Type | Count | Purpose |
|--------------|-------|---------|
| S3 Bucket | 1 | Private file storage |
| CloudFront Distribution | 1 | Content delivery with signed URLs |
| CloudFront Public Keys | 2 | Active and inactive keys for rotation |
| CloudFront Key Groups | 2 | Active and inactive key groups |
| CloudFront OAC | 1 | Origin Access Control for S3 |
| Lambda Function | 1 | Signed URL generation (Java 11) |
| DynamoDB Table | 1 | File metadata storage |
| API Gateway | 1 | HTTP API for Lambda |
| Secrets Manager Secrets | 2 | Active and inactive private keys |
| SSM Parameters | 5 | Key rotation configuration |
| IAM Roles | 1 | Lambda execution role |
| CloudWatch Log Groups | 1 | Lambda logs |
| Route53 Records | 1-2 | Custom domain (optional) |

**Total:** ~40-50 resources

---

## S3 Bucket

### Configuration
```
Name: {project_name}-bucket-{random_suffix}
Region: {aws_region}
Encryption: AES-256 (SSE-S3)
Versioning: Enabled
Public Access: Blocked (all)
```

### Bucket Policy
- Allows CloudFront OAC to read objects
- Denies all other access

### Folder Structure
```
s3://{bucket-name}/
├── uploads/
│   ├── {fileId-1}/
│   │   └── {filename}
│   ├── {fileId-2}/
│   │   └── {filename}
│   └── ...
```

### Terraform Resource
```hcl
resource "aws_s3_bucket" "main"
resource "aws_s3_bucket_public_access_block" "main"
resource "aws_s3_bucket_versioning" "main"
resource "aws_s3_bucket_server_side_encryption_configuration" "main"
resource "aws_s3_bucket_policy" "main"
```

---

## CloudFront Distribution

### Configuration
```
Domain: {distribution-id}.cloudfront.net
Custom Domain: {subdomain}.{domain_name} (optional)
Price Class: PriceClass_100 (North America & Europe)
HTTP Version: HTTP/2
IPv6: Enabled
```

### Cache Behaviors

#### Default Behavior (Downloads)
```
Path Pattern: Default (*)
Allowed Methods: GET, HEAD, OPTIONS
Cached Methods: GET, HEAD
Viewer Protocol: Redirect HTTP to HTTPS
Compress: Enabled
TTL: Min=0, Default=0, Max=0 (no caching for signed URLs)
Trusted Key Groups: [active-key-group, inactive-key-group]
```

#### Upload Behavior
```
Path Pattern: uploads/*
Allowed Methods: DELETE, GET, HEAD, OPTIONS, PATCH, POST, PUT
Cached Methods: GET, HEAD
Viewer Protocol: Redirect HTTP to HTTPS
Compress: Enabled
TTL: Min=0, Default=0, Max=0
Trusted Key Groups: [active-key-group, inactive-key-group]
```

### Origin
```
Type: S3 bucket
Origin Access: Origin Access Control (OAC)
Origin Protocol: HTTPS only
```

### Terraform Resources
```hcl
resource "aws_cloudfront_distribution" "main"
resource "aws_cloudfront_origin_access_control" "main"
```

---

## CloudFront Keys and Key Groups

### Active Key Pair
```
Public Key Name: {project_name}-active-key
Public Key ID: K2PNHFE2BDB9MN (example)
Algorithm: RSA-2048
Key Group Name: {project_name}-active-key-group
```

### Inactive Key Pair
```
Public Key Name: {project_name}-inactive-key
Public Key ID: K3QOGIF3CEC0NO (example)
Algorithm: RSA-2048
Key Group Name: {project_name}-inactive-key-group
```

### Distribution Trust
The CloudFront distribution is configured to trust **both** key groups, enabling zero-downtime rotation.

### Terraform Resources
```hcl
resource "aws_cloudfront_public_key" "active"
resource "aws_cloudfront_public_key" "inactive"
resource "aws_cloudfront_key_group" "active"
resource "aws_cloudfront_key_group" "inactive"
```

---

## Lambda Function

### Configuration
```
Function Name: {project_name}-function
Runtime: Java 11 (Corretto)
Handler: com.example.CloudFrontSignerHandler::handleRequest
Memory: 512 MB
Timeout: 30 seconds
Architecture: x86_64
Package: cloudfront-signer-lambda-1.0.0.jar (~18 MB)
```

### Environment Variables
```
BUCKET_NAME: {bucket-name}
TABLE_NAME: {table-name}
CLOUDFRONT_DOMAIN: {cloudfront-domain}
UPLOAD_EXPIRATION: 900 (seconds)
DOWNLOAD_EXPIRATION: 3600 (seconds)
ACTIVE_KEY_ID_PARAM: /cloudfront-signer/active-key-id
ACTIVE_SECRET_ARN_PARAM: /cloudfront-signer/active-secret-arn
```

### Execution Role Permissions
- `dynamodb:GetItem`, `PutItem`, `Scan` on metadata table
- `secretsmanager:GetSecretValue` on both private key secrets
- `ssm:GetParameter` on key configuration parameters
- `logs:CreateLogGroup`, `CreateLogStream`, `PutLogEvents`

### Terraform Resources
```hcl
resource "aws_lambda_function" "main"
resource "aws_iam_role" "lambda_role"
resource "aws_iam_role_policy" "lambda_policy"
resource "aws_iam_role_policy_attachment" "lambda_basic"
```

---

## DynamoDB Table

### Configuration
```
Table Name: {project_name}-files
Billing Mode: PAY_PER_REQUEST (on-demand)
Partition Key: fileId (String)
Point-in-time Recovery: Enabled
```

### Schema
```
fileId (String, Partition Key) - UUID of the file
filename (String) - Original filename
s3Key (String) - S3 object key
contentType (String) - MIME type
uploadedAt (String) - ISO 8601 timestamp
```

### Example Item
```json
{
  "fileId": "550e8400-e29b-41d4-a716-446655440000",
  "filename": "document.pdf",
  "s3Key": "uploads/550e8400-e29b-41d4-a716-446655440000/document.pdf",
  "contentType": "application/pdf",
  "uploadedAt": "2025-10-19T10:30:00Z"
}
```

### Terraform Resource
```hcl
resource "aws_dynamodb_table" "main"
```

---

## API Gateway

### Configuration
```
API Name: {project_name}-api
Type: REST API
Stage: prod
Endpoint Type: Regional
```

### Endpoints

#### POST /api/files/upload
```
Integration: Lambda Proxy
Method: POST
Authorization: None (add your own if needed)
CORS: Enabled
Request Body: {"filename": "string", "contentType": "string"}
Response: {"fileId": "string", "uploadUrl": "string", "filename": "string", "expiresIn": "string"}
```

#### GET /api/files/download/{fileId}
```
Integration: Lambda Proxy
Method: GET
Authorization: None
CORS: Enabled
Path Parameter: fileId (required)
Response: {"fileId": "string", "downloadUrl": "string", "filename": "string", "expiresIn": "string"}
```

#### GET /api/files
```
Integration: Lambda Proxy
Method: GET
Authorization: None
CORS: Enabled
Response: {"files": [{"fileId": "string", "filename": "string", "uploadedAt": "string"}]}
```

### Terraform Resources
```hcl
resource "aws_api_gateway_rest_api" "main"
resource "aws_api_gateway_resource" "api"
resource "aws_api_gateway_resource" "files"
resource "aws_api_gateway_resource" "upload"
resource "aws_api_gateway_resource" "download"
resource "aws_api_gateway_method" "upload_post"
resource "aws_api_gateway_method" "download_get"
resource "aws_api_gateway_method" "files_get"
resource "aws_api_gateway_integration" "upload"
resource "aws_api_gateway_integration" "download"
resource "aws_api_gateway_integration" "files"
resource "aws_api_gateway_deployment" "main"
```

---

## Secrets Manager

### Active Private Key Secret
```
Name: {project_name}-active-private-key
Description: Active private key for CloudFront signed URLs
Recovery Window: 7 days
Rotation: Manual (via rotation script)
Format: PEM (PKCS#8)
```

### Inactive Private Key Secret
```
Name: {project_name}-inactive-private-key
Description: Inactive private key for CloudFront signed URLs (staged for rotation)
Recovery Window: 7 days
Rotation: Manual (via rotation script)
Format: PEM (PKCS#8)
```

### Access
- Lambda execution role has `GetSecretValue` permission on both secrets
- Secrets are never logged or exposed in CloudWatch

### Terraform Resources
```hcl
resource "aws_secretsmanager_secret" "active_private_key"
resource "aws_secretsmanager_secret_version" "active_private_key"
resource "aws_secretsmanager_secret" "inactive_private_key"
resource "aws_secretsmanager_secret_version" "inactive_private_key"
```

---

## SSM Parameter Store

### Parameters

#### /cloudfront-signer/active-key-id
```
Type: String
Description: CloudFront active public key ID
Example Value: K2PNHFE2BDB9MN
Used By: Lambda function to determine which key to use for signing
```

#### /cloudfront-signer/active-secret-arn
```
Type: String
Description: ARN of the Secrets Manager secret containing the active private key
Example Value: arn:aws:secretsmanager:eu-west-2:123456789012:secret:cloudfront-signed-urls-demo-active-private-key-AbCdEf
Used By: Lambda function to retrieve the private key
```

#### /cloudfront-signer/inactive-key-id
```
Type: String
Description: CloudFront inactive public key ID (staged for rotation)
Example Value: K3QOGIF3CEC0NO
Used By: Rotation script
```

#### /cloudfront-signer/inactive-secret-arn
```
Type: String
Description: ARN of the Secrets Manager secret containing the inactive private key
Example Value: arn:aws:secretsmanager:eu-west-2:123456789012:secret:cloudfront-signed-urls-demo-inactive-private-key-GhIjKl
Used By: Rotation script
```

#### /cloudfront-signer/last-rotation
```
Type: String
Description: Timestamp of the last key rotation
Example Value: 1697712000 (Unix timestamp)
Used By: Monitoring and audit
```

### Terraform Resources
```hcl
resource "aws_ssm_parameter" "active_key_id"
resource "aws_ssm_parameter" "active_secret_arn"
resource "aws_ssm_parameter" "inactive_key_id"
resource "aws_ssm_parameter" "inactive_secret_arn"
resource "aws_ssm_parameter" "last_rotation"
```

---

## IAM Roles and Policies

### Lambda Execution Role
```
Role Name: {project_name}-lambda-role
Assume Role Policy: lambda.amazonaws.com
```

### Attached Policies

#### AWS Managed Policy
```
Policy: AWSLambdaBasicExecutionRole
Permissions: CloudWatch Logs access
```

#### Custom Inline Policy
```
Policy Name: {project_name}-lambda-policy

Permissions:
- DynamoDB:
  - GetItem, PutItem, UpdateItem, DeleteItem, Query, Scan
  - Resource: {dynamodb-table-arn}

- Secrets Manager:
  - GetSecretValue
  - Resources: [active-secret-arn, inactive-secret-arn]

- SSM Parameter Store:
  - GetParameter, GetParameters
  - Resources: [active-key-id-arn, active-secret-arn-arn]

- S3:
  - PutObject, GetObject, DeleteObject, ListBucket
  - Resources: [{bucket-arn}, {bucket-arn}/*]

- CloudWatch Logs:
  - CreateLogGroup, CreateLogStream, PutLogEvents
  - Resource: /aws/lambda/{function-name}:*
```

### Terraform Resources
```hcl
resource "aws_iam_role" "lambda_role"
resource "aws_iam_role_policy" "lambda_policy"
resource "aws_iam_role_policy_attachment" "lambda_basic"
```

---

## CloudWatch Logs

### Log Group
```
Name: /aws/lambda/{project_name}-function
Retention: 7 days (configurable)
```

### Log Events
- Lambda initialization (cold starts)
- Signed URL generation requests
- Key configuration cache hits/misses
- Errors and exceptions

### Terraform Resource
```hcl
resource "aws_cloudwatch_log_group" "lambda"
```

---

## Route53 (Optional - Custom Domain)

### Records

#### A Record (IPv4)
```
Name: {subdomain}.{domain_name}
Type: A
Alias: Yes
Target: CloudFront distribution
Routing Policy: Simple
```

#### AAAA Record (IPv6)
```
Name: {subdomain}.{domain_name}
Type: AAAA
Alias: Yes
Target: CloudFront distribution
Routing Policy: Simple
```

### Terraform Resources
```hcl
resource "aws_route53_record" "main_a"
resource "aws_route53_record" "main_aaaa"
data "aws_route53_zone" "main"
data "aws_acm_certificate" "main"
```

---

## Cost Breakdown (Estimated)

### Monthly Costs (Typical Application)

| Service | Usage | Cost |
|---------|-------|------|
| S3 Storage | 10 GB | $0.23 |
| S3 Requests | 10,000 PUT, 50,000 GET | $0.06 |
| CloudFront Data Transfer | 100 GB | $8.50 |
| CloudFront Requests | 100,000 | $0.10 |
| Lambda Invocations | 100,000 @ 512MB, 200ms avg | $0.83 |
| DynamoDB | On-demand, 100,000 reads/writes | $0.25 |
| Secrets Manager | 2 secrets | $0.80 |
| SSM Parameters | 5 standard parameters | $0.00 |
| API Gateway | 100,000 requests | $0.35 |
| **Total** | | **~$11.12/month** |

### Key Rotation Costs
- Per rotation: <$0.01
- Annual (4 rotations): <$0.05

### Notes
- CloudFront costs vary by region and data transfer volume
- Lambda costs scale with invocation count and duration
- DynamoDB on-demand pricing scales with actual usage
- First 1 million Lambda requests per month are free (AWS Free Tier)

---

## Terraform Outputs

After deployment, Terraform provides these outputs:

```hcl
output "api_gateway_url"           # API Gateway endpoint
output "cloudfront_domain"         # CloudFront distribution domain
output "custom_domain_url"         # Custom domain URL (if enabled)
output "s3_bucket_name"            # S3 bucket name
output "dynamodb_table_name"       # DynamoDB table name
output "lambda_function_name"      # Lambda function name
output "active_key_pair_id"        # Active CloudFront public key ID
output "inactive_key_pair_id"      # Inactive CloudFront public key ID
output "active_key_group_id"       # Active key group ID
output "inactive_key_group_id"     # Inactive key group ID
output "active_secret_arn"         # Active private key secret ARN (sensitive)
output "inactive_secret_arn"       # Inactive private key secret ARN (sensitive)
```

---

## Quick Commands

### Get All Resource Names
```bash
cd terraform

# S3 Bucket
terraform output -raw s3_bucket_name

# DynamoDB Table
terraform output -raw dynamodb_table_name

# Lambda Function
terraform output -raw lambda_function_name

# API Gateway URL
terraform output -raw api_gateway_url

# CloudFront Domain
terraform output -raw cloudfront_domain

# Active Key ID
terraform output -raw active_key_pair_id
```

### Verify All Resources Exist
```bash
# S3 Bucket
aws s3 ls s3://$(terraform output -raw s3_bucket_name)

# DynamoDB Table
aws dynamodb describe-table --table-name $(terraform output -raw dynamodb_table_name)

# Lambda Function
aws lambda get-function --function-name $(terraform output -raw lambda_function_name)

# CloudFront Distribution
aws cloudfront list-distributions --query "DistributionList.Items[?contains(Aliases.Items, '$(terraform output -raw cloudfront_domain)')]"

# Secrets
aws secretsmanager list-secrets --query "SecretList[?contains(Name, 'cloudfront-signed-urls-demo')]"

# SSM Parameters
aws ssm get-parameters-by-path --path /cloudfront-signer --recursive
```

---

## Related Documentation

- **Deployment Guide:** `docs/DEPLOYMENT_GUIDE.md`
- **Key Rotation Strategy:** `docs/KEY_ROTATION_STRATEGY.md`
- **Key Rotation Guide:** `docs/KEY_ROTATION_GUIDE.md`
- **Java Lambda README:** `lambda-java/README.md`
- **Service Catalog Epic:** `docs/SERVICE_CATALOG_EPIC.md`

