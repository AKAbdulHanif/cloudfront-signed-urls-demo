#!/bin/bash

# Script to update CloudFront distribution with separate behaviors for uploads and downloads
# This allows PUT operations through /uploads/* path without OAC

set -e

DISTRIBUTION_ID="E2G9NCP6YLJ6OF"
KEY_GROUP_ID="K1VQWJ8Y7QZQXR"  # Replace with your actual key group ID

echo "=========================================="
echo "Updating CloudFront Distribution"
echo "Distribution ID: $DISTRIBUTION_ID"
echo "=========================================="
echo ""

# Step 1: Get current distribution configuration
echo "Step 1: Fetching current distribution configuration..."
aws cloudfront get-distribution-config \
  --id "$DISTRIBUTION_ID" \
  --output json > /tmp/cf-config.json

# Extract ETag
ETAG=$(jq -r '.ETag' /tmp/cf-config.json)
echo "Current ETag: $ETAG"
echo ""

# Step 2: Get the key group ID
echo "Step 2: Finding CloudFront Key Group..."
KEY_GROUP_ID=$(aws cloudfront list-key-groups \
  --query "KeyGroupList.Items[?KeyGroup.Name=='cloudfront-signedurl-demo-key-group'].KeyGroup.Id" \
  --output text)

if [ -z "$KEY_GROUP_ID" ]; then
  echo "❌ Key group not found!"
  exit 1
fi

echo "Key Group ID: $KEY_GROUP_ID"
echo ""

# Step 3: Create updated configuration with ordered cache behavior
echo "Step 3: Creating updated configuration..."

# Extract just the DistributionConfig
jq '.DistributionConfig' /tmp/cf-config.json > /tmp/cf-dist-config.json

# Add ordered cache behavior for /uploads/*
jq --arg key_group_id "$KEY_GROUP_ID" '
.CacheBehaviors = {
  "Quantity": 1,
  "Items": [
    {
      "PathPattern": "/uploads/*",
      "TargetOriginId": .Origins.Items[0].Id,
      "TrustedSigners": {
        "Enabled": false,
        "Quantity": 0
      },
      "TrustedKeyGroups": {
        "Enabled": true,
        "Quantity": 1,
        "Items": [$key_group_id]
      },
      "ViewerProtocolPolicy": "redirect-to-https",
      "AllowedMethods": {
        "Quantity": 7,
        "Items": ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"],
        "CachedMethods": {
          "Quantity": 2,
          "Items": ["HEAD", "GET"]
        }
      },
      "Compress": false,
      "MinTTL": 0,
      "DefaultTTL": 0,
      "MaxTTL": 0,
      "ForwardedValues": {
        "QueryString": true,
        "Cookies": {
          "Forward": "none"
        },
        "Headers": {
          "Quantity": 1,
          "Items": ["*"]
        }
      },
      "SmoothStreaming": false,
      "FieldLevelEncryptionId": ""
    }
  ]
}
' /tmp/cf-dist-config.json > /tmp/cf-dist-config-updated.json

echo "Updated configuration created"
echo ""

# Step 4: Update the distribution
echo "Step 4: Updating CloudFront distribution..."
echo "This may take 10-15 minutes to deploy..."
echo ""

aws cloudfront update-distribution \
  --id "$DISTRIBUTION_ID" \
  --if-match "$ETAG" \
  --distribution-config file:///tmp/cf-dist-config-updated.json \
  --output json > /tmp/cf-update-result.json

echo "✅ Update initiated successfully!"
echo ""

# Step 5: Wait for deployment
echo "Step 5: Waiting for deployment to complete..."
echo "You can check status with:"
echo "  aws cloudfront get-distribution --id $DISTRIBUTION_ID --query 'Distribution.Status'"
echo ""
echo "Or wait for completion with:"
echo "  aws cloudfront wait distribution-deployed --id $DISTRIBUTION_ID"
echo ""

# Optional: Wait for deployment (uncomment if you want to wait)
# aws cloudfront wait distribution-deployed --id "$DISTRIBUTION_ID"
# echo "✅ Deployment complete!"

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "CloudFront distribution updated with:"
echo "  ✓ /uploads/* - Allows PUT operations (no OAC)"
echo "  ✓ /* (default) - Allows GET operations (with OAC)"
echo ""
echo "Both behaviors require CloudFront signed URLs"
echo ""
echo "After deployment completes, test with:"
echo "  1. Generate upload URL via API"
echo "  2. PUT file to the signed URL"
echo "  3. Verify upload succeeds (HTTP 200)"
echo ""

