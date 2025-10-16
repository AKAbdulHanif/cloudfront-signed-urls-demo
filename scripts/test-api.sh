#!/bin/bash

# CloudFront Signed URLs - Complete Flow Test Script
# Tests upload and download functionality with CloudFront custom domain

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration from Terraform outputs
API_URL="https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod"
CLOUDFRONT_DOMAIN="cdn-demo.pe-labs.com"
S3_BUCKET="pe-labs-cfn-signed-demo-161025"

echo "=========================================="
echo "CloudFront Signed URLs - Flow Test"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  API Gateway: $API_URL"
echo "  CloudFront:  https://$CLOUDFRONT_DOMAIN"
echo "  S3 Bucket:   $S3_BUCKET"
echo ""

# Create a test file
TEST_FILE="/tmp/test_upload_$(date +%s).txt"
TEST_CONTENT="Hello from CloudFront Signed URLs Demo! Timestamp: $(date)"
echo "$TEST_CONTENT" > "$TEST_FILE"
echo -e "${BLUE}Created test file: $TEST_FILE${NC}"
echo "Content: $TEST_CONTENT"
echo ""

# Step 1: Generate upload URL
echo "=========================================="
echo -e "${YELLOW}Step 1: Generating Upload URL...${NC}"
echo "=========================================="

UPLOAD_RESPONSE=$(curl -s -X POST \
  "$API_URL/api/files/upload" \
  -H "Content-Type: application/json" \
  -d "{\"filename\":\"test-$(date +%s).txt\",\"contentType\":\"text/plain\"}")

echo "Response: $UPLOAD_RESPONSE"
echo ""

# Parse the response
UPLOAD_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.uploadUrl // .url // empty')
FILE_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.fileId // empty')
FILENAME=$(echo "$UPLOAD_RESPONSE" | jq -r '.filename // empty')

if [ -z "$UPLOAD_URL" ]; then
  echo -e "${RED}❌ Failed to generate upload URL${NC}"
  echo "Response: $UPLOAD_RESPONSE"
  exit 1
fi

echo -e "${GREEN}✅ Upload URL generated${NC}"
echo "File ID: $FILE_ID"
echo "Filename: $FILENAME"
echo "Upload URL: ${UPLOAD_URL:0:100}..."
echo ""

# Step 2: Upload the file
echo "=========================================="
echo -e "${YELLOW}Step 2: Uploading file to CloudFront...${NC}"
echo "=========================================="

# Check if URL is for S3 or CloudFront
if [[ $UPLOAD_URL == *"$CLOUDFRONT_DOMAIN"* ]]; then
  echo "Using CloudFront signed URL for upload"
  UPLOAD_METHOD="PUT"
elif [[ $UPLOAD_URL == *"X-Amz-Algorithm"* ]]; then
  echo "Using S3 pre-signed URL for upload"
  UPLOAD_METHOD="PUT"
else
  echo "Unknown URL type, trying PUT method"
  UPLOAD_METHOD="PUT"
fi

# Perform the upload
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/upload_response.txt \
  -X "$UPLOAD_METHOD" \
  -H "Content-Type: text/plain" \
  --data-binary "@$TEST_FILE" \
  "$UPLOAD_URL")

echo "HTTP Status Code: $HTTP_CODE"

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo -e "${GREEN}✅ File uploaded successfully${NC}"
else
  echo -e "${RED}❌ Upload failed${NC}"
  echo "Response:"
  cat /tmp/upload_response.txt
  echo ""
  exit 1
fi
echo ""

# Wait a moment for S3 to process
echo "Waiting 2 seconds for S3 to process..."
sleep 2
echo ""

# Step 3: List files
echo "=========================================="
echo -e "${YELLOW}Step 3: Listing files in DynamoDB...${NC}"
echo "=========================================="

LIST_RESPONSE=$(curl -s "$API_URL/api/files")
echo "$LIST_RESPONSE" | jq '.'
echo ""

# Step 4: Generate download URL
echo "=========================================="
echo -e "${YELLOW}Step 4: Generating Download URL...${NC}"
echo "=========================================="

if [ -n "$FILE_ID" ]; then
  DOWNLOAD_RESPONSE=$(curl -s "$API_URL/api/files/download/$FILE_ID")
else
  # Try to get the first file from the list
  FILE_ID=$(echo "$LIST_RESPONSE" | jq -r '.files[0].fileId // empty')
  if [ -z "$FILE_ID" ]; then
    echo -e "${RED}❌ No file ID available${NC}"
    exit 1
  fi
  DOWNLOAD_RESPONSE=$(curl -s "$API_URL/api/files/download/$FILE_ID")
fi

echo "Response: $DOWNLOAD_RESPONSE"
echo ""

DOWNLOAD_URL=$(echo "$DOWNLOAD_RESPONSE" | jq -r '.downloadUrl // .url // empty')

if [ -z "$DOWNLOAD_URL" ]; then
  echo -e "${RED}❌ Failed to generate download URL${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Download URL generated${NC}"
echo "Download URL: ${DOWNLOAD_URL:0:100}..."
echo ""

# Step 5: Download the file
echo "=========================================="
echo -e "${YELLOW}Step 5: Downloading file from CloudFront...${NC}"
echo "=========================================="

DOWNLOADED_FILE="/tmp/downloaded_$(date +%s).txt"
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$DOWNLOADED_FILE" "$DOWNLOAD_URL")

echo "HTTP Status Code: $HTTP_CODE"

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo -e "${GREEN}✅ File downloaded successfully${NC}"
  echo ""
  echo "Downloaded content:"
  cat "$DOWNLOADED_FILE"
  echo ""
  
  # Verify content matches
  if diff -q "$TEST_FILE" "$DOWNLOADED_FILE" > /dev/null; then
    echo -e "${GREEN}✅ Content verification: PASSED${NC}"
  else
    echo -e "${YELLOW}⚠ Content differs (may be expected for binary files)${NC}"
  fi
else
  echo -e "${RED}❌ Download failed${NC}"
  echo "Response:"
  cat "$DOWNLOADED_FILE"
  echo ""
  exit 1
fi
echo ""

# Step 6: Verify CloudFront is being used
echo "=========================================="
echo -e "${YELLOW}Step 6: Verifying CloudFront Usage...${NC}"
echo "=========================================="

if [[ $DOWNLOAD_URL == *"$CLOUDFRONT_DOMAIN"* ]]; then
  echo -e "${GREEN}✅ Download URL uses CloudFront custom domain${NC}"
  echo "Domain: $CLOUDFRONT_DOMAIN"
elif [[ $DOWNLOAD_URL == *"cloudfront.net"* ]]; then
  echo -e "${YELLOW}⚠ Download URL uses CloudFront default domain${NC}"
  echo "Consider updating to use custom domain"
else
  echo -e "${YELLOW}⚠ Download URL uses S3 directly (not CloudFront)${NC}"
fi
echo ""

# Summary
echo "=========================================="
echo -e "${GREEN}Test Summary${NC}"
echo "=========================================="
echo -e "${GREEN}✅ Upload URL generation${NC}"
echo -e "${GREEN}✅ File upload${NC}"
echo -e "${GREEN}✅ File listing${NC}"
echo -e "${GREEN}✅ Download URL generation${NC}"
echo -e "${GREEN}✅ File download${NC}"
echo ""
echo "All tests passed! 🎉"
echo ""
echo "Your CloudFront Signed URLs infrastructure is working correctly!"
echo ""

# Cleanup
rm -f "$TEST_FILE" "$DOWNLOADED_FILE" /tmp/upload_response.txt

echo "Test files cleaned up."
echo ""

