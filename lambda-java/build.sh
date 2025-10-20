#!/bin/bash

# Build script for Java Lambda function
# This script builds the Lambda function using Maven and creates a deployment package

set -e

echo "Building CloudFront Signer Lambda (Java)..."

# Check if Maven is installed
if ! command -v mvn &> /dev/null; then
    echo "Error: Maven is not installed. Please install Maven first."
    exit 1
fi

# Clean previous builds
echo "Cleaning previous builds..."
mvn clean

# Build the project
echo "Building project with Maven..."
mvn package

# Check if build was successful
if [ -f "target/cloudfront-signer-lambda-1.0.0.jar" ]; then
    echo "✅ Build successful!"
    echo "Lambda JAR location: target/cloudfront-signer-lambda-1.0.0.jar"
    echo "File size: $(du -h target/cloudfront-signer-lambda-1.0.0.jar | cut -f1)"
else
    echo "❌ Build failed!"
    exit 1
fi

echo ""
echo "To deploy this Lambda function:"
echo "1. Upload the JAR to AWS Lambda"
echo "2. Set the handler to: com.example.CloudFrontSignerHandler::handleRequest"
echo "3. Set the runtime to: Java 11"
echo "4. Configure environment variables (see README.md)"

