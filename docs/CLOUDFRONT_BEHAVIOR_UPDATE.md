# CloudFront Behavior Update - Enable PUT for Uploads

## Problem

Origin Access Control (OAC) only supports GET operations. When CloudFront tries to forward PUT requests to S3 with OAC enabled, S3 denies the request.

## Solution

Create two separate CloudFront cache behaviors:

1. **`/uploads/*`** - No OAC, allows PUT/POST/DELETE for uploads
2. **`/*` (default)** - With OAC, allows GET/HEAD for downloads

Both require CloudFront signed URLs for access control.

## Option 1: Update via AWS Console (Easiest)

### Step 1: Open CloudFront Distribution

1. Go to AWS Console → CloudFront
2. Click on distribution `E2G9NCP6YLJ6OF`
3. Go to **Behaviors** tab
4. Click **Create behavior**

### Step 2: Create Upload Behavior

**Path pattern**: `/uploads/*`

**Origin and origin groups**: Select your S3 origin

**Viewer protocol policy**: Redirect HTTP to HTTPS

**Allowed HTTP methods**: GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE

**Cache key and origin requests**:
- Query strings: All
- Headers: All
- Cookies: None

**Cache policy**: Create custom or use "CachingDisabled"
- Min TTL: 0
- Default TTL: 0  
- Max TTL: 0

**Origin request policy**: Create custom or use "AllViewers"
- Forward all headers

**Restrict viewer access**: Yes
- Trusted key groups: Select `cloudfront-signedurl-demo-key-group`

**Compress objects automatically**: No

Click **Create behavior**

### Step 3: Verify Behavior Priority

The `/uploads/*` behavior should be listed BEFORE the default `/*` behavior (priority 0).

If not, select it and click "Move up" to make it priority 0.

### Step 4: Wait for Deployment

Status will show "Deploying" for 10-15 minutes. Wait for "Deployed" status.

## Option 2: Update via AWS CLI (Automated)

```bash
# Run the provided script
./update-cloudfront-behaviors.sh

# Wait for deployment
aws cloudfront wait distribution-deployed --id E2G9NCP6YLJ6OF
```

## Option 3: Update via Terraform

Use the provided `cloudfront-behavior-update.tf` file:

```bash
# Add to your Terraform configuration
# Then apply
terraform plan
terraform apply
```

## After Update

### Test Upload

```bash
# Generate upload URL
UPLOAD_RESPONSE=$(curl -s -X POST \
  "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/upload" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.txt","contentType":"text/plain"}')

UPLOAD_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.uploadUrl')

# Upload file
echo "test content" > test.txt
curl -v -X PUT \
  -H "Content-Type: text/plain" \
  --data-binary "@test.txt" \
  "$UPLOAD_URL"

# Should return HTTP 200 (success) instead of 403 (access denied)
```

### Test Download

```bash
# Generate download URL
FILE_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.fileId')

DOWNLOAD_RESPONSE=$(curl -s \
  "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/download/$FILE_ID")

DOWNLOAD_URL=$(echo "$DOWNLOAD_RESPONSE" | jq -r '.downloadUrl')

# Download file
curl "$DOWNLOAD_URL"

# Should return file content
```

## Architecture After Update

```
Upload Flow:
Client → cdn-demo.pe-labs.com/uploads/* (signed URL)
       → CloudFront (no OAC, forwards PUT)
       → S3 bucket

Download Flow:
Client → cdn-demo.pe-labs.com/* (signed URL)
       → CloudFront (with OAC, secure GET)
       → S3 bucket
```

## Security

- **Uploads**: Protected by CloudFront signed URLs (time-limited, signed)
- **Downloads**: Protected by CloudFront signed URLs + OAC (double security)
- **S3 Bucket**: Private, only accessible via CloudFront
- **Customer Whitelist**: Only `cdn-demo.pe-labs.com` needed ✅

## Verification

After deployment, check the behaviors:

```bash
aws cloudfront get-distribution-config --id E2G9NCP6YLJ6OF \
  --query 'DistributionConfig.CacheBehaviors.Items[].PathPattern'
```

Should show: `["/uploads/*"]`

---

**Choose Option 1 (Console) for quickest update!**
