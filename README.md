# CloudFront Signed URLs Demo

A complete AWS infrastructure solution for secure file uploads and downloads using CloudFront signed URLs with custom domain support.

[![AWS](https://img.shields.io/badge/AWS-CloudFront%20%7C%20Lambda%20%7C%20S3-orange)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)
[![Python](https://img.shields.io/badge/Python-3.11-blue)](https://www.python.org/)

## 🎯 Overview

This project demonstrates how to implement secure file uploads and downloads using CloudFront signed URLs, enabling:

- ✅ **Custom Domain Support** - Use your own domain (e.g., `cdn-demo.pe-labs.com`) instead of S3 URLs
- ✅ **Corporate Firewall Friendly** - Whitelist a single custom domain instead of dynamic S3 URLs
- ✅ **Secure PUT Operations** - Upload files directly to CloudFront using signed URLs
- ✅ **Time-Limited Access** - URLs expire after configured time (15 min upload, 1 hour download)
- ✅ **Serverless Architecture** - No servers to manage, scales automatically
- ✅ **Infrastructure as Code** - Complete Terraform configuration for reproducible deployments

## 🏗️ Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       │ 1. Request upload/download URL
       ▼
┌─────────────────────┐
│   API Gateway       │
│  (REST API)         │
└──────┬──────────────┘
       │
       │ 2. Invoke Lambda
       ▼
┌─────────────────────┐      ┌──────────────────┐
│  Lambda Function    │─────▶│ Secrets Manager  │
│  (Generate Signed   │      │ (Private Key)    │
│   URLs)             │      └──────────────────┘
└──────┬──────────────┘
       │
       │ 3. Return signed URL (https://cdn-demo.pe-labs.com/...)
       ▼
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       │ 4. Upload/Download via signed URL
       ▼
┌─────────────────────┐      ┌──────────────────┐
│   CloudFront        │─────▶│   S3 Bucket      │
│  (cdn-demo.pe-labs  │      │  (Private)       │
│   .com)             │      └──────────────────┘
└─────────────────────┘
       │
       │ Metadata
       ▼
┌─────────────────────┐
│   DynamoDB Table    │
│  (File Metadata)    │
└─────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured
- Terraform >= 1.0
- Python 3.11+
- Domain name (optional, for custom domain)

### 1. Clone Repository

```bash
git clone https://github.com/akabdulhanif/cloudfront-signed-urls-demo.git
cd cloudfront-signed-urls-demo
```

### 2. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
project_name = "cloudfront-signedurl-demo"
aws_region   = "us-east-1"

# Optional: Custom domain configuration
custom_domain_enabled = true
domain_name          = "pe-labs.com"
subdomain            = "cdn-demo"

# CloudFront signing keys (leave empty for auto-generation)
cloudfront_public_key  = ""
cloudfront_private_key = ""
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy
terraform apply
```

### 4. Test the API

```bash
# Get API URL from Terraform output
API_URL=$(terraform output -raw api_gateway_url)

# Generate upload URL
curl -X POST "$API_URL/api/files/upload" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.txt","contentType":"text/plain"}' | jq '.'

# Upload file (use uploadUrl from response)
echo "Hello CloudFront!" > test.txt
curl -X PUT -H "Content-Type: text/plain" \
  --data-binary "@test.txt" \
  "<UPLOAD_URL_FROM_RESPONSE>"

# List files
curl "$API_URL/api/files" | jq '.'
```

### 5. Test with Custom Domain

Run the comprehensive test script:

```bash
cd scripts
./test-with-custom-domain.sh
```

This verifies that all file operations use your custom domain (`cdn-demo.pe-labs.com`).

## 📁 Project Structure

```
cloudfront-signed-urls-demo/
├── README.md                          # This file
├── LICENSE                            # MIT License
├── .gitignore                         # Git ignore rules (excludes keys!)
│
├── terraform/                         # Terraform infrastructure code
│   ├── main.tf                        # Main infrastructure resources
│   ├── variables.tf                   # Input variables
│   ├── outputs.tf                     # Output values
│   └── terraform.tfvars.example       # Example configuration
│
├── lambda/                            # Lambda function code
│   ├── index.py                       # Main Lambda handler
│   ├── requirements.txt               # Python dependencies
│   └── build.sh                       # Build deployment package
│
├── scripts/                           # Utility scripts
│   ├── deploy.sh                      # One-click deployment
│   ├── test-api.sh                    # API testing script
│   └── test-with-custom-domain.sh     # Custom domain testing
│
├── docs/                              # Documentation
│   ├── API.md                         # API documentation
│   ├── ARCHITECTURE.md                # Architecture details
│   ├── SECURITY.md                    # Security best practices
│   ├── DEPLOYMENT.md                  # Deployment guide
│   ├── TESTING.md                     # Testing guide
│   └── CUSTOM_DOMAIN_TESTING.md       # Custom domain testing guide
│
└── examples/                          # Integration examples
    ├── curl/                          # cURL examples
    └── python/                        # Python examples
```

## 📚 Documentation

- **[API Documentation](docs/API.md)** - Complete API reference with examples
- **[Architecture Guide](docs/ARCHITECTURE.md)** - Detailed architecture explanation
- **[Security Guide](docs/SECURITY.md)** - Security best practices and key management
- **[Custom Domain Testing](docs/CUSTOM_DOMAIN_TESTING.md)** - How to test with custom domain
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Step-by-step deployment instructions
- **[Troubleshooting](docs/TESTING.md)** - Common issues and solutions

## 🔑 Key Features

### CloudFront Signed URLs

- **Time-Limited Access** - URLs expire after configured duration
- **PUT and GET Support** - Upload and download with signed URLs
- **Custom Domain** - Use your own domain instead of CloudFront default
- **Secure** - Private key stored in AWS Secrets Manager

### Custom Domain Support ✨

**Confirmed Working**: This infrastructure fully supports custom domains through Route53, ACM, and CloudFront.

**How it works**:
1. API Gateway generates signed URLs
2. Signed URLs point to your custom CloudFront domain
3. All file operations happen through your custom domain
4. End users never see default CloudFront or S3 URLs

**Example**:
```
API Gateway generates:
https://cdn-demo.pe-labs.com/uploads/file.pdf?Policy=...&Signature=...&Key-Pair-Id=...

Users upload/download via:
cdn-demo.pe-labs.com (your custom domain!)
```

See [Custom Domain Testing Guide](docs/CUSTOM_DOMAIN_TESTING.md) for details.

### Serverless Architecture

- **Lambda Function** - Generates signed URLs on-demand
- **API Gateway** - RESTful API for client integration
- **DynamoDB** - Stores file metadata
- **S3** - Private bucket for file storage
- **CloudFront** - Global CDN with signed URL validation

### Infrastructure as Code

- **Terraform** - Complete infrastructure definition
- **Automated Deployment** - One-command deployment
- **Reproducible** - Deploy to multiple environments easily
- **Version Controlled** - Track infrastructure changes

## 🌐 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/files/upload` | Generate upload URL |
| GET | `/api/files` | List all files |
| GET | `/api/files/download/{id}` | Generate download URL |
| DELETE | `/api/files/{id}` | Delete file |
| GET | `/api/config` | Get configuration |

See [API Documentation](docs/API.md) for detailed information.

## 🔒 Security

- ✅ S3 bucket is private (no public access)
- ✅ CloudFront validates all signed URL requests
- ✅ Private key encrypted in Secrets Manager
- ✅ HTTPS only (TLS 1.2+)
- ✅ IAM roles follow least privilege principle
- ✅ Encryption at rest for S3 and DynamoDB
- ✅ Time-limited access (URLs expire)
- ✅ **Keys never committed to repository** (protected by .gitignore)

See [Security Guide](docs/SECURITY.md) for more details.

## 💰 Cost Estimation

Estimated monthly cost for moderate usage:

| Service | Usage | Cost |
|---------|-------|------|
| CloudFront | 100GB transfer | $8.50 |
| S3 Storage | 100GB | $2.30 |
| Lambda | 1M requests | $2.00 |
| API Gateway | 1M requests | $3.50 |
| DynamoDB | On-demand | $1.25 |
| Other Services | - | $1.50 |
| **Total** | | **~$19/month** |

Actual costs vary based on usage. See [AWS Pricing](https://aws.amazon.com/pricing/).

## 🧪 Testing

### Automated Testing

Run the comprehensive test suite:

```bash
# Test complete upload/download flow
./scripts/test-api.sh

# Test custom domain specifically
./scripts/test-with-custom-domain.sh
```

### Manual Testing

```bash
# Generate upload URL
curl -X POST \
  "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod/api/files/upload" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.txt","contentType":"text/plain"}' | jq '.'

# The response will include uploadUrl using your custom domain:
# "uploadUrl": "https://cdn-demo.pe-labs.com/uploads/abc123_test.txt?Policy=...&Signature=...&Key-Pair-Id=..."
```

See [Custom Domain Testing Guide](docs/CUSTOM_DOMAIN_TESTING.md) for detailed testing instructions.

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- AWS CloudFront team for signed URL documentation
- Terraform AWS provider maintainers
- Community contributors

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/akabdulhanif/cloudfront-signed-urls-demo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/akabdulhanif/cloudfront-signed-urls-demo/discussions)

## 🗺️ Roadmap

- [ ] Add frontend React application
- [ ] Implement authentication (Okta integration)
- [ ] Add file versioning support
- [ ] Implement virus scanning for uploads
- [ ] Add CloudFormation templates
- [ ] Create Helm chart for Kubernetes deployment
- [ ] Add monitoring dashboards
- [ ] Implement file sharing with expiring links

## 📊 Status

- ✅ Core infrastructure working
- ✅ CloudFront signed URLs functional
- ✅ Custom domain support confirmed
- ✅ API Gateway integration
- ✅ Lambda function deployed
- ✅ Documentation complete
- ✅ Custom domain testing guide
- ⏳ Frontend application (planned)
- ⏳ Authentication (planned)

---

**Made with ❤️ for secure file sharing**

**Star ⭐ this repo if you find it helpful!**

