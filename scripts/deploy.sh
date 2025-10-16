#!/bin/bash

# One-click deployment script for CloudFront Signed URLs Demo

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "CloudFront Signed URLs Demo - Deployment"
echo "=========================================="
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform not found${NC}"
    echo "Please install Terraform: https://www.terraform.io/downloads"
    exit 1
fi
echo -e "${GREEN}✓ Terraform found${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not found${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI found${NC}"

if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS credentials not configured${NC}"
    echo "Please configure AWS CLI: aws configure"
    exit 1
fi
echo -e "${GREEN}✓ AWS credentials configured${NC}"

echo ""

# Build Lambda function
echo -e "${YELLOW}Step 1: Building Lambda function...${NC}"
cd ../lambda
./build.sh
cd ../scripts
echo ""

# Initialize Terraform
echo -e "${YELLOW}Step 2: Initializing Terraform...${NC}"
cd ../terraform
terraform init
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Creating terraform.tfvars from example...${NC}"
    if [ -f "terraform.tfvars.example" ]; then
        cp terraform.tfvars.example terraform.tfvars
        echo -e "${YELLOW}⚠ Please edit terraform.tfvars with your configuration${NC}"
        echo "Then run this script again."
        exit 0
    fi
fi

# Plan
echo -e "${YELLOW}Step 3: Planning infrastructure...${NC}"
terraform plan -out=tfplan
echo ""

# Confirm deployment
echo -e "${YELLOW}Ready to deploy. Continue? (yes/no)${NC}"
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

# Apply
echo -e "${YELLOW}Step 4: Deploying infrastructure...${NC}"
terraform apply tfplan
echo ""

# Get outputs
echo "=========================================="
echo -e "${GREEN}Deployment Complete!${NC}"
echo "=========================================="
echo ""
echo "API Gateway URL:"
terraform output -raw api_gateway_url
echo ""
echo ""
echo "CloudFront Domain:"
terraform output -raw cloudfront_domain
echo ""
echo ""
echo "Test the API:"
echo "  curl -X POST \\"
echo "    \"\$(terraform output -raw api_gateway_url)/api/files/upload\" \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{\"filename\":\"test.txt\",\"contentType\":\"text/plain\"}' | jq '.'"
echo ""

cd ../scripts

