# Testing CloudFront with Custom Domain

## Understanding the Architecture

### Two Separate Endpoints

Your infrastructure has **two different endpoints** serving different purposes:

```
┌─────────────────────────────────────────────────────────┐
│  API Gateway (Control Plane)                            │
│  https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com │
│                                                          │
│  Purpose: Generate signed URLs                          │
│  Used by: Your application backend                      │
│  Returns: Signed URLs pointing to CloudFront            │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  CloudFront (Data Plane)                                │
│  https://cdn-demo.pe-labs.com                           │
│                                                          │
│  Purpose: Serve files with signed URL validation        │
│  Used by: End users / browsers                          │
│  Validates: Signature, expiration, resource path        │
└─────────────────────────────────────────────────────────┘
```

### Why Two Endpoints?

**API Gateway** is for your application:
- Generates signed URLs
- Manages file metadata
- Lists files
- Deletes files
- **Does NOT serve actual files**

**CloudFront** is for file operations:
- Uploads files (PUT)
- Downloads files (GET)
- Validates signed URLs
- **Uses your custom domain**

## The Flow

### Upload Flow

```
1. Your App → API Gateway
   POST /api/files/upload
   {"filename": "document.pdf"}
   
2. API Gateway → Lambda
   Lambda generates signed URL:
   https://cdn-demo.pe-labs.com/uploads/abc123_document.pdf?Policy=...&Signature=...

3. Lambda → Your App
   Returns: {"uploadUrl": "https://cdn-demo.pe-labs.com/..."}

4. Your App → CloudFront (Custom Domain!)
   PUT https://cdn-demo.pe-labs.com/uploads/abc123_document.pdf?Policy=...
   Body: [file content]

5. CloudFront validates signature → S3
   File stored in S3 bucket
```

### Download Flow

```
1. Your App → API Gateway
   GET /api/files/download/abc123_document.pdf

2. API Gateway → Lambda
   Lambda generates signed URL:
   https://cdn-demo.pe-labs.com/uploads/abc123_document.pdf?Policy=...&Signature=...

3. Lambda → Your App
   Returns: {"downloadUrl": "https://cdn-demo.pe-labs.com/..."}

4. User's Browser → CloudFront (Custom Domain!)
   GET https://cdn-demo.pe-labs.com/uploads/abc123_document.pdf?Policy=...

5. CloudFront validates signature → S3
   File retrieved from S3 and served to user
```

## Testing with Custom Domain

### ✅ What You Should Test

Run the provided test script:

```bash
./test-with-custom-domain.sh
```

This script verifies:
1. ✅ API Gateway generates signed URLs
2. ✅ Signed URLs point to your custom domain (`cdn-demo.pe-labs.com`)
3. ✅ Files upload through custom domain
4. ✅ Files download through custom domain
5. ✅ Content integrity is maintained
6. ✅ Signed URL components are present

### Expected Output

```
==========================================
CloudFront Signed URLs - Custom Domain Test
==========================================

API Gateway: https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod
CloudFront:  https://cdn-demo.pe-labs.com

Step 1: Generate Upload URL
✓ Upload URL uses custom domain: cdn-demo.pe-labs.com

Step 2: Upload File via CloudFront
✓ File uploaded successfully via cdn-demo.pe-labs.com (HTTP 200)

Step 3: List Files
[file metadata shown]

Step 4: Generate Download URL
✓ Download URL uses custom domain: cdn-demo.pe-labs.com

Step 5: Download File via CloudFront
✓ File downloaded successfully via cdn-demo.pe-labs.com (HTTP 200)

Step 6: Verify Content
✓ Content verification: PASSED

✓ All Tests Passed!
```

## Manual Testing

### Test Upload Manually

```bash
# 1. Generate upload URL
curl -X POST \
  "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/upload" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.txt","contentType":"text/plain"}' | jq '.'

# Response will include uploadUrl like:
# "uploadUrl": "https://cdn-demo.pe-labs.com/uploads/abc123_test.txt?Policy=...&Signature=...&Key-Pair-Id=..."

# 2. Upload file using the custom domain URL
echo "Hello CloudFront!" > test.txt
curl -X PUT \
  -H "Content-Type: text/plain" \
  --data-binary "@test.txt" \
  "https://cdn-demo.pe-labs.com/uploads/abc123_test.txt?Policy=...&Signature=...&Key-Pair-Id=..."
```

### Test Download Manually

```bash
# 1. Generate download URL
curl "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/download/abc123_test.txt" | jq '.'

# Response will include downloadUrl like:
# "downloadUrl": "https://cdn-demo.pe-labs.com/uploads/abc123_test.txt?Policy=...&Signature=...&Key-Pair-Id=..."

# 2. Download file using the custom domain URL
curl "https://cdn-demo.pe-labs.com/uploads/abc123_test.txt?Policy=...&Signature=...&Key-Pair-Id=..." -o downloaded.txt

# 3. Verify content
cat downloaded.txt
```

## Verifying Custom Domain

### Check DNS Resolution

```bash
# Verify DNS points to CloudFront
dig cdn-demo.pe-labs.com

# Should return CNAME pointing to CloudFront distribution
# cdn-demo.pe-labs.com. 300 IN CNAME d1234abcd.cloudfront.net.
```

### Check SSL Certificate

```bash
# Verify SSL certificate
openssl s_client -connect cdn-demo.pe-labs.com:443 -servername cdn-demo.pe-labs.com < /dev/null 2>/dev/null | openssl x509 -noout -text | grep Subject

# Should show your custom domain in certificate
```

### Check CloudFront Response Headers

```bash
# Upload a file first, then:
curl -I "https://cdn-demo.pe-labs.com/uploads/YOUR_FILE_ID?Policy=...&Signature=...&Key-Pair-Id=..."

# Look for CloudFront headers:
# X-Cache: Hit from cloudfront
# X-Amz-Cf-Id: ...
# Via: 1.1 ... (CloudFront)
```

## Common Issues

### Issue 1: URLs Don't Use Custom Domain

**Symptom:** Signed URLs contain `d1234abcd.cloudfront.net` instead of `cdn-demo.pe-labs.com`

**Cause:** Lambda environment variable `CLOUDFRONT_DOMAIN` is not set correctly

**Fix:**
```bash
# Check Lambda environment variable
aws lambda get-function-configuration \
  --function-name cloudfront-signedurl-demo-api \
  --query 'Environment.Variables.CLOUDFRONT_DOMAIN'

# Should return: "cdn-demo.pe-labs.com"

# If not, update it:
aws lambda update-function-configuration \
  --function-name cloudfront-signedurl-demo-api \
  --environment "Variables={CLOUDFRONT_DOMAIN=cdn-demo.pe-labs.com,...}"
```

### Issue 2: SSL Certificate Error

**Symptom:** `SSL certificate problem: unable to get local issuer certificate`

**Cause:** ACM certificate not properly configured or DNS not propagated

**Fix:**
1. Verify ACM certificate status in AWS Console
2. Check DNS propagation: `dig cdn-demo.pe-labs.com`
3. Wait for DNS propagation (can take up to 48 hours)

### Issue 3: 403 Forbidden

**Symptom:** Upload/download returns 403 Forbidden

**Possible Causes:**
1. Signed URL expired
2. Signature invalid (key mismatch)
3. Resource path doesn't match

**Fix:**
```bash
# Check if URL has expired
# Extract Policy from URL and decode:
POLICY="<base64-encoded-policy-from-url>"
echo "$POLICY" | base64 -d | jq '.'

# Check DateLessThan timestamp
# Compare with current time: date +%s

# Verify public key matches private key
aws cloudfront get-public-key --id K27M0SUQ8BJ2RL

# Verify private key in Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id arn:aws:secretsmanager:us-east-1:376129865674:secret:cloudfront-signedurl-demo-cloudfront-private-key-tcOixu
```

## Browser Testing

### Upload from Browser

```html
<!DOCTYPE html>
<html>
<head>
    <title>CloudFront Upload Test</title>
</head>
<body>
    <h1>Upload to CloudFront Custom Domain</h1>
    <input type="file" id="fileInput">
    <button onclick="uploadFile()">Upload</button>
    <div id="status"></div>

    <script>
        async function uploadFile() {
            const file = document.getElementById('fileInput').files[0];
            const status = document.getElementById('status');
            
            // 1. Get signed upload URL from API Gateway
            status.textContent = 'Getting upload URL...';
            const response = await fetch('https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/upload', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({
                    filename: file.name,
                    contentType: file.type
                })
            });
            
            const data = await response.json();
            console.log('Upload URL:', data.uploadUrl);
            
            // Verify URL uses custom domain
            if (data.uploadUrl.includes('cdn-demo.pe-labs.com')) {
                status.textContent = '✓ Upload URL uses custom domain\n';
            }
            
            // 2. Upload file to CloudFront custom domain
            status.textContent += 'Uploading to CloudFront...';
            const uploadResponse = await fetch(data.uploadUrl, {
                method: 'PUT',
                headers: {'Content-Type': file.type},
                body: file
            });
            
            if (uploadResponse.ok) {
                status.textContent += '\n✓ File uploaded successfully via ' + new URL(data.uploadUrl).hostname;
            } else {
                status.textContent += '\n✗ Upload failed: ' + uploadResponse.status;
            }
        }
    </script>
</body>
</html>
```

## Summary

### Key Points

1. **API Gateway** generates signed URLs (control plane)
2. **CloudFront** serves files with your custom domain (data plane)
3. **All file operations** go through `cdn-demo.pe-labs.com`
4. **Signed URLs** contain Policy, Signature, and Key-Pair-Id
5. **Time-limited** access (15 min upload, 1 hour download)

### Testing Checklist

- [ ] Run `./test-with-custom-domain.sh`
- [ ] Verify upload URLs contain `cdn-demo.pe-labs.com`
- [ ] Verify download URLs contain `cdn-demo.pe-labs.com`
- [ ] Test file upload through custom domain
- [ ] Test file download through custom domain
- [ ] Verify content integrity
- [ ] Check CloudFront response headers
- [ ] Test URL expiration
- [ ] Test with invalid signature (should fail)

### Success Criteria

✅ All signed URLs use custom domain (`cdn-demo.pe-labs.com`)  
✅ Files upload successfully through CloudFront  
✅ Files download successfully through CloudFront  
✅ Content integrity maintained  
✅ Signed URL validation working  
✅ SSL/TLS working with custom domain  

---

**Your custom domain is working! The test script proves it.** 🎉

