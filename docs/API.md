# CloudFront Signed URLs API Documentation

## Base URL
```
https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod
```

## Endpoints

### 1. Generate Upload URL

Generate a CloudFront signed URL for uploading a file.

**Endpoint:** `POST /api/files/upload`

**Request Body:**
```json
{
  "filename": "document.pdf",
  "contentType": "application/pdf"
}
```

**Response:** `200 OK`
```json
{
  "uploadUrl": "https://cdn-demo.pe-labs.com/uploads/abc123_document.pdf?Policy=...&Signature=...&Key-Pair-Id=...",
  "fileId": "abc123_document.pdf",
  "filename": "abc123_document.pdf",
  "expiresIn": 900,
  "method": "PUT",
  "headers": {
    "Content-Type": "application/pdf"
  }
}
```

**Example:**
```bash
curl -X POST \
  "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/upload" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.txt","contentType":"text/plain"}' | jq '.'
```

**Upload File:**
```bash
# Use the uploadUrl from the response
curl -X PUT \
  -H "Content-Type: text/plain" \
  --data-binary "@/path/to/file.txt" \
  "<UPLOAD_URL>"
```

---

### 2. List Files

List all uploaded files.

**Endpoint:** `GET /api/files`

**Response:** `200 OK`
```json
{
  "files": [
    {
      "fileId": "abc123_document.pdf",
      "filename": "document.pdf",
      "contentType": "application/pdf",
      "uploadedAt": "2025-10-16T10:30:00.000Z",
      "status": "pending"
    }
  ],
  "count": 1
}
```

**Example:**
```bash
curl "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files" | jq '.'
```

---

### 3. Generate Download URL

Generate a CloudFront signed URL for downloading a file.

**Endpoint:** `GET /api/files/download/{fileId}`

**Path Parameters:**
- `fileId` - The unique file identifier returned from upload

**Response:** `200 OK`
```json
{
  "downloadUrl": "https://cdn-demo.pe-labs.com/uploads/abc123_document.pdf?Policy=...&Signature=...&Key-Pair-Id=...",
  "filename": "document.pdf",
  "fileId": "abc123_document.pdf",
  "expiresIn": 3600
}
```

**Example:**
```bash
curl "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/download/abc123_document.pdf" | jq '.'
```

**Download File:**
```bash
# Use the downloadUrl from the response
curl "<DOWNLOAD_URL>" -o downloaded_file.pdf
```

---

### 4. Delete File

Delete a file from S3 and DynamoDB.

**Endpoint:** `DELETE /api/files/{fileId}`

**Path Parameters:**
- `fileId` - The unique file identifier

**Response:** `200 OK`
```json
{
  "message": "File deleted successfully",
  "fileId": "abc123_document.pdf"
}
```

**Example:**
```bash
curl -X DELETE \
  "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/abc123_document.pdf" | jq '.'
```

---

### 5. Get Configuration

Get API configuration information.

**Endpoint:** `GET /api/config`

**Response:** `200 OK`
```json
{
  "cloudfront": {
    "domain": "cdn-demo.pe-labs.com",
    "keyPairId": "K27M0SUQ8BJ2RL"
  },
  "s3": {
    "bucket": "pe-labs-cfn-signed-demo-161025"
  },
  "dynamodb": {
    "table": "cloudfront-signedurl-demo-files-metadata"
  },
  "expiration": {
    "upload": 900,
    "download": 3600
  }
}
```

**Example:**
```bash
curl "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/config" | jq '.'
```

---

## Error Responses

### 400 Bad Request
```json
{
  "error": "Missing filename"
}
```

### 404 Not Found
```json
{
  "error": "File not found"
}
```

### 500 Internal Server Error
```json
{
  "error": "Failed to generate upload URL",
  "message": "Detailed error message"
}
```

---

## Complete Upload/Download Flow

### Upload Flow

```bash
# 1. Generate upload URL
RESPONSE=$(curl -s -X POST \
  "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/upload" \
  -H "Content-Type: application/json" \
  -d '{"filename":"myfile.txt","contentType":"text/plain"}')

echo "$RESPONSE" | jq '.'

# Extract upload URL and file ID
UPLOAD_URL=$(echo "$RESPONSE" | jq -r '.uploadUrl')
FILE_ID=$(echo "$RESPONSE" | jq -r '.fileId')

echo "Upload URL: $UPLOAD_URL"
echo "File ID: $FILE_ID"

# 2. Create test file
echo "Hello CloudFront!" > /tmp/myfile.txt

# 3. Upload file
curl -X PUT \
  -H "Content-Type: text/plain" \
  --data-binary "@/tmp/myfile.txt" \
  "$UPLOAD_URL"

echo "File uploaded successfully!"
```

### Download Flow

```bash
# 1. Generate download URL
RESPONSE=$(curl -s \
  "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/download/$FILE_ID")

echo "$RESPONSE" | jq '.'

# Extract download URL
DOWNLOAD_URL=$(echo "$RESPONSE" | jq -r '.downloadUrl')

echo "Download URL: $DOWNLOAD_URL"

# 2. Download file
curl "$DOWNLOAD_URL" -o /tmp/downloaded_file.txt

# 3. Verify content
cat /tmp/downloaded_file.txt
```

---

## Legacy Endpoints (Backward Compatibility)

The following legacy endpoints are still supported:

- `POST /api/files/generate-upload-url` → Use `POST /api/files/upload` instead
- `GET /api/files/generate-download-url/{filename}` → Use `GET /api/files/download/{fileId}` instead
- `GET /api/files/list` → Use `GET /api/files` instead
- `DELETE /api/files/delete/{filename}` → Use `DELETE /api/files/{fileId}` instead

---

## CORS Support

All endpoints support CORS with the following headers:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Headers: Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token
Access-Control-Allow-Methods: GET,POST,PUT,DELETE,OPTIONS
```

---

## Rate Limits

- Upload URL expiration: 15 minutes (900 seconds)
- Download URL expiration: 1 hour (3600 seconds)
- DynamoDB TTL: 24 hours for file metadata

---

## Security

- All file operations use CloudFront signed URLs
- Private key stored securely in AWS Secrets Manager
- S3 bucket is private (no public access)
- CloudFront validates all signed URL requests
- Time-limited access (URLs expire)

---

## Integration Examples

### JavaScript/TypeScript

```javascript
// Upload file
async function uploadFile(file) {
  // 1. Get upload URL
  const response = await fetch(
    'https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/upload',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        filename: file.name,
        contentType: file.type
      })
    }
  );
  
  const { uploadUrl, fileId } = await response.json();
  
  // 2. Upload file to CloudFront
  await fetch(uploadUrl, {
    method: 'PUT',
    headers: { 'Content-Type': file.type },
    body: file
  });
  
  return fileId;
}

// Download file
async function downloadFile(fileId) {
  // 1. Get download URL
  const response = await fetch(
    `https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/download/${fileId}`
  );
  
  const { downloadUrl, filename } = await response.json();
  
  // 2. Download file
  window.location.href = downloadUrl;
  // Or use fetch to get the file content
}
```

### Python

```python
import requests

# Upload file
def upload_file(filename, content_type='text/plain'):
    # 1. Get upload URL
    response = requests.post(
        'https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/upload',
        json={'filename': filename, 'contentType': content_type}
    )
    data = response.json()
    
    # 2. Upload file
    with open(filename, 'rb') as f:
        requests.put(
            data['uploadUrl'],
            data=f,
            headers={'Content-Type': content_type}
        )
    
    return data['fileId']

# Download file
def download_file(file_id, output_path):
    # 1. Get download URL
    response = requests.get(
        f'https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/download/{file_id}'
    )
    data = response.json()
    
    # 2. Download file
    file_response = requests.get(data['downloadUrl'])
    with open(output_path, 'wb') as f:
        f.write(file_response.content)
```

---

## Monitoring

### CloudWatch Logs

Lambda function logs are available in:
```
/aws/lambda/cloudfront-signedurl-demo-api
```

View logs:
```bash
aws logs tail /aws/lambda/cloudfront-signedurl-demo-api --follow
```

### Metrics

Monitor these CloudWatch metrics:
- Lambda invocations
- Lambda errors
- Lambda duration
- API Gateway 4xx/5xx errors
- API Gateway latency

---

## Troubleshooting

### Upload fails with "Access Denied"
- Check private key format (must be PKCS#1)
- Verify private key matches public key in CloudFront
- Ensure CloudFront signed URL hasn't expired

### Download returns 404
- Verify file exists in DynamoDB
- Check S3 bucket for the file
- Ensure correct fileId is used

### CORS errors in browser
- Verify S3 bucket CORS configuration
- Check CloudFront origin settings
- Ensure API Gateway has CORS enabled

---

## Support

For issues or questions:
1. Check Lambda CloudWatch logs
2. Verify CloudFront distribution status
3. Test API endpoints with curl
4. Review this documentation

---

**API Version:** 2.0  
**Last Updated:** October 16, 2025  
**Base URL:** https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod

