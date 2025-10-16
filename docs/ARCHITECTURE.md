# Architecture Documentation

## Overview

This document provides detailed architecture information for the CloudFront Signed URLs Demo, with special focus on custom domain support.

## High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                          Client Application                       │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             │ HTTPS
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                      API Gateway (REST API)                       │
│              https://xxx.execute-api.us-east-1.amazonaws.com      │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             │ Invoke
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                        Lambda Function                            │
│                  (Generate Signed URLs)                           │
│                                                                   │
│  ┌─────────────────┐      ┌──────────────────┐                  │
│  │ Get Private Key │─────▶│ Secrets Manager  │                  │
│  └─────────────────┘      └──────────────────┘                  │
│                                                                   │
│  ┌─────────────────┐      ┌──────────────────┐                  │
│  │ Store Metadata  │─────▶│   DynamoDB       │                  │
│  └─────────────────┘      └──────────────────┘                  │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             │ Return Signed URL
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                          Client Application                       │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             │ PUT/GET with Signed URL
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                      CloudFront Distribution                      │
│                    https://cdn-demo.pe-labs.com                   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Signed URL Validation                        │   │
│  │  1. Verify signature with public key                      │   │
│  │  2. Check expiration time                                 │   │
│  │  3. Validate resource path                                │   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             │ Origin Request (if valid)
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                         S3 Bucket (Private)                       │
│                    pe-labs-cfn-signed-demo-161025                 │
│                                                                   │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐    │
│  │  uploads/      │  │  downloads/    │  │  metadata/     │    │
│  └────────────────┘  └────────────────┘  └────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

## Custom Domain Support

### ✅ Confirmed Working with Custom DNS

The infrastructure fully supports custom domains through:

1. **Route53 Hosted Zone**
   - Manages DNS for your domain
   - Creates CNAME records pointing to CloudFront

2. **ACM Certificate**
   - SSL/TLS certificate for custom domain
   - Automatically validated via DNS
   - Deployed to CloudFront (us-east-1 required)

3. **CloudFront Custom Domain**
   - Alternate domain names (CNAMEs)
   - Uses ACM certificate
   - Supports signed URLs with custom domain

### Custom Domain Flow

```
User Request
    │
    ▼
https://cdn-demo.pe-labs.com/uploads/file.pdf?Policy=...&Signature=...&Key-Pair-Id=...
    │
    ▼
┌────────────────────────────────────────┐
│         Route53 DNS Resolution          │
│  cdn-demo.pe-labs.com → CloudFront     │
└────────────────┬───────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────┐
│      CloudFront Distribution            │
│  - Validates DNS matches CNAME          │
│  - Terminates TLS with ACM cert         │
│  - Validates signed URL signature       │
└────────────────┬───────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────┐
│          S3 Origin (Private)            │
│  - Accessed via OAC                     │
│  - No public access                     │
└────────────────────────────────────────┘
```

### DNS Configuration

**Scenario 1: Route53 Manages Your Domain**

If your domain is already in Route53:
```hcl
custom_domain_enabled = true
domain_name          = "pe-labs.com"
subdomain            = "cdn-demo"
```

Terraform will:
- Find existing hosted zone
- Create ACM certificate
- Validate certificate via DNS
- Create CloudFront distribution with custom domain
- Create CNAME record pointing to CloudFront

**Scenario 2: External DNS Provider**

If your domain is managed elsewhere (e.g., GoDaddy, Cloudflare):

1. Deploy infrastructure with `custom_domain_enabled = false`
2. Get CloudFront distribution domain from outputs
3. Create CNAME record in your DNS provider:
   ```
   cdn-demo.pe-labs.com → d1234abcd.cloudfront.net
   ```
4. Request ACM certificate manually
5. Update Terraform to use the certificate

**Scenario 3: Subdomain Delegation**

Delegate a subdomain to Route53:

1. Create Route53 hosted zone for subdomain
2. Get nameservers from Route53
3. Create NS records in parent domain:
   ```
   cdn-demo.pe-labs.com NS ns-1234.awsdns-30.org
   cdn-demo.pe-labs.com NS ns-5678.awsdns-42.co.uk
   ```
4. Deploy with Terraform

## CloudFront Signed URLs

### How Signed URLs Work

```
1. Lambda generates policy:
{
  "Statement": [{
    "Resource": "https://cdn-demo.pe-labs.com/uploads/file.pdf",
    "Condition": {
      "DateLessThan": {"AWS:EpochTime": 1697654321}
    }
  }]
}

2. Lambda signs policy with private key (RSA-SHA1)

3. Lambda creates signed URL:
https://cdn-demo.pe-labs.com/uploads/file.pdf?
  Policy=<base64-encoded-policy>&
  Signature=<base64-encoded-signature>&
  Key-Pair-Id=K27M0SUQ8BJ2RL

4. Client uses signed URL

5. CloudFront validates:
   - Signature matches (using public key)
   - Current time < expiration time
   - Resource path matches
```

### Key Pair Management

```
┌──────────────────────────────────────────┐
│        Private Key (PKCS#1)              │
│  -----BEGIN RSA PRIVATE KEY-----         │
│  MIIEpAIBAAKCAQEA...                     │
│  -----END RSA PRIVATE KEY-----           │
│                                          │
│  Stored in: AWS Secrets Manager          │
│  Encryption: AWS KMS                     │
│  Access: Lambda execution role only      │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│        Public Key                         │
│  -----BEGIN PUBLIC KEY-----               │
│  MIIBIjANBgkqhkiG...                     │
│  -----END PUBLIC KEY-----                │
│                                          │
│  Stored in: CloudFront                   │
│  ID: K27M0SUQ8BJ2RL                      │
│  Associated with: Key Group              │
└──────────────────────────────────────────┘
```

## Components

### 1. API Gateway

**Type:** REST API (not HTTP API)

**Endpoints:**
- `POST /api/files/upload` - Generate upload URL
- `GET /api/files` - List files
- `GET /api/files/download/{id}` - Generate download URL
- `DELETE /api/files/{id}` - Delete file
- `GET /api/config` - Get configuration

**Integration:** Lambda proxy integration

**Features:**
- CORS enabled
- Throttling configured
- CloudWatch logging
- Custom domain (optional)

### 2. Lambda Function

**Runtime:** Python 3.11

**Memory:** 512 MB

**Timeout:** 30 seconds

**Environment Variables:**
- `BUCKET_NAME` - S3 bucket name
- `TABLE_NAME` - DynamoDB table name
- `CLOUDFRONT_DOMAIN` - Custom domain (e.g., cdn-demo.pe-labs.com)
- `CLOUDFRONT_KEY_PAIR_ID` - Public key ID
- `PRIVATE_KEY_SECRET_ARN` - Secrets Manager ARN
- `UPLOAD_EXPIRATION` - Upload URL expiration (seconds)
- `DOWNLOAD_EXPIRATION` - Download URL expiration (seconds)

**Dependencies:**
- `boto3` - AWS SDK
- `cryptography` - RSA signing

**Key Features:**
- Private key caching (per container)
- CloudFront signed URL generation
- DynamoDB metadata storage
- Error handling and logging

### 3. CloudFront Distribution

**Origin:** S3 bucket (private)

**Origin Access:** Origin Access Control (OAC)

**Cache Behavior:**
- Default TTL: 0 (no caching for signed URLs)
- Allowed Methods: GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE
- Viewer Protocol: Redirect HTTP to HTTPS
- Compress: Yes

**Custom Domain:**
- Alternate domain names: cdn-demo.pe-labs.com
- SSL Certificate: ACM certificate
- TLS version: TLSv1.2_2021

**Signed URLs:**
- Trusted key groups: cloudfront-signedurl-demo-key-group
- Public key: K27M0SUQ8BJ2RL

### 4. S3 Bucket

**Name:** pe-labs-cfn-signed-demo-161025

**Access:** Private (no public access)

**Features:**
- Versioning enabled
- Encryption at rest (AES-256)
- CORS configured
- Lifecycle policies (optional)

**Bucket Policy:**
- Allow CloudFront OAC only
- Deny all other access

### 5. DynamoDB Table

**Name:** cloudfront-signedurl-demo-files-metadata

**Primary Key:** file_id (String)

**Attributes:**
- `file_id` - Unique identifier
- `original_filename` - Original filename
- `object_key` - S3 object key
- `content_type` - MIME type
- `upload_url_generated_at` - Timestamp
- `status` - Upload status
- `ttl` - Time to live (automatic deletion)

**Billing:** On-demand

**Features:**
- TTL enabled (24 hours)
- Encryption at rest
- Point-in-time recovery

### 6. Secrets Manager

**Secret Name:** cloudfront-signedurl-demo-cloudfront-private-key

**Content:** CloudFront private key (PKCS#1 format)

**Encryption:** AWS KMS

**Access:** Lambda execution role only

**Rotation:** Manual (recommended quarterly)

## Security Architecture

### Defense in Depth

```
Layer 1: Network
  - HTTPS only
  - CloudFront WAF (optional)
  - API Gateway throttling

Layer 2: Authentication
  - CloudFront signed URLs
  - Time-limited access
  - Signature validation

Layer 3: Authorization
  - IAM roles (least privilege)
  - S3 bucket policies
  - CloudFront OAC

Layer 4: Data Protection
  - Encryption in transit (TLS)
  - Encryption at rest (S3, DynamoDB, Secrets Manager)
  - Private key in Secrets Manager

Layer 5: Monitoring
  - CloudWatch Logs
  - CloudTrail
  - GuardDuty (optional)
```

## Scalability

### Auto-Scaling Components

- **Lambda:** Automatic scaling (up to 1000 concurrent executions)
- **API Gateway:** Handles 10,000 requests/second
- **CloudFront:** Global edge network, unlimited scale
- **S3:** Unlimited storage, 5,500 GET/3,500 PUT per second per prefix
- **DynamoDB:** On-demand scaling

### Performance Optimization

1. **Lambda Cold Start:**
   - Private key caching reduces latency
   - Provisioned concurrency (optional)

2. **CloudFront:**
   - Global edge locations
   - HTTP/2 and HTTP/3 support
   - Compression enabled

3. **S3:**
   - Transfer acceleration (optional)
   - Multipart upload for large files

## Cost Optimization

### Cost Breakdown

**Fixed Costs (Monthly):**
- Route53 Hosted Zone: $0.50
- Secrets Manager: $0.40
- **Total Fixed:** ~$0.90/month

**Variable Costs (per 1M requests):**
- API Gateway: $3.50
- Lambda: $2.00
- CloudFront: $85 (per TB transfer)
- S3: $0.40 (GET) + $5.00 (PUT)
- DynamoDB: $1.25

**Optimization Tips:**
- Use CloudFront caching for static content
- Set appropriate DynamoDB TTL
- Use S3 Intelligent-Tiering
- Monitor and delete unused files

## Disaster Recovery

### Backup Strategy

- **S3:** Versioning + Cross-region replication (optional)
- **DynamoDB:** Point-in-time recovery + On-demand backups
- **Secrets Manager:** Automatic replication to multiple AZs
- **Terraform State:** Remote backend with versioning

### Recovery Procedures

**Scenario 1: S3 Bucket Deletion**
- Restore from versioning
- Or restore from cross-region replica

**Scenario 2: DynamoDB Table Deletion**
- Restore from point-in-time recovery
- Or restore from on-demand backup

**Scenario 3: Key Compromise**
- Generate new key pair
- Update Secrets Manager
- Update CloudFront public key
- Old signed URLs stop working automatically

## Monitoring & Observability

### CloudWatch Dashboards

**Recommended Metrics:**
- Lambda invocations, errors, duration
- API Gateway requests, 4xx, 5xx errors
- CloudFront requests, bytes downloaded
- S3 storage, requests
- DynamoDB read/write capacity

### Alarms

**Critical Alarms:**
- Lambda errors > 10 in 5 minutes
- API Gateway 5xx > 5 in 5 minutes
- CloudFront 5xx > 1% of requests

**Warning Alarms:**
- Lambda duration > 10 seconds
- API Gateway 4xx > 100 in 5 minutes
- DynamoDB throttling

## Future Enhancements

### Planned Features

1. **Authentication**
   - Okta integration
   - JWT validation
   - User-specific file access

2. **Frontend Application**
   - React UI
   - Drag-and-drop upload
   - Progress indicators

3. **Advanced Features**
   - File versioning
   - File sharing with expiring links
   - Thumbnail generation
   - Virus scanning

4. **Multi-Region**
   - Active-active deployment
   - Global DynamoDB tables
   - Cross-region S3 replication

---

**Architecture Version:** 2.0  
**Last Updated:** October 16, 2025  
**Status:** Production Ready ✅

