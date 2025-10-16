# Security Guide

## 🔒 Security Best Practices

This document outlines the security considerations and best practices for the CloudFront Signed URLs Demo.

## Key Management

### ⚠️ CRITICAL: Never Commit Keys to Version Control

**The `.gitignore` file is configured to exclude:**
- `*.pem` - PEM formatted keys
- `*.key` - Key files
- `private_key*` - Any file starting with "private_key"
- `public_key*` - Any file starting with "public_key"
- `terraform.tfvars` - May contain sensitive configuration

### Key Generation

**Option 1: Auto-Generation (Recommended)**

Leave the key fields empty in `terraform.tfvars`:
```hcl
cloudfront_public_key  = ""
cloudfront_private_key = ""
```

Terraform will automatically:
1. Generate RSA key pair (2048-bit)
2. Store private key in AWS Secrets Manager (encrypted)
3. Upload public key to CloudFront
4. Never store keys in Terraform state (uses `sensitive = true`)

**Option 2: Manual Generation**

If you need to generate keys manually:

```bash
# Generate private key (PKCS#1 format required!)
openssl genrsa -out private_key.pem 2048

# Extract public key
openssl rsa -in private_key.pem -pubout -out public_key.pem

# Store in AWS Secrets Manager (DO NOT put in terraform.tfvars!)
aws secretsmanager create-secret \
  --name cloudfront-signedurl-demo-private-key \
  --secret-string file://private_key.pem

# Delete local copies
shred -u private_key.pem public_key.pem
```

### Key Rotation

Rotate CloudFront signing keys quarterly:

```bash
# 1. Generate new key pair
./scripts/generate-keys.sh

# 2. Update Secrets Manager
aws secretsmanager update-secret \
  --secret-id <SECRET_ARN> \
  --secret-string file://new_private_key.pem

# 3. Update CloudFront public key
# (Use Terraform or AWS Console)

# 4. Securely delete old keys
shred -u *.pem
```

## AWS Security

### IAM Permissions

**Principle of Least Privilege**

The Lambda execution role has minimal permissions:
- Read from Secrets Manager (specific secret only)
- Read/Write to specific S3 bucket
- Read/Write to specific DynamoDB table
- Write CloudWatch Logs

**Recommended: Restrict Terraform User**

Create a dedicated IAM user for Terraform with only required permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudfront:*",
        "lambda:*",
        "apigateway:*",
        "s3:*",
        "dynamodb:*",
        "secretsmanager:*",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PassRole",
        "route53:*",
        "acm:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

### S3 Bucket Security

**Private Bucket**
- ✅ Block all public access
- ✅ Encryption at rest (AES-256)
- ✅ Versioning enabled
- ✅ Access only via CloudFront OAC
- ✅ Server-side encryption

**Bucket Policy**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipal",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::BUCKET_NAME/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::ACCOUNT_ID:distribution/DISTRIBUTION_ID"
        }
      }
    }
  ]
}
```

### CloudFront Security

**TLS/SSL**
- ✅ HTTPS only (redirect HTTP to HTTPS)
- ✅ TLS 1.2 minimum
- ✅ ACM certificate for custom domain
- ✅ Signed URLs for access control

**Origin Access Control (OAC)**
- ✅ CloudFront uses OAC to access S3
- ✅ S3 bucket not publicly accessible
- ✅ All requests must go through CloudFront

**Signed URLs**
- ✅ Time-limited access (15 min upload, 1 hour download)
- ✅ RSA-SHA1 signature validation
- ✅ Private key never exposed
- ✅ URLs expire automatically

### DynamoDB Security

- ✅ Encryption at rest
- ✅ Point-in-time recovery enabled
- ✅ TTL for automatic cleanup
- ✅ On-demand billing (no over-provisioning)

### Secrets Manager

**Private Key Storage**
- ✅ Encrypted at rest (AWS KMS)
- ✅ Automatic rotation (optional)
- ✅ Access logged in CloudTrail
- ✅ IAM-based access control

**Best Practices**
```bash
# Enable automatic rotation (optional)
aws secretsmanager rotate-secret \
  --secret-id <SECRET_ARN> \
  --rotation-lambda-arn <LAMBDA_ARN>

# Enable deletion protection
aws secretsmanager update-secret \
  --secret-id <SECRET_ARN> \
  --description "CloudFront private key - DO NOT DELETE"
```

## Network Security

### API Gateway

**Throttling**
```hcl
# In Terraform
resource "aws_api_gateway_usage_plan" "main" {
  throttle_settings {
    burst_limit = 100
    rate_limit  = 50
  }
}
```

**IP Whitelisting (Optional)**
```hcl
resource "aws_api_gateway_rest_api_policy" "main" {
  policy = jsonencode({
    Statement = [{
      Effect = "Deny"
      Principal = "*"
      Action = "execute-api:Invoke"
      Resource = "*"
      Condition = {
        NotIpAddress = {
          "aws:SourceIp" = ["YOUR_IP_CIDR"]
        }
      }
    }]
  })
}
```

### CloudFront

**Geo-Restriction (Optional)**
```hcl
restrictions {
  geo_restriction {
    restriction_type = "whitelist"
    locations        = ["US", "GB", "DE"]
  }
}
```

**WAF Integration (Recommended for Production)**
```hcl
resource "aws_wafv2_web_acl" "main" {
  # Rate limiting
  # SQL injection protection
  # XSS protection
}
```

## Application Security

### Input Validation

**Lambda Function**
- ✅ Validates filename (no path traversal)
- ✅ Validates content type
- ✅ Limits file size (configurable)
- ✅ Sanitizes user input

**Recommended: Add File Type Validation**
```python
ALLOWED_EXTENSIONS = {'.pdf', '.jpg', '.png', '.txt', '.docx'}

def validate_filename(filename):
    ext = os.path.splitext(filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise ValueError(f"File type {ext} not allowed")
```

### CORS Configuration

**Restrictive CORS (Recommended for Production)**
```python
headers = {
    'Access-Control-Allow-Origin': 'https://yourdomain.com',  # Not '*'
    'Access-Control-Allow-Methods': 'GET,POST,DELETE',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization'
}
```

### Content Security

**Virus Scanning (Recommended for Production)**

Integrate with AWS services:
1. **S3 Event → Lambda → ClamAV**
2. **S3 Event → Lambda → Third-party API**

```python
# Example: Scan on upload
def scan_file(bucket, key):
    # Download file
    # Scan with ClamAV or API
    # Delete if malicious
    # Update DynamoDB status
```

## Monitoring & Logging

### CloudWatch Logs

**Lambda Logs**
- ✅ All invocations logged
- ✅ Errors logged with stack traces
- ✅ 30-day retention

**CloudTrail**
- ✅ API calls logged
- ✅ Key access logged
- ✅ S3 data events (optional)

### Alarms

**Recommended CloudWatch Alarms**
```bash
# Lambda errors
aws cloudwatch put-metric-alarm \
  --alarm-name lambda-errors \
  --metric-name Errors \
  --threshold 10 \
  --evaluation-periods 1

# API Gateway 5xx errors
aws cloudwatch put-metric-alarm \
  --alarm-name api-5xx \
  --metric-name 5XXError \
  --threshold 5 \
  --evaluation-periods 1

# Unauthorized access attempts
aws cloudwatch put-metric-alarm \
  --alarm-name api-4xx \
  --metric-name 4XXError \
  --threshold 100 \
  --evaluation-periods 1
```

## Compliance

### Data Privacy

**GDPR Considerations**
- ✅ Data encryption at rest and in transit
- ✅ TTL for automatic data deletion
- ✅ Ability to delete user data (DELETE endpoint)
- ✅ Access logs for audit trail

**Data Retention**
- Files: 24 hours (configurable via DynamoDB TTL)
- Logs: 30 days (configurable)
- Backups: Configure as needed

### Audit Trail

**CloudTrail Events**
- API calls to AWS services
- IAM role assumptions
- Secrets Manager access
- S3 data events (optional)

## Incident Response

### Security Incident Checklist

1. **Detect**
   - Monitor CloudWatch alarms
   - Review CloudTrail logs
   - Check GuardDuty findings

2. **Contain**
   - Rotate compromised keys immediately
   - Disable affected API keys
   - Block malicious IPs in WAF

3. **Investigate**
   - Review CloudWatch Logs
   - Check S3 access logs
   - Analyze CloudTrail events

4. **Remediate**
   - Patch vulnerabilities
   - Update IAM policies
   - Rotate all credentials

5. **Document**
   - Record incident details
   - Update security procedures
   - Conduct post-mortem

### Key Compromise Response

If private key is compromised:

```bash
# 1. Generate new key pair
openssl genrsa -out new_private_key.pem 2048
openssl rsa -in new_private_key.pem -pubout -out new_public_key.pem

# 2. Update Secrets Manager
aws secretsmanager update-secret \
  --secret-id <SECRET_ARN> \
  --secret-string file://new_private_key.pem

# 3. Update CloudFront (via Terraform)
terraform apply -var="cloudfront_public_key=$(cat new_public_key.pem)"

# 4. Invalidate old signed URLs (they'll stop working automatically)

# 5. Securely delete old keys
shred -u new_private_key.pem new_public_key.pem
```

## Security Checklist

### Before Deployment

- [ ] Review IAM permissions
- [ ] Ensure keys are not in version control
- [ ] Configure CORS restrictively
- [ ] Set up CloudWatch alarms
- [ ] Enable CloudTrail logging
- [ ] Configure S3 bucket encryption
- [ ] Set appropriate TTL values
- [ ] Review API Gateway throttling

### After Deployment

- [ ] Verify S3 bucket is private
- [ ] Test signed URL expiration
- [ ] Verify HTTPS-only access
- [ ] Check CloudWatch logs
- [ ] Test error handling
- [ ] Verify IAM role permissions
- [ ] Document key rotation procedure
- [ ] Set up monitoring dashboard

### Regular Maintenance

- [ ] Rotate CloudFront keys quarterly
- [ ] Review CloudWatch logs weekly
- [ ] Update dependencies monthly
- [ ] Audit IAM permissions quarterly
- [ ] Review CloudTrail events monthly
- [ ] Test disaster recovery annually

## Additional Resources

- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [CloudFront Security](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/security.html)
- [S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [Lambda Security](https://docs.aws.amazon.com/lambda/latest/dg/lambda-security.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

## Reporting Security Issues

If you discover a security vulnerability, please email security@example.com instead of opening a public issue.

---

**Remember: Security is a continuous process, not a one-time setup!**

