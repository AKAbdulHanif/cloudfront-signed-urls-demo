#!/bin/bash

# Test CloudFront Signed URLs with Custom Domain
# This script demonstrates that files are uploaded/downloaded via custom domain

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
API_URL="https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod"
CUSTOM_DOMAIN="cdn-demo.pe-labs.com"

echo "=========================================="
echo "CloudFront Signed URLs - Custom Domain Test"
echo "=========================================="
echo ""
echo -e "${CYAN}API Gateway:${NC} $API_URL (for generating signed URLs)"
echo -e "${CYAN}CloudFront:${NC}  https://$CUSTOM_DOMAIN (for actual file operations)"
echo ""
echo -e "${YELLOW}Note: API Gateway generates signed URLs, but files are uploaded/downloaded"
echo -e "      through CloudFront custom domain ($CUSTOM_DOMAIN)${NC}"
echo ""

# Step 1: Generate Upload URL
echo "=========================================="
echo -e "${BLUE}Step 1: Generate Upload URL${NC}"
echo "=========================================="
echo ""
echo "Calling API Gateway to generate signed URL..."

UPLOAD_RESPONSE=$(curl -s -X POST \
  "$API_URL/api/files/upload" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test-custom-domain.txt","contentType":"text/plain"}')

echo "$UPLOAD_RESPONSE" | jq '.'
echo ""

# Extract values
UPLOAD_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.uploadUrl')
FILE_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.fileId')

if [ "$UPLOAD_URL" == "null" ] || [ -z "$UPLOAD_URL" ]; then
  echo -e "${RED}✗ Failed to generate upload URL${NC}"
  exit 1
fi

# Check if URL uses custom domain
if [[ "$UPLOAD_URL" == *"$CUSTOM_DOMAIN"* ]]; then
  echo -e "${GREEN}✓ Upload URL uses custom domain: $CUSTOM_DOMAIN${NC}"
else
  echo -e "${RED}✗ Upload URL does NOT use custom domain${NC}"
  echo "URL: $UPLOAD_URL"
  exit 1
fi

echo ""
echo -e "${CYAN}Upload URL:${NC} ${UPLOAD_URL:0:80}..."
echo -e "${CYAN}File ID:${NC} $FILE_ID"
echo ""

# Step 2: Upload File via CloudFront Custom Domain
echo "=========================================="
echo -e "${BLUE}Step 2: Upload File via CloudFront${NC}"
echo "=========================================="
echo ""
echo "Creating test file..."
TEST_CONTENT="Hello from CloudFront Custom Domain!
This file was uploaded via: $CUSTOM_DOMAIN
Timestamp: $(date)
File ID: $FILE_ID"

echo "$TEST_CONTENT" > /tmp/test-custom-domain.txt
echo "Test file content:"
echo "---"
cat /tmp/test-custom-domain.txt
echo "---"
echo ""

echo "Uploading to CloudFront custom domain ($CUSTOM_DOMAIN)..."
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/upload_response.txt \
  -X PUT \
  -H "Content-Type: text/plain" \
  --data-binary "@/tmp/test-custom-domain.txt" \
  "$UPLOAD_URL")

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo -e "${GREEN}✓ File uploaded successfully via $CUSTOM_DOMAIN (HTTP $HTTP_CODE)${NC}"
else
  echo -e "${RED}✗ Upload failed (HTTP $HTTP_CODE)${NC}"
  cat /tmp/upload_response.txt
  exit 1
fi
echo ""

# Wait a moment for S3 consistency
echo "Waiting 2 seconds for S3 consistency..."
sleep 2
echo ""

# Step 3: List Files
echo "=========================================="
echo -e "${BLUE}Step 3: List Files${NC}"
echo "=========================================="
echo ""
echo "Fetching file list from API..."
curl -s "$API_URL/api/files" | jq '.files[] | select(.fileId == "'$FILE_ID'")'
echo ""

# Step 4: Generate Download URL
echo "=========================================="
echo -e "${BLUE}Step 4: Generate Download URL${NC}"
echo "=========================================="
echo ""
echo "Calling API Gateway to generate download URL..."

DOWNLOAD_RESPONSE=$(curl -s "$API_URL/api/files/download/$FILE_ID")

echo "$DOWNLOAD_RESPONSE" | jq '.'
echo ""

DOWNLOAD_URL=$(echo "$DOWNLOAD_RESPONSE" | jq -r '.downloadUrl')

if [ "$DOWNLOAD_URL" == "null" ] || [ -z "$DOWNLOAD_URL" ]; then
  echo -e "${RED}✗ Failed to generate download URL${NC}"
  exit 1
fi

# Check if URL uses custom domain
if [[ "$DOWNLOAD_URL" == *"$CUSTOM_DOMAIN"* ]]; then
  echo -e "${GREEN}✓ Download URL uses custom domain: $CUSTOM_DOMAIN${NC}"
else
  echo -e "${RED}✗ Download URL does NOT use custom domain${NC}"
  echo "URL: $DOWNLOAD_URL"
  exit 1
fi

echo ""
echo -e "${CYAN}Download URL:${NC} ${DOWNLOAD_URL:0:80}..."
echo ""

# Step 5: Download File via CloudFront Custom Domain
echo "=========================================="
echo -e "${BLUE}Step 5: Download File via CloudFront${NC}"
echo "=========================================="
echo ""
echo "Downloading from CloudFront custom domain ($CUSTOM_DOMAIN)..."

HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/downloaded.txt "$DOWNLOAD_URL")

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo -e "${GREEN}✓ File downloaded successfully via $CUSTOM_DOMAIN (HTTP $HTTP_CODE)${NC}"
else
  echo -e "${RED}✗ Download failed (HTTP $HTTP_CODE)${NC}"
  exit 1
fi
echo ""

echo "Downloaded content:"
echo "---"
cat /tmp/downloaded.txt
echo "---"
echo ""

# Step 6: Verify Content
echo "=========================================="
echo -e "${BLUE}Step 6: Verify Content${NC}"
echo "=========================================="
echo ""

if diff /tmp/test-custom-domain.txt /tmp/downloaded.txt > /dev/null; then
  echo -e "${GREEN}✓ Content verification: PASSED${NC}"
  echo "Uploaded and downloaded content match perfectly!"
else
  echo -e "${RED}✗ Content verification: FAILED${NC}"
  echo "Content mismatch!"
  exit 1
fi
echo ""

# Step 7: Verify Signed URL Components
echo "=========================================="
echo -e "${BLUE}Step 7: Verify Signed URL Components${NC}"
echo "=========================================="
echo ""

echo "Upload URL components:"
echo "$UPLOAD_URL" | grep -o "Policy=[^&]*" | head -c 50
echo "..."
echo "$UPLOAD_URL" | grep -o "Signature=[^&]*" | head -c 50
echo "..."
echo "$UPLOAD_URL" | grep -o "Key-Pair-Id=[^&]*"
echo ""

echo "Download URL components:"
echo "$DOWNLOAD_URL" | grep -o "Policy=[^&]*" | head -c 50
echo "..."
echo "$DOWNLOAD_URL" | grep -o "Signature=[^&]*" | head -c 50
echo "..."
echo "$DOWNLOAD_URL" | grep -o "Key-Pair-Id=[^&]*"
echo ""

# Cleanup
rm -f /tmp/test-custom-domain.txt /tmp/downloaded.txt /tmp/upload_response.txt

# Summary
echo "=========================================="
echo -e "${GREEN}✓ All Tests Passed!${NC}"
echo "=========================================="
echo ""
echo "Summary:"
echo -e "  ${GREEN}✓${NC} Upload URL uses custom domain ($CUSTOM_DOMAIN)"
echo -e "  ${GREEN}✓${NC} File uploaded successfully via CloudFront"
echo -e "  ${GREEN}✓${NC} Download URL uses custom domain ($CUSTOM_DOMAIN)"
echo -e "  ${GREEN}✓${NC} File downloaded successfully via CloudFront"
echo -e "  ${GREEN}✓${NC} Content integrity verified"
echo -e "  ${GREEN}✓${NC} Signed URL components present"
echo ""
echo -e "${CYAN}Your CloudFront signed URLs are working perfectly with custom domain!${NC}"
echo ""
echo "Key Points:"
echo "  • API Gateway ($API_URL) generates signed URLs"
echo "  • CloudFront ($CUSTOM_DOMAIN) handles actual file operations"
echo "  • All file transfers go through your custom domain"
echo "  • URLs are time-limited and cryptographically signed"
echo ""

