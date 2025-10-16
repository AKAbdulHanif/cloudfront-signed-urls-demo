#!/bin/bash

# Build Lambda deployment package

set -e

echo "Building Lambda deployment package..."

# Create build directory
BUILD_DIR="build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Copy Lambda function
cp index.py "$BUILD_DIR/"

# Install dependencies
pip3 install -r requirements.txt -t "$BUILD_DIR/" --upgrade --quiet

# Create ZIP file
cd "$BUILD_DIR"
zip -r ../lambda-deployment.zip . -q
cd ..

# Clean up
rm -rf "$BUILD_DIR"

echo "✓ Lambda deployment package created: lambda-deployment.zip"
echo "  Size: $(du -h lambda-deployment.zip | cut -f1)"

