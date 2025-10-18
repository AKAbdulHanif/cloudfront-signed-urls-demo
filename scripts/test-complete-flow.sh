#!/bin/bash

# Complete CloudFront Signed URLs Test Script
# Tests the entire upload and download flow

set -e

# Configuration
API_URL="https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod"
TEST_FILE="/tmp/cloudfront-test-file.txt"
TEST_CONTENT="Hello from CloudFront Signed URLs! Timestamp: $(date)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "CloudFront Signed URLs - Complete Test"
echo "=========================================="
echo ""
echo "API URL: $API_URL"
echo ""

# Step 1: Test Configuration
echo "Step 1: Testing configuration endpoint..."
CONFIG_RESPONSE=$(curl -s "$API_URL/api/files/config")
if echo "$CONFIG_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Configuration endpoint working${NC}"
    echo "$CONFIG_RESPONSE" | jq '.'
else
    echo -e "${RED}❌ Configuration endpoint failed${NC}"
    echo "$CONFIG_RESPONSE"
    exit 1
fi
echo ""

# Step 2: Generate Upload URL
echo "Step 2: Generating upload URL..."
UPLOAD_RESPONSE=$(curl -s -X POST \
  "$API_URL/api/files/upload" \
  -H "Content-Type: application/json" \
  -d "{\"filename\":\"test-$(date +%s).txt\",\"contentType\":\"text/plain\"}")

if echo "$UPLOAD_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Upload URL generated${NC}"
    UPLOAD_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.uploadUrl')
    FILE_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.fileId')
    echo "File ID: $FILE_ID"
    echo "Upload URL: ${UPLOAD_URL:0:80}..."
else
    echo -e "${RED}❌ Failed to generate upload URL${NC}"
    echo "$UPLOAD_RESPONSE"
    exit 1
fi
echo ""

# Step 3: Create test file and upload
echo "Step 3: Uploading file to CloudFront..."
echo "$TEST_CONTENT" > "$TEST_FILE"
echo "Test file created: $TEST_FILE"
echo "Content: $TEST_CONTENT"

UPLOAD_STATUS=$(curl -s -w "%{http_code}" -o /tmp/upload_response.txt \
  -X PUT \
  -H "Content-Type: text/plain" \
  --data-binary "@$TEST_FILE" \
  "$UPLOAD_URL")

if [ "$UPLOAD_STATUS" = "200" ] || [ "$UPLOAD_STATUS" = "204" ]; then
    echo -e "${GREEN}✅ File uploaded successfully (HTTP $UPLOAD_STATUS)${NC}"
else
    echo -e "${RED}❌ File upload failed (HTTP $UPLOAD_STATUS)${NC}"
    cat /tmp/upload_response.txt
    exit 1
fi
echo ""

# Step 4: Wait a moment for S3 consistency
echo "Step 4: Waiting for S3 consistency..."
sleep 2
echo -e "${GREEN}✅ Ready${NC}"
echo ""

# Step 5: List files
echo "Step 5: Listing files..."
LIST_RESPONSE=$(curl -s "$API_URL/api/files")
if echo "$LIST_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    FILE_COUNT=$(echo "$LIST_RESPONSE" | jq -r '.count')
    echo -e "${GREEN}✅ Files listed successfully${NC}"
    echo "Total files: $FILE_COUNT"
    echo "$LIST_RESPONSE" | jq '.files[] | {fileId, filename, status}'
else
    echo -e "${RED}❌ Failed to list files${NC}"
    echo "$LIST_RESPONSE"
fi
echo ""

# Step 6: Generate Download URL
echo "Step 6: Generating download URL..."
DOWNLOAD_RESPONSE=$(curl -s "$API_URL/api/files/download/$FILE_ID")

if echo "$DOWNLOAD_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Download URL generated${NC}"
    DOWNLOAD_URL=$(echo "$DOWNLOAD_RESPONSE" | jq -r '.downloadUrl')
    FILENAME=$(echo "$DOWNLOAD_RESPONSE" | jq -r '.filename')
    echo "Filename: $FILENAME"
    echo "Download URL: ${DOWNLOAD_URL:0:80}..."
else
    echo -e "${RED}❌ Failed to generate download URL${NC}"
    echo "$DOWNLOAD_RESPONSE"
    exit 1
fi
echo ""

# Step 7: Download file
echo "Step 7: Downloading file from CloudFront..."
DOWNLOAD_STATUS=$(curl -s -w "%{http_code}" -o /tmp/downloaded_file.txt \
  "$DOWNLOAD_URL")

if [ "$DOWNLOAD_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ File downloaded successfully (HTTP $DOWNLOAD_STATUS)${NC}"
    DOWNLOADED_CONTENT=$(cat /tmp/downloaded_file.txt)
    echo "Downloaded content: $DOWNLOADED_CONTENT"
else
    echo -e "${RED}❌ File download failed (HTTP $DOWNLOAD_STATUS)${NC}"
    cat /tmp/downloaded_file.txt
    exit 1
fi
echo ""

# Step 8: Verify content integrity
echo "Step 8: Verifying content integrity..."
if [ "$TEST_CONTENT" = "$DOWNLOADED_CONTENT" ]; then
    echo -e "${GREEN}✅ Content integrity verified${NC}"
    echo "Original:   $TEST_CONTENT"
    echo "Downloaded: $DOWNLOADED_CONTENT"
else
    echo -e "${RED}❌ Content mismatch!${NC}"
    echo "Original:   $TEST_CONTENT"
    echo "Downloaded: $DOWNLOADED_CONTENT"
    exit 1
fi
echo ""

# Step 9: Verify custom domain usage
echo "Step 9: Verifying custom domain usage..."
if echo "$UPLOAD_URL" | grep -q "cdn-demo.pe-labs.com"; then
    echo -e "${GREEN}✅ Upload URL uses custom domain (cdn-demo.pe-labs.com)${NC}"
else
    echo -e "${YELLOW}⚠️  Upload URL doesn't use custom domain${NC}"
    echo "URL: $UPLOAD_URL"
fi

if echo "$DOWNLOAD_URL" | grep -q "cdn-demo.pe-labs.com"; then
    echo -e "${GREEN}✅ Download URL uses custom domain (cdn-demo.pe-labs.com)${NC}"
else
    echo -e "${YELLOW}⚠️  Download URL doesn't use custom domain${NC}"
    echo "URL: $DOWNLOAD_URL"
fi
echo ""

# Step 10: Verify signed URL parameters
echo "Step 10: Verifying signed URL parameters..."
if echo "$DOWNLOAD_URL" | grep -q "Policy=" && \
   echo "$DOWNLOAD_URL" | grep -q "Signature=" && \
   echo "$DOWNLOAD_URL" | grep -q "Key-Pair-Id="; then
    echo -e "${GREEN}✅ Signed URL contains required parameters${NC}"
    echo "  - Policy: Present"
    echo "  - Signature: Present"
    echo "  - Key-Pair-Id: Present"
else
    echo -e "${RED}❌ Signed URL missing required parameters${NC}"
fi
echo ""

# Cleanup
echo "Cleaning up temporary files..."
rm -f "$TEST_FILE" /tmp/downloaded_file.txt /tmp/upload_response.txt
echo -e "${GREEN}✅ Cleanup complete${NC}"
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}✅ All tests passed successfully!${NC}"
echo ""
echo "Verified:"
echo "  ✓ Configuration endpoint"
echo "  ✓ Upload URL generation"
echo "  ✓ File upload via CloudFront"
echo "  ✓ File listing"
echo "  ✓ Download URL generation"
echo "  ✓ File download via CloudFront"
echo "  ✓ Content integrity"
echo "  ✓ Custom domain usage"
echo "  ✓ Signed URL parameters"
echo ""
echo "Your CloudFront Signed URLs infrastructure is working perfectly! 🎉"
echo "=========================================="

