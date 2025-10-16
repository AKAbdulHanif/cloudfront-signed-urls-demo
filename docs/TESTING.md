# Manual Testing Guide - CloudFront Signed URLs

## Quick Test Commands

Use these commands to manually test your CloudFront signed URLs infrastructure.

### Configuration
```bash
API_URL="https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod"
CLOUDFRONT_DOMAIN="cdn-demo.pe-labs.com"
```

---

## Test 1: Generate Upload URL

```bash
curl -X POST \
  "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/upload" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.txt","contentType":"text/plain"}' | jq '.'
```

**Expected Response:**
```json
{
  "uploadUrl": "https://cdn-demo.pe-labs.com/...",
  "fileId": "abc123...",
  "filename": "test.txt",
  "expiresIn": 900
}
```

---

## Test 2: Upload a File

First, create a test file:
```bash
echo "Hello CloudFront!" > /tmp/test.txt
```

Then use the upload URL from Test 1:
```bash
# Replace <UPLOAD_URL> with the URL from Test 1
curl -X PUT \
  -H "Content-Type: text/plain" \
  --data-binary "@/tmp/test.txt" \
  "<UPLOAD_URL>"
```

**Expected Response:**
- HTTP 200 OK (empty body is normal for S3 PUT)

---

## Test 3: List Files

```bash
curl "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files" | jq '.'
```

**Expected Response:**
```json
{
  "files": [
    {
      "fileId": "abc123...",
      "filename": "test.txt",
      "uploadedAt": "2025-10-16T...",
      "size": 123,
      "contentType": "text/plain"
    }
  ]
}
```

---

## Test 4: Generate Download URL

```bash
# Replace <FILE_ID> with a fileId from Test 3
curl "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/download/<FILE_ID>" | jq '.'
```

**Expected Response:**
```json
{
  "downloadUrl": "https://cdn-demo.pe-labs.com/...",
  "filename": "test.txt",
  "expiresIn": 3600
}
```

---

## Test 5: Download the File

```bash
# Replace <DOWNLOAD_URL> with the URL from Test 4
curl "<DOWNLOAD_URL>" -o /tmp/downloaded.txt

# Verify content
cat /tmp/downloaded.txt
```

**Expected Output:**
```
Hello CloudFront!
```

---

## Automated Test Script

For a complete automated test, run:

```bash
./test_cloudfront_flow.sh
```

This script will:
1. ✅ Generate upload URL
2. ✅ Upload a test file
3. ✅ List files in DynamoDB
4. ✅ Generate download URL
5. ✅ Download the file
6. ✅ Verify content matches
7. ✅ Confirm CloudFront custom domain is used

---

## Troubleshooting

### Issue: "Access Denied" on upload
**Cause:** CloudFront signed URL signature is invalid

**Check:**
1. Private key format (must be PKCS#1)
2. Private key matches public key
3. Key pair ID is correct

**Fix:**
```bash
# Check private key format
aws secretsmanager get-secret-value \
  --secret-id arn:aws:secretsmanager:us-east-1:376129865674:secret:cloudfront-signedurl-demo-cloudfront-private-key-tcOixu \
  --query SecretString --output text | head -1

# Should show: -----BEGIN RSA PRIVATE KEY-----
# If it shows: -----BEGIN PRIVATE KEY----- then convert it
```

### Issue: "Access Denied" on download
**Cause:** Same as upload - signature issue

**Solution:** Same as above

### Issue: Upload works but uses S3 URL instead of CloudFront
**Cause:** Lambda is generating S3 pre-signed URLs instead of CloudFront signed URLs

**Check Lambda logs:**
```bash
aws logs tail /aws/lambda/cloudfront-signedurl-demo-api --follow
```

### Issue: 404 Not Found on download
**Cause:** File not in S3 or wrong key

**Verify file exists:**
```bash
aws s3 ls s3://pe-labs-cfn-signed-demo-161025/
```

### Issue: CORS errors in browser
**Cause:** S3 bucket CORS not configured

**Check CORS:**
```bash
aws s3api get-bucket-cors --bucket pe-labs-cfn-signed-demo-161025
```

---

## Verify CloudFront Configuration

### Check CloudFront Distribution
```bash
aws cloudfront get-distribution --id E2G9NCP6YLJ6OF | jq '.Distribution.DistributionConfig'
```

### Check CloudFront Public Key
```bash
aws cloudfront get-public-key --id K27M0SUQ8BJ2RL | jq '.'
```

### Check Key Group
```bash
aws cloudfront list-key-groups | jq '.KeyGroupList.Items[] | select(.KeyGroup.Name=="cloudfront-signedurl-demo-key-group")'
```

### Check Lambda Environment Variables
```bash
aws lambda get-function-configuration --function-name cloudfront-signedurl-demo-api | jq '.Environment.Variables'
```

Should show:
```json
{
  "CLOUDFRONT_DOMAIN": "cdn-demo.pe-labs.com",
  "CLOUDFRONT_KEY_PAIR_ID": "K27M0SUQ8BJ2RL",
  "PRIVATE_KEY_SECRET_ARN": "arn:aws:secretsmanager:...",
  "BUCKET_NAME": "pe-labs-cfn-signed-demo-161025",
  "TABLE_NAME": "cloudfront-signedurl-demo-files-metadata",
  "UPLOAD_EXPIRATION": "900",
  "DOWNLOAD_EXPIRATION": "3600"
}
```

---

## Success Criteria

✅ Upload URL contains `cdn-demo.pe-labs.com`  
✅ File uploads successfully via CloudFront URL  
✅ File appears in DynamoDB table  
✅ Download URL contains `cdn-demo.pe-labs.com`  
✅ File downloads successfully via CloudFront URL  
✅ Downloaded content matches uploaded content  
✅ URLs expire after configured time  

---

## Next Steps

After verifying everything works:

1. **Deploy Frontend Application**
   - Build React frontend with upload/download UI
   - Deploy to S3 + CloudFront
   - Configure API endpoint

2. **Add Authentication**
   - Implement Okta authentication
   - Add JWT validation in Lambda
   - Restrict API access

3. **Add Monitoring**
   - CloudWatch dashboards
   - CloudWatch alarms for errors
   - X-Ray tracing

4. **Production Hardening**
   - Enable WAF on CloudFront
   - Add rate limiting
   - Implement file scanning
   - Add encryption at rest

5. **Documentation**
   - API documentation
   - User guide
   - Operations runbook

