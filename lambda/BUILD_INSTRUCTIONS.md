# Lambda Package Build Instructions

## Problem

The Lambda function is failing with `invalid ELF header` error because the `cryptography` library was compiled for the wrong architecture. Lambda requires packages built for Amazon Linux 2 (x86_64).

## Solution

Build the Lambda package using Docker to ensure compatibility with AWS Lambda runtime.

## Option 1: Build with Docker (Recommended)

### Prerequisites
- Docker installed and running
- Clone the repository

### Steps

```bash
cd lambda

# Run the Docker build script
./build-docker.sh

# The script will:
# 1. Use official AWS Lambda Python 3.11 Docker image
# 2. Install dependencies inside the container
# 3. Create lambda.zip compatible with Lambda runtime
```

### What the script does

```bash
docker run --rm \
  -v "$(pwd)":/var/task \
  -w /var/task \
  public.ecr.aws/lambda/python:3.11 \
  pip install -r requirements.txt -t package/
```

This ensures all native extensions (like `cryptography`) are compiled for the correct architecture.

## Option 2: Manual Docker Build

If the script doesn't work, build manually:

```bash
cd lambda

# Clean previous build
rm -rf package lambda.zip
mkdir package

# Install dependencies using Lambda Docker image
docker run --rm \
  -v "$(pwd)":/var/task \
  -w /var/task \
  public.ecr.aws/lambda/python:3.11 \
  pip install -r requirements.txt -t package/

# Copy Lambda function
cp index.py package/

# Create ZIP
cd package
zip -r ../lambda.zip .
cd ..

# Clean up
rm -rf package
```

## Option 3: Use AWS SAM CLI

If you have AWS SAM CLI installed:

```bash
cd lambda

# Build using SAM
sam build --use-container

# The built package will be in .aws-sam/build/
```

## Option 4: Build on Amazon Linux EC2

If Docker isn't available:

1. Launch Amazon Linux 2 EC2 instance
2. Install Python 3.11
3. Run the regular build script:

```bash
./build.sh
```

## Quick Fix: Update Existing Lambda

Once you've built the correct package:

```bash
# Update Lambda function code
aws lambda update-function-code \
  --function-name cloudfront-signedurl-demo-api \
  --zip-file fileb://lambda.zip

# Wait for update to complete
aws lambda wait function-updated \
  --function-name cloudfront-signedurl-demo-api

# Test the function
aws lambda invoke \
  --function-name cloudfront-signedurl-demo-api \
  --cli-binary-format raw-in-base64-out \
  --payload '{"httpMethod":"GET","path":"/api/config"}' \
  response.json

cat response.json
```

## Verification

After updating, test the API:

```bash
curl https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/config | jq '.'
```

You should see a successful response instead of "Internal server error".

## Why This Happens

The `cryptography` library includes native C extensions that are compiled during installation. These compiled binaries are architecture-specific:

- **Your Mac (ARM64 or x86_64)**: Compiles for macOS
- **AWS Lambda (x86_64 Linux)**: Requires Amazon Linux 2 binaries

When you run `pip install` on your Mac, it creates binaries for macOS, which Lambda can't execute.

## Prevention

Always build Lambda packages using:
1. **Docker with Lambda base image** (recommended)
2. **EC2 instance with Amazon Linux 2**
3. **AWS SAM CLI with `--use-container` flag**
4. **GitHub Actions** with Linux runner

## Terraform Integration

Update your Terraform workflow to build the package correctly:

```hcl
# In your CI/CD pipeline or locally before terraform apply
resource "null_resource" "lambda_build" {
  triggers = {
    requirements = filemd5("${path.module}/../lambda/requirements.txt")
    source_code  = filemd5("${path.module}/../lambda/index.py")
  }
  
  provisioner "local-exec" {
    command = "cd ${path.module}/../lambda && ./build-docker.sh"
  }
}

resource "aws_lambda_function" "main" {
  # ... other configuration ...
  
  depends_on = [null_resource.lambda_build]
}
```

## Additional Resources

- [AWS Lambda Deployment Package](https://docs.aws.amazon.com/lambda/latest/dg/python-package.html)
- [Lambda Docker Images](https://docs.aws.amazon.com/lambda/latest/dg/python-image.html)
- [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)

---

**After building with Docker, update your Lambda function and the API will work correctly!**

