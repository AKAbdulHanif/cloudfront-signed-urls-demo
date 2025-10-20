# CloudFront Signer Lambda (Java)

This is a Java 11 Lambda function that generates CloudFront signed URLs for secure file uploads and downloads. It supports key rotation through AWS Systems Manager Parameter Store.

## Features

- **CloudFront Signed URLs:** Generates time-limited signed URLs for both upload (PUT) and download (GET) operations
- **Key Rotation Support:** Automatically reads the active key configuration from SSM Parameter Store
- **Caching:** Caches key configuration in memory for 5 minutes to reduce AWS API calls
- **DynamoDB Integration:** Stores and retrieves file metadata
- **CORS Support:** Includes CORS headers for browser-based applications

## Architecture

The Lambda function integrates with the following AWS services:

- **SSM Parameter Store:** Stores the active key pair ID and secret ARN
- **Secrets Manager:** Stores the private keys for signing URLs
- **DynamoDB:** Stores file metadata (file ID, filename, S3 key, upload timestamp)
- **CloudFront:** Validates signed URLs and serves content

## Building

### Prerequisites

- Java 11 or higher
- Maven 3.6 or higher

### Build Instructions

```bash
# Build the Lambda function
./build.sh

# The output JAR will be located at:
# target/cloudfront-signer-lambda-1.0.0.jar
```

## Deployment

### 1. Upload to AWS Lambda

```bash
# Using AWS CLI
aws lambda create-function \
  --function-name cloudfront-signer-lambda \
  --runtime java11 \
  --role arn:aws:iam::ACCOUNT_ID:role/lambda-execution-role \
  --handler com.example.CloudFrontSignerHandler::handleRequest \
  --zip-file fileb://target/cloudfront-signer-lambda-1.0.0.jar \
  --timeout 30 \
  --memory-size 512
```

### 2. Configure Environment Variables

The Lambda function requires the following environment variables:

| Variable | Description | Example |
| --- | --- | --- |
| `CLOUDFRONT_DOMAIN` | Custom domain for CloudFront distribution | `cdn-demo.pe-labs.com` |
| `BUCKET_NAME` | S3 bucket name | `my-bucket` |
| `TABLE_NAME` | DynamoDB table name | `file-metadata` |
| `UPLOAD_EXPIRATION` | Upload URL expiration in seconds (default: 900) | `900` |
| `DOWNLOAD_EXPIRATION` | Download URL expiration in seconds (default: 3600) | `3600` |
| `ACTIVE_KEY_ID_PARAM` | SSM parameter for active key ID (default: `/cloudfront-signer/active-key-id`) | `/cloudfront-signer/active-key-id` |
| `ACTIVE_SECRET_ARN_PARAM` | SSM parameter for active secret ARN (default: `/cloudfront-signer/active-secret-arn`) | `/cloudfront-signer/active-secret-arn` |

### 3. Configure IAM Permissions

The Lambda execution role must have the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": [
        "arn:aws:ssm:REGION:ACCOUNT_ID:parameter/cloudfront-signer/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:REGION:ACCOUNT_ID:secret:cloudfront-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Scan"
      ],
      "Resource": [
        "arn:aws:dynamodb:REGION:ACCOUNT_ID:table/TABLE_NAME"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

## API Endpoints

The Lambda function is designed to be invoked via API Gateway with the following endpoints:

### 1. Generate Upload URL

**Endpoint:** `POST /api/files/upload`

**Request Body:**
```json
{
  "filename": "document.pdf",
  "contentType": "application/pdf"
}
```

**Response:**
```json
{
  "fileId": "550e8400-e29b-41d4-a716-446655440000",
  "uploadUrl": "https://cdn-demo.pe-labs.com/uploads/550e8400-e29b-41d4-a716-446655440000/document.pdf?Policy=...&Signature=...&Key-Pair-Id=...",
  "filename": "document.pdf",
  "expiresIn": "900"
}
```

### 2. Generate Download URL

**Endpoint:** `GET /api/files/download/{fileId}`

**Response:**
```json
{
  "fileId": "550e8400-e29b-41d4-a716-446655440000",
  "downloadUrl": "https://cdn-demo.pe-labs.com/uploads/550e8400-e29b-41d4-a716-446655440000/document.pdf?Expires=...&Signature=...&Key-Pair-Id=...",
  "filename": "document.pdf",
  "expiresIn": "3600"
}
```

### 3. List Files

**Endpoint:** `GET /api/files`

**Response:**
```json
{
  "files": [
    {
      "fileId": "550e8400-e29b-41d4-a716-446655440000",
      "filename": "document.pdf",
      "uploadedAt": "2025-10-19T10:30:00Z"
    }
  ]
}
```

## Key Rotation

The Lambda function supports zero-downtime key rotation. It reads the active key configuration from SSM Parameter Store on startup and caches it for 5 minutes.

### SSM Parameters

The following SSM parameters must be configured:

- `/cloudfront-signer/active-key-id`: The CloudFront public key ID (e.g., `K2PNHFE2BDB9MN`)
- `/cloudfront-signer/active-secret-arn`: The ARN of the Secrets Manager secret containing the private key

### Rotation Process

1. A rotation script updates the SSM parameters with the new key configuration
2. The Lambda function automatically picks up the new configuration on the next invocation (or after the 5-minute cache expires)
3. Old signed URLs remain valid until they expire (as long as the old key is still trusted by CloudFront)

See `docs/KEY_ROTATION_STRATEGY.md` for detailed rotation procedures.

## Testing

### Local Testing

You can test the Lambda function locally using AWS SAM or by creating a test harness.

### Integration Testing

```bash
# Test upload endpoint
curl -X POST https://API_GATEWAY_URL/api/files/upload \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.txt","contentType":"text/plain"}'

# Test download endpoint
curl https://API_GATEWAY_URL/api/files/download/FILE_ID

# Test list files endpoint
curl https://API_GATEWAY_URL/api/files
```

## Dependencies

The Lambda function uses the following key dependencies:

- **AWS SDK for Java v2:** For interacting with AWS services (SSM, Secrets Manager, DynamoDB)
- **AWS Lambda Java Core:** For Lambda runtime support
- **AWS Lambda Java Events:** For API Gateway event handling
- **Jackson:** For JSON serialization/deserialization
- **Bouncy Castle:** For PEM key parsing and cryptographic operations

## Performance Considerations

- **Cold Start:** Initial cold start takes ~3-5 seconds due to SDK initialization
- **Warm Invocations:** Subsequent invocations take ~100-200ms
- **Memory:** Recommended memory allocation is 512 MB
- **Timeout:** Recommended timeout is 30 seconds

## Security Best Practices

- **Private Keys:** Never log or expose private keys in CloudWatch Logs
- **IAM Permissions:** Follow the principle of least privilege for the Lambda execution role
- **Secrets Rotation:** Rotate CloudFront key pairs every 90 days
- **HTTPS Only:** Always use HTTPS for signed URLs
- **Short Expiration:** Use short expiration times for upload URLs (15 minutes) and reasonable times for download URLs (1 hour)

## Troubleshooting

### Issue: "Access Denied" when accessing SSM Parameter Store

**Solution:** Verify that the Lambda execution role has `ssm:GetParameter` permissions for the specified parameters.

### Issue: "Signature does not match" error from CloudFront

**Solution:** 
1. Verify that the public key in CloudFront matches the private key in Secrets Manager
2. Check that the SSM parameters point to the correct key pair ID and secret ARN
3. Ensure the private key is in PKCS#8 format (not PKCS#1)

### Issue: Lambda timeout

**Solution:** Increase the Lambda timeout to 30 seconds and ensure the Lambda has network access to AWS services (VPC configuration if applicable).

## License

MIT License - See LICENSE file for details

