#!/bin/bash

# Lambda Deployment Package Build Script

set -e

echo "=========================================="
echo "Building Lambda Deployment Package"
echo "=========================================="
echo ""

# Clean previous build
echo "Cleaning previous build..."
rm -rf package lambda.zip
mkdir -p package

# Install dependencies
echo "Installing dependencies..."
python3 -m pip install -r requirements.txt -t package/ --quiet

# Copy Lambda function
echo "Copying Lambda function..."
cp index.py package/

# Create deployment package
echo "Creating deployment package..."
cd package
zip -r ../lambda.zip . -q
cd ..

# Clean up
echo "Cleaning up..."
rm -rf package

# Show package info
echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo "Package: lambda.zip"
echo "Size: $(du -h lambda.zip | cut -f1)"
echo ""
