#!/bin/bash

# Example: Complete upload/download flow using cURL

set -e

# Configuration
API_URL="https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod"

echo "=========================================="
echo "CloudFront Signed URLs - cURL Example"
echo "=========================================="
echo ""

# Step 1: Generate upload URL
echo "Step 1: Generating upload URL..."
UPLOAD_RESPONSE=$(curl -s -X POST \
  "$API_URL/api/files/upload" \
  -H "Content-Type: application/json" \
  -d '{"filename":"example.txt","contentType":"text/plain"}')

echo "$UPLOAD_RESPONSE" | jq '.'
echo ""

# Extract values
UPLOAD_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.uploadUrl')
FILE_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.fileId')

if [ "$UPLOAD_URL" == "null" ] || [ -z "$UPLOAD_URL" ]; then
  echo "Error: Failed to generate upload URL"
  exit 1
fi

echo "Upload URL: ${UPLOAD_URL:0:80}..."
echo "File ID: $FILE_ID"
echo ""

# Step 2: Upload file
echo "Step 2: Uploading file..."
echo "Hello from CloudFront Signed URLs!" > /tmp/example.txt

HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/upload_response.txt \
  -X PUT \
  -H "Content-Type: text/plain" \
  --data-binary "@/tmp/example.txt" \
  "$UPLOAD_URL")

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo "✓ File uploaded successfully (HTTP $HTTP_CODE)"
else
  echo "✗ Upload failed (HTTP $HTTP_CODE)"
  cat /tmp/upload_response.txt
  exit 1
fi
echo ""

# Step 3: List files
echo "Step 3: Listing files..."
curl -s "$API_URL/api/files" | jq '.'
echo ""

# Step 4: Generate download URL
echo "Step 4: Generating download URL..."
DOWNLOAD_RESPONSE=$(curl -s "$API_URL/api/files/download/$FILE_ID")

echo "$DOWNLOAD_RESPONSE" | jq '.'
echo ""

DOWNLOAD_URL=$(echo "$DOWNLOAD_RESPONSE" | jq -r '.downloadUrl')

if [ "$DOWNLOAD_URL" == "null" ] || [ -z "$DOWNLOAD_URL" ]; then
  echo "Error: Failed to generate download URL"
  exit 1
fi

echo "Download URL: ${DOWNLOAD_URL:0:80}..."
echo ""

# Step 5: Download file
echo "Step 5: Downloading file..."
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/downloaded.txt "$DOWNLOAD_URL")

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo "✓ File downloaded successfully (HTTP $HTTP_CODE)"
  echo ""
  echo "Downloaded content:"
  cat /tmp/downloaded.txt
  echo ""
else
  echo "✗ Download failed (HTTP $HTTP_CODE)"
  exit 1
fi

# Cleanup
rm -f /tmp/example.txt /tmp/downloaded.txt /tmp/upload_response.txt

echo ""
echo "=========================================="
echo "✓ All tests passed!"
echo "=========================================="

