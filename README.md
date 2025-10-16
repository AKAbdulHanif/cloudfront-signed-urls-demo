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
       │ 3. Return signed URL
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
git clone https://github.com/YOUR_USERNAME/cloudfront-signed-urls-demo.git
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

# CloudFront signing keys (generated automatically if not provided)
cloudfront_public_key  = ""  # Leave empty to auto-generate
cloudfront_private_key = ""  # Leave empty to auto-generate
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

# Upload file
echo "Hello CloudFront!" > test.txt
curl -X PUT -H "Content-Type: text/plain" \
  --data-binary "@test.txt" \
  "<UPLOAD_URL_FROM_RESPONSE>"

# List files
curl "$API_URL/api/files" | jq '.'
```

## 📁 Project Structure

```
cloudfront-signed-urls-demo/
├── README.md                    # This file
├── LICENSE                      # MIT License
├── .gitignore                   # Git ignore rules
│
├── terraform/                   # Terraform infrastructure code
│   ├── main.tf                  # Main infrastructure resources
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Output values
│   ├── lambda.tf                # Lambda function configuration
│   ├── cloudfront.tf            # CloudFront distribution
│   ├── terraform.tfvars.example # Example configuration
│   └── README.md                # Terraform documentation
│
├── lambda/                      # Lambda function code
│   ├── index.py                 # Main Lambda handler
│   ├── requirements.txt         # Python dependencies
│   ├── build.sh                 # Build deployment package
│   └── README.md                # Lambda documentation
│
├── scripts/                     # Utility scripts
│   ├── deploy.sh                # One-click deployment
│   ├── test-api.sh              # API testing script
│   ├── generate-keys.sh         # Generate CloudFront key pair
│   └── cleanup.sh               # Destroy infrastructure
│
├── docs/                        # Documentation
│   ├── API.md                   # API documentation
│   ├── DEPLOYMENT.md            # Deployment guide
│   ├── ARCHITECTURE.md          # Architecture details
│   ├── TROUBLESHOOTING.md       # Common issues and solutions
│   └── SECURITY.md              # Security best practices
│
└── examples/                    # Integration examples
    ├── javascript/              # JavaScript/TypeScript examples
    ├── python/                  # Python examples
    └── curl/                    # cURL examples
```

## 📚 Documentation

- **[API Documentation](docs/API.md)** - Complete API reference with examples
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Step-by-step deployment instructions
- **[Architecture Guide](docs/ARCHITECTURE.md)** - Detailed architecture explanation
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Security Guide](docs/SECURITY.md)** - Security best practices

## 🔑 Key Features

### CloudFront Signed URLs

- **Time-Limited Access** - URLs expire after configured duration
- **PUT and GET Support** - Upload and download with signed URLs
- **Custom Domain** - Use your own domain instead of CloudFront default
- **Secure** - Private key stored in AWS Secrets Manager

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

Run the automated test suite:

```bash
# Test complete upload/download flow
./scripts/test-api.sh

# Or use the examples
cd examples/curl
./test-flow.sh
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- AWS CloudFront team for signed URL documentation
- Terraform AWS provider maintainers
- Community contributors

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/cloudfront-signed-urls-demo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USERNAME/cloudfront-signed-urls-demo/discussions)
- **Email**: your.email@example.com

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
- ✅ Custom domain support
- ✅ API Gateway integration
- ✅ Lambda function deployed
- ✅ Documentation complete
- ⏳ Frontend application (in progress)
- ⏳ Authentication (planned)

---

**Made with ❤️ for secure file sharing**

**Star ⭐ this repo if you find it helpful!**

