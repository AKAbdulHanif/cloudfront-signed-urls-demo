#!/bin/bash

# Lambda Deployment Package Build Script (Docker-based)
# This ensures the package is built for the correct Lambda runtime environment

set -e

echo "=========================================="
echo "Building Lambda Deployment Package"
echo "Using Docker for Lambda-compatible build"
echo "=========================================="
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not available"
    echo "Please install Docker or use a Linux system to build the package"
    exit 1
fi

# Clean previous build
echo "Cleaning previous build..."
rm -rf package lambda.zip

# Create package directory
mkdir -p package

# Build dependencies using Docker with Lambda Python runtime
echo "Installing dependencies using Docker..."
docker run --rm \
  -v "$(pwd)":/var/task \
  -w /var/task \
  public.ecr.aws/lambda/python:3.11 \
  pip install -r requirements.txt -t package/ --quiet

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
echo "The package is now compatible with AWS Lambda runtime"
echo ""

