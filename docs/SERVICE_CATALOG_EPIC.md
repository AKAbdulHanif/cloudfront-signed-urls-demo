# Epic: CloudFront Signed URLs as a Self-Service Capability

**Epic ID:** INFRA-SC-001  
**Status:** Proposed  
**Priority:** High  
**Target Quarter:** Q1 2026  
**Author:** Platform Engineering Team  
**Last Updated:** October 19, 2025

---

## Executive Summary

This epic outlines the development and rollout of a self-service infrastructure capability that enables development teams to provision CloudFront distributions with signed URL support for secure file uploads and downloads. The capability addresses a critical business need for GBS customers who require a single whitelisted domain for file access, while also providing a standardized, secure, and scalable pattern for all teams handling file operations.

The proposed solution leverages AWS Service Catalog to provide modular, composable infrastructure components that teams can provision on-demand. This approach aligns with the organization's journey toward self-service delegated access and reduces the operational burden on the platform team while maintaining security and compliance standards.

---

## Business Context

### Problem Statement

Development teams across the organization require secure file upload and download capabilities for various use cases, including document management, export functionality, secure messaging attachments, and payment processing. Currently, teams face several challenges when implementing these features.

First, corporate firewall restrictions prevent customers from accessing files stored in S3 buckets with wildcard domain patterns such as `*.s3.eu-west-1.amazonaws.com`. This limitation blocks critical business functionality for GBS customers, who represent a significant revenue stream. Second, teams lack a standardized approach to implementing secure file handling, leading to inconsistent security postures and increased operational overhead. Third, the absence of a self-service infrastructure pattern means that teams must engage the platform team for each new implementation, creating bottlenecks and delaying time-to-market.

### Business Value

The implementation of CloudFront Signed URLs as a self-service capability delivers measurable business value across multiple dimensions. From a revenue protection perspective, the solution unblocks GBS customers who are currently unable to access critical features due to firewall restrictions. This prevents potential revenue loss and improves customer satisfaction. The single custom domain approach means that customers only need to whitelist one domain (e.g., `files.example.com`) rather than managing complex wildcard patterns or bucket-specific URLs.

From an operational efficiency standpoint, the self-service model reduces the platform team's workload by enabling development teams to provision infrastructure independently. This accelerates time-to-market for new features and reduces the cycle time for implementing file handling capabilities. The standardized approach also reduces the cognitive load on development teams, as they no longer need to become experts in CloudFront, S3 security, and signed URL generation.

Security and compliance benefits are equally significant. The solution enforces security best practices by default, including private S3 buckets, time-limited access through signed URLs, and secure key storage in AWS Secrets Manager. The architecture supports GDPR compliance through proper access controls and audit trails. Additionally, the modular design allows for future enhancements such as data classification controls and geographic restrictions.

### Success Metrics

The success of this initiative will be measured through several key performance indicators. Adoption metrics include the number of teams provisioning the Service Catalog modules within the first six months (target: 10+ teams), the reduction in platform team tickets related to file handling infrastructure (target: 50% reduction), and the time-to-provision for new file handling capabilities (target: under 2 hours from request to production-ready).

Business impact metrics focus on customer satisfaction improvements for GBS customers (measured through support ticket reduction), the number of previously blocked features that are now accessible (target: 100% of identified use cases), and revenue protection through prevented customer churn.

Technical quality metrics include security compliance scores from AWS Security Hub and GuardDuty (target: 100% compliance), infrastructure provisioning success rate (target: 95%+), and CloudFront signed URL validation success rate (target: 99.9%+).

---

## Technical Architecture

### Current State

The organization currently operates approximately 120 AWS accounts with infrastructure provisioned primarily through CloudFormation templates and Jenkins pipelines. Teams have access to a self-service catalog for basic CloudFront and S3 static hosting (GET operations only), but this does not support file uploads (PUT operations) or signed URLs. Development teams use separate Jenkins instances per product group for orchestration, and templates are fragmented across projects.

For file handling, teams typically implement custom solutions using direct S3 pre-signed URLs, which expose bucket-specific domains that cannot be whitelisted by corporate firewalls. There is no standardized approach to key management, signed URL generation, or secure file access patterns.

### Target State Architecture

The target state introduces a modular, self-service infrastructure pattern based on AWS Service Catalog. The architecture consists of six core modules that can be provisioned independently or as a complete portfolio. The following diagram illustrates the overall architecture and data flow.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Development Team                              │
│  ┌────────────────┐         ┌──────────────────┐                   │
│  │  Application   │────────▶│  Service Catalog │                   │
│  │  (Lambda/ECS)  │         │    Portfolio     │                   │
│  └────────────────┘         └──────────────────┘                   │
│         │                            │                               │
│         │                            ▼                               │
│         │              ┌──────────────────────────┐                 │
│         │              │   Provisioned Resources  │                 │
│         │              │  - CloudFront Dist.      │                 │
│         │              │  - S3 Bucket             │                 │
│         │              │  - Key Pair              │                 │
│         │              │  - Secrets Manager       │                 │
│         │              │  - IAM Role              │                 │
│         │              └──────────────────────────┘                 │
│         │                            │                               │
└─────────┼────────────────────────────┼───────────────────────────────┘
          │                            │
          ▼                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS Infrastructure                           │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    CloudFront Distribution                     │  │
│  │  Custom Domain: files.example.com                             │  │
│  │                                                                 │  │
│  │  Behavior 1: /uploads/*                                        │  │
│  │  - Methods: PUT, POST, DELETE                                  │  │
│  │  - OAC: Disabled (allows PUT to S3)                           │  │
│  │  - Signed URLs: Required                                       │  │
│  │                                                                 │  │
│  │  Behavior 2: /* (default)                                      │  │
│  │  - Methods: GET, HEAD                                          │  │
│  │  - OAC: Enabled (secure S3 access)                            │  │
│  │  - Signed URLs: Required                                       │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                            │                                         │
│                            ▼                                         │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      S3 Bucket (Private)                       │  │
│  │  - Bucket Policy: CloudFront OAC only                         │  │
│  │  - Encryption: AES-256                                         │  │
│  │  - Versioning: Enabled                                         │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    AWS Secrets Manager                         │  │
│  │  - CloudFront Private Key (RSA-2048, PKCS#1)                  │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                  DynamoDB Table (Optional)                     │  │
│  │  - File Metadata Storage                                       │  │
│  │  - TTL Enabled                                                 │  │
│  └──────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────┘
```

### Module Breakdown

The architecture is decomposed into six Service Catalog modules, each with a specific responsibility and clear interfaces.

**CloudFront Distribution Module** provisions a CloudFront distribution configured with dual-path behaviors to support both uploads and downloads. The module accepts parameters for custom domain name, ACM certificate ARN, S3 bucket name, and CloudFront key group ID. It outputs the CloudFront distribution ID and domain name. The module automatically configures two cache behaviors: one for `/uploads/*` that allows PUT, POST, and DELETE operations without Origin Access Control (OAC), and a default behavior for `/*` that allows GET and HEAD operations with OAC enabled. Both behaviors require signed URLs through the specified key group.

**S3 Bucket Module** creates a private S3 bucket with security best practices enforced by default. The module accepts an optional bucket name (auto-generated if not provided) and lifecycle configuration parameters. It outputs the bucket name and ARN. The bucket is configured with server-side encryption using AES-256, versioning enabled, and a bucket policy that restricts access exclusively to the CloudFront distribution via OAC. Public access is explicitly blocked through bucket-level settings.

**CloudFront Key Pair Module** generates the cryptographic keys required for signing CloudFront URLs. The module accepts a key group name as input and outputs the CloudFront public key ID, key group ID, and the ARN of the secret containing the private key. Internally, the module generates an RSA-2048 key pair, uploads the public key to CloudFront, creates a key group containing the public key, and stores the private key in AWS Secrets Manager in PKCS#1 format.

**Secrets Manager Private Key Module** provides secure storage for the CloudFront private key. The module accepts a secret name and the private key value as inputs, and outputs the secret ARN. The secret is configured with automatic rotation disabled (as CloudFront key pairs should be rotated manually with proper coordination), encryption at rest using AWS KMS, and resource-based policies that restrict access to authorized IAM roles.

**DynamoDB Metadata Table Module** is an optional component that provisions a DynamoDB table for storing file metadata. The module accepts a table name and primary key definition as inputs, and outputs the table name and ARN. The table is configured with on-demand billing mode to accommodate variable workloads, TTL enabled for automatic cleanup of expired metadata, and point-in-time recovery enabled for data protection.

**IAM Integration Role Module** creates an IAM role that development teams' applications can assume to access the necessary resources for generating signed URLs. The module accepts the application role name, private key secret ARN, and optional DynamoDB table ARN as inputs, and outputs the integration role ARN. The role is configured with a trust policy that allows assumption by the team's application (Lambda function, ECS task, or EC2 instance), permissions to read the private key from Secrets Manager, permissions to read and write file metadata to DynamoDB (if provisioned), and appropriate resource-level restrictions to enforce least privilege access.

### Integration Pattern

Development teams integrate with the provisioned infrastructure through a standardized pattern. First, the team provisions the required Service Catalog modules, either individually or as a complete portfolio. The team then configures their application (Lambda function, ECS container, or EC2 instance) to assume the IAM integration role provided by the IAM Integration Role Module.

When a file upload or download is requested, the application assumes the integration role to obtain temporary credentials. Using these credentials, the application retrieves the CloudFront private key from AWS Secrets Manager. The application then generates a CloudFront signed URL using the private key, specifying the appropriate policy (custom policy for uploads with PUT method allowed, canned policy for downloads with GET method). The signed URL is returned to the client, who uses it to upload or download the file directly through CloudFront.

For uploads, the client sends a PUT request to the signed URL at the `/uploads/*` path. CloudFront validates the signature, and if valid, forwards the request to the S3 bucket without OAC restrictions. For downloads, the client sends a GET request to the signed URL at the default path. CloudFront validates the signature and uses OAC to securely retrieve the file from the S3 bucket.

### Security Architecture

The security architecture implements defense-in-depth principles across multiple layers. At the network layer, CloudFront enforces HTTPS-only access with TLS 1.2 minimum protocol version, custom domain with ACM certificate for trusted communication, and geographic restrictions (if required by compliance).

At the access control layer, signed URLs provide time-limited access with cryptographic validation, separate behaviors for uploads and downloads enforce least privilege, and OAC ensures that the S3 bucket is accessible only through CloudFront for download operations. IAM roles enforce least privilege access to Secrets Manager and DynamoDB, with resource-level permissions restricting access to specific secrets and tables.

At the data layer, S3 server-side encryption protects data at rest using AES-256, bucket versioning enables recovery from accidental deletions or modifications, and private bucket configuration with explicit public access blocks prevents unauthorized access. Secrets Manager provides encrypted storage for the CloudFront private key with audit logging through CloudTrail.

Compliance and audit capabilities include CloudTrail logging of all API calls related to infrastructure provisioning and key access, CloudWatch metrics and alarms for monitoring CloudFront error rates and Lambda function errors, AWS Security Hub and GuardDuty integration for continuous security posture assessment, and DynamoDB metadata table providing an audit trail of file operations.

---

## Implementation Plan

### Phase 1: Module Development (Weeks 1-4)

The first phase focuses on developing and testing the core Service Catalog modules. During weeks 1-2, the team will develop the S3 Bucket Module, CloudFront Key Pair Module, and Secrets Manager Private Key Module. These foundational modules have no dependencies on each other and can be developed in parallel. Each module will include comprehensive input validation, output definitions, and error handling.

During weeks 3-4, the team will develop the CloudFront Distribution Module, IAM Integration Role Module, and DynamoDB Metadata Table Module. These modules depend on the outputs from the foundational modules and will integrate with them through parameter passing. Unit tests will be developed for each module to validate input validation, resource creation, and output generation.

### Phase 2: Integration Testing (Weeks 5-6)

The second phase validates that the modules work together correctly as an integrated system. During week 5, the team will provision the complete portfolio in a development AWS account and execute end-to-end tests covering file upload flows (generate signed URL, upload file via PUT, verify file in S3) and file download flows (generate signed URL, download file via GET, verify content). The team will also test error scenarios including expired signed URLs, invalid signatures, and missing permissions.

During week 6, the team will conduct security testing including penetration testing of signed URL validation, verification of OAC restrictions, and validation of IAM role permissions. Performance testing will measure CloudFront response times, S3 upload/download throughput, and signed URL generation latency. The team will also validate compliance with organizational security standards using AWS Security Hub and GuardDuty.

### Phase 3: Documentation and Onboarding (Weeks 7-8)

The third phase prepares the capability for rollout to development teams. During week 7, the team will create module documentation including README files with inputs, outputs, and usage examples, architecture diagrams illustrating data flows and security controls, and troubleshooting guides for common issues. The team will also develop an onboarding guide that provides a step-by-step walkthrough of provisioning the portfolio, code snippets for integrating with the IAM role and generating signed URLs, and best practices for key rotation and security.

During week 8, the team will create training materials including a recorded demo of the provisioning and integration process, a FAQ document addressing common questions, and a Slack channel or support forum for ongoing assistance. The team will also develop runbooks for the platform team covering monitoring and alerting setup, incident response procedures, and key rotation processes.

### Phase 4: Pilot Rollout (Weeks 9-12)

The fourth phase validates the capability with a limited set of early adopter teams. During weeks 9-10, the team will identify 3-5 pilot teams representing diverse use cases (e.g., document management, export functionality, secure messaging) and onboard them through guided provisioning sessions. The platform team will provide hands-on support during initial integration and collect feedback on documentation clarity and module usability.

During weeks 11-12, the team will monitor pilot deployments for errors, performance issues, and security incidents. Based on feedback, the team will iterate on documentation, add missing features or parameters, and refine the onboarding process. Success criteria for the pilot phase include 100% successful provisioning rate, zero security incidents, and positive feedback from pilot teams on ease of use.

### Phase 5: General Availability (Weeks 13-16)

The final phase makes the capability available to all development teams. During week 13, the team will publish the Service Catalog portfolio to all AWS accounts and announce the capability through internal communication channels (Slack, email, wiki). The team will also schedule office hours for teams to ask questions and get support.

During weeks 14-16, the team will monitor adoption metrics including the number of teams provisioning the portfolio and the number of CloudFront distributions created. The team will continue to provide support through the Slack channel and office hours, and will collect feedback for future enhancements. The team will also establish ongoing maintenance processes including quarterly security reviews, monthly cost optimization analysis, and continuous monitoring of AWS service updates that may impact the modules.

---

## Cost Estimation

### Infrastructure Costs

The cost of running CloudFront Signed URLs infrastructure varies based on usage patterns, but the following estimates provide a baseline for planning purposes. All costs are estimated in USD per month.

**CloudFront Distribution** costs depend on data transfer and request volume. For a typical application with 1 TB of data transfer out to the internet and 10 million requests per month, the estimated cost is approximately $85 per month ($0.085 per GB for the first 10 TB plus $0.0075 per 10,000 HTTPS requests). For higher-volume applications with 10 TB of data transfer and 100 million requests, the estimated cost increases to approximately $750 per month.

**S3 Storage** costs are based on the amount of data stored and the number of requests. For 100 GB of standard storage with 1 million PUT requests and 10 million GET requests, the estimated cost is approximately $2.30 for storage plus $5.00 for PUT requests plus $4.00 for GET requests, totaling $11.30 per month. For 1 TB of storage with proportionally higher request volumes, the estimated cost is approximately $115 per month.

**AWS Secrets Manager** charges $0.40 per secret per month plus $0.05 per 10,000 API calls. For a typical application with one secret and 100,000 API calls per month, the estimated cost is $0.90 per month.

**DynamoDB** costs depend on read/write capacity and storage. Using on-demand pricing with 1 million write requests, 10 million read requests, and 1 GB of storage, the estimated cost is approximately $1.25 for writes plus $2.50 for reads plus $0.25 for storage, totaling $4.00 per month.

**ACM Certificate** for custom domains is provided at no additional charge when used with CloudFront.

**Route53 Hosted Zone** costs $0.50 per hosted zone per month plus $0.40 per million queries. For a typical application with 10 million queries per month, the estimated cost is $4.50 per month.

**Total Estimated Monthly Cost** for a typical application (1 TB CloudFront transfer, 100 GB S3 storage, moderate DynamoDB usage) is approximately $105-$110 per month. For a high-volume application (10 TB CloudFront transfer, 1 TB S3 storage, high DynamoDB usage), the estimated cost is approximately $875-$900 per month.

### Development and Maintenance Costs

The initial development effort is estimated at 8 weeks of platform engineering time (1-2 engineers), representing approximately 320-640 hours of effort. Ongoing maintenance is estimated at 20 hours per month for monitoring, support, and updates. Training and onboarding for development teams is estimated at 2 hours per team for initial onboarding and 1 hour per quarter for ongoing support.

### Cost Optimization Opportunities

Several opportunities exist to optimize costs as the capability scales. CloudFront Reserved Capacity can provide discounts of up to 30% for committed usage levels. S3 Intelligent-Tiering can automatically move infrequently accessed files to lower-cost storage tiers, reducing storage costs by up to 70%. DynamoDB Reserved Capacity can provide discounts of up to 50% for predictable workloads. Lifecycle policies can automatically delete expired files and metadata, reducing storage costs over time.

---

## Risks and Mitigation

### Technical Risks

**Risk:** CloudFront key pair mismatch between public and private keys leads to signature validation failures. **Impact:** High - All signed URLs fail validation, blocking file uploads and downloads. **Mitigation:** Implement automated testing that validates key pair matching during module provisioning. Store key pair metadata (public key ID, creation timestamp) in Secrets Manager alongside the private key. Develop a key rotation runbook that ensures public and private keys are always synchronized.

**Risk:** OAC limitation prevents PUT operations, requiring separate behavior without OAC. **Impact:** Medium - Upload path has single-layer security (signed URLs only) instead of dual-layer (signed URLs + OAC). **Mitigation:** Clearly document the security model in module documentation. Enforce short expiration times (15 minutes) for upload signed URLs to minimize exposure window. Monitor AWS service updates for potential OAC support for PUT operations.

**Risk:** Lambda package build failures due to platform-specific dependencies (cryptography library). **Impact:** Medium - Developers on Apple Silicon Macs cannot build Lambda packages locally. **Mitigation:** Provide Docker-based build scripts that target Linux x86_64 architecture. Include pre-built Lambda packages in the Service Catalog modules. Document the build process clearly in the onboarding guide.

### Operational Risks

**Risk:** Teams misconfigure IAM roles, granting excessive permissions. **Impact:** Medium - Potential security vulnerabilities and compliance violations. **Mitigation:** Provide pre-configured IAM role templates with least privilege permissions. Implement AWS Config rules that detect overly permissive IAM policies. Conduct quarterly security reviews of all provisioned resources.

**Risk:** Lack of monitoring leads to undetected failures. **Impact:** Medium - Poor user experience and potential revenue impact. **Mitigation:** Include CloudWatch dashboards and alarms in the Service Catalog modules. Provide runbooks for common failure scenarios. Establish SLAs for platform team response times.

**Risk:** Key rotation process is unclear or undocumented. **Impact:** Low - Keys remain in use beyond recommended rotation period, increasing security risk. **Mitigation:** Develop and document a key rotation runbook. Implement CloudWatch alarms that trigger when keys are older than 90 days. Provide automated scripts for key rotation where possible.

### Adoption Risks

**Risk:** Teams find the modules too complex or difficult to use. **Impact:** High - Low adoption rate, failure to achieve business objectives. **Mitigation:** Conduct usability testing with pilot teams before general availability. Provide comprehensive documentation and training materials. Offer office hours and dedicated support during initial rollout.

**Risk:** Competing priorities delay team adoption. **Impact:** Medium - Slower-than-expected adoption, delayed business value realization. **Mitigation:** Secure executive sponsorship to prioritize adoption. Demonstrate quick wins with pilot teams. Communicate business value clearly to development teams and their leadership.

---

## Dependencies

### Internal Dependencies

The successful implementation of this epic depends on several internal factors. The platform engineering team must have capacity to dedicate 1-2 engineers for 8 weeks during the development phase. AWS account access with appropriate permissions to create Service Catalog products and IAM roles is required. The organization must have an existing Route53 hosted zone for custom domain configuration, or be willing to create one as part of the implementation.

Development teams must have applications that require file upload/download capabilities and be willing to participate in the pilot program. The security team must review and approve the security architecture before general availability rollout. The organization must have existing monitoring and alerting infrastructure (CloudWatch, Datadog) that can be integrated with the new capability.

### External Dependencies

External dependencies are minimal, as the solution relies entirely on AWS managed services. However, the implementation does depend on AWS service availability and SLAs for CloudFront, S3, Secrets Manager, DynamoDB, and IAM. The organization must have an existing relationship with AWS for support escalations if needed.

For custom domain configuration, the organization must own the domain name and have the ability to create DNS records. If using an external DNS provider (not Route53), the team must have access to create CNAME records for ACM certificate validation and CloudFront distribution aliases.

---

## Success Criteria

### Quantitative Metrics

The success of this initiative will be measured through specific, quantitative metrics tracked over a six-month period following general availability. Adoption metrics include at least 10 teams provisioning the Service Catalog portfolio within six months, at least 20 CloudFront distributions created using the modules, and a 50% reduction in platform team tickets related to file handling infrastructure.

Business impact metrics include zero revenue loss due to GBS customer firewall restrictions, 100% of identified blocked features now accessible, and a customer satisfaction score improvement of at least 10 points for affected customers.

Technical quality metrics include 95%+ infrastructure provisioning success rate, 99.9%+ CloudFront signed URL validation success rate, 100% compliance score from AWS Security Hub and GuardDuty, and zero security incidents related to the provisioned infrastructure.

### Qualitative Metrics

Qualitative success criteria focus on user experience and organizational impact. Development teams should report that the modules are easy to understand and use, with clear documentation and examples. Teams should feel empowered to provision infrastructure independently without requiring platform team assistance. The platform team should report reduced operational burden and increased capacity for strategic initiatives.

From a security perspective, the security team should confirm that the architecture meets organizational security standards and compliance requirements. The solution should be perceived as a best practice pattern that other infrastructure capabilities should emulate.

---

## Future Enhancements

### Short-Term Enhancements (3-6 months)

Several enhancements can be implemented in the short term to expand the capability's value. Data classification controls can be added to enforce different access policies based on file sensitivity (OFFICIAL vs OFFICIAL-SENSITIVE). Geographic restrictions can be implemented through CloudFront geo-blocking to comply with data residency requirements. Automated key rotation can be developed to reduce operational burden and improve security posture.

Integration with organizational identity providers (Okta) can enable user-level access controls in addition to application-level controls. CloudWatch dashboards and alarms can be enhanced to provide deeper visibility into usage patterns and performance metrics. Cost allocation tags can be added to enable chargeback or showback to development teams.

### Long-Term Enhancements (6-12 months)

Longer-term enhancements can further extend the capability's reach and impact. Multi-region support can be added to improve performance for global users and provide disaster recovery capabilities. Integration with AWS WAF can provide protection against common web exploits and DDoS attacks. Support for additional file operations (DELETE, PATCH) can enable more complex file management workflows.

Integration with organizational data loss prevention (DLP) tools can provide automated scanning of uploaded files for sensitive data. Support for large file uploads (multi-part upload) can enable handling of files larger than 5 GB. Integration with organizational backup and recovery solutions can provide additional data protection.

A self-service portal UI can be developed to provide a graphical interface for provisioning modules, generating signed URLs, and monitoring usage. This would complement the Service Catalog approach and provide an alternative for teams that prefer UI-based workflows.

---

## Appendix A: Module Specifications

### CloudFront Distribution Module

**Module Name:** `cloudfront-signed-urls-distribution`  
**Version:** 1.0.0  
**Description:** Provisions a CloudFront distribution with dual-path behaviors for signed URL support.

**Input Parameters:**

| Parameter | Type | Required | Description | Default |
| :--- | :--- | :--- | :--- | :--- |
| `CustomDomainName` | String | Yes | Custom domain name for the CloudFront distribution | - |
| `AcmCertificateArn` | String | Yes | ARN of the ACM certificate for the custom domain | - |
| `S3BucketName` | String | Yes | Name of the S3 bucket to use as the origin | - |
| `CloudFrontKeyGroupId` | String | Yes | ID of the CloudFront key group for signed URLs | - |
| `PriceClass` | String | No | CloudFront price class | `PriceClass_100` |
| `MinTTL` | Number | No | Minimum TTL for cached objects (seconds) | `0` |
| `DefaultTTL` | Number | No | Default TTL for cached objects (seconds) | `86400` |
| `MaxTTL` | Number | No | Maximum TTL for cached objects (seconds) | `31536000` |

**Output Parameters:**

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `CloudFrontDistributionId` | String | ID of the CloudFront distribution |
| `CloudFrontDistributionDomainName` | String | Domain name of the CloudFront distribution |
| `CloudFrontDistributionArn` | String | ARN of the CloudFront distribution |

### S3 Bucket Module

**Module Name:** `cloudfront-signed-urls-s3-bucket`  
**Version:** 1.0.0  
**Description:** Provisions a private S3 bucket with security best practices.

**Input Parameters:**

| Parameter | Type | Required | Description | Default |
| :--- | :--- | :--- | :--- | :--- |
| `BucketName` | String | No | Name of the S3 bucket (auto-generated if not provided) | Auto-generated |
| `VersioningEnabled` | Boolean | No | Enable versioning on the bucket | `true` |
| `LifecycleExpirationDays` | Number | No | Number of days after which objects are deleted (0 = disabled) | `0` |

**Output Parameters:**

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `S3BucketName` | String | Name of the S3 bucket |
| `S3BucketArn` | String | ARN of the S3 bucket |
| `S3BucketRegionalDomainName` | String | Regional domain name of the S3 bucket |

### CloudFront Key Pair Module

**Module Name:** `cloudfront-signed-urls-key-pair`  
**Version:** 1.0.0  
**Description:** Generates a CloudFront public/private key pair for signed URLs.

**Input Parameters:**

| Parameter | Type | Required | Description | Default |
| :--- | :--- | :--- | :--- | :--- |
| `KeyGroupName` | String | Yes | Name of the CloudFront key group | - |
| `SecretName` | String | No | Name of the Secrets Manager secret for the private key | Auto-generated |

**Output Parameters:**

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `CloudFrontPublicKeyId` | String | ID of the CloudFront public key |
| `CloudFrontKeyGroupId` | String | ID of the CloudFront key group |
| `PrivateKeySecretArn` | String | ARN of the Secrets Manager secret containing the private key |

### IAM Integration Role Module

**Module Name:** `cloudfront-signed-urls-iam-role`  
**Version:** 1.0.0  
**Description:** Creates an IAM role for application integration.

**Input Parameters:**

| Parameter | Type | Required | Description | Default |
| :--- | :--- | :--- | :--- | :--- |
| `ApplicationRoleName` | String | Yes | Name of the IAM role | - |
| `PrivateKeySecretArn` | String | Yes | ARN of the Secrets Manager secret containing the private key | - |
| `DynamoDbTableArn` | String | No | ARN of the DynamoDB table for metadata (optional) | - |
| `TrustedPrincipalArn` | String | Yes | ARN of the principal that can assume this role | - |

**Output Parameters:**

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `IntegrationRoleArn` | String | ARN of the IAM integration role |
| `IntegrationRoleName` | String | Name of the IAM integration role |

---

## Appendix B: Code Examples

### Python Example: Generating Signed URLs

```python
import boto3
import json
from datetime import datetime, timedelta
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.backends import default_backend
import base64
from urllib.parse import urlencode

class CloudFrontSigner:
    def __init__(self, key_pair_id, private_key_secret_arn, region='us-east-1'):
        self.key_pair_id = key_pair_id
        self.region = region
        
        # Retrieve private key from Secrets Manager
        secrets_client = boto3.client('secretsmanager', region_name=region)
        response = secrets_client.get_secret_value(SecretId=private_key_secret_arn)
        self.private_key_pem = response['SecretString']
        
        # Load private key
        self.private_key = serialization.load_pem_private_key(
            self.private_key_pem.encode('utf-8'),
            password=None,
            backend=default_backend()
        )
    
    def generate_signed_url_for_upload(self, domain, file_path, expiration_minutes=15):
        """Generate a signed URL for file upload (PUT operation)"""
        url = f"https://{domain}/uploads/{file_path}"
        expiration = datetime.utcnow() + timedelta(minutes=expiration_minutes)
        
        # Custom policy for PUT operation
        policy = {
            "Statement": [
                {
                    "Resource": url,
                    "Condition": {
                        "DateLessThan": {
                            "AWS:EpochTime": int(expiration.timestamp())
                        }
                    }
                }
            ]
        }
        
        return self._sign_url_with_custom_policy(url, policy)
    
    def generate_signed_url_for_download(self, domain, file_path, expiration_minutes=60):
        """Generate a signed URL for file download (GET operation)"""
        url = f"https://{domain}/{file_path}"
        expiration = datetime.utcnow() + timedelta(minutes=expiration_minutes)
        
        # Canned policy for GET operation
        return self._sign_url_with_canned_policy(url, expiration)
    
    def _sign_url_with_custom_policy(self, url, policy):
        """Sign URL with custom policy"""
        policy_json = json.dumps(policy, separators=(',', ':'))
        policy_base64 = base64.b64encode(policy_json.encode('utf-8')).decode('utf-8')
        policy_base64 = policy_base64.replace('+', '-').replace('=', '_').replace('/', '~')
        
        signature = self.private_key.sign(
            policy_json.encode('utf-8'),
            padding.PKCS1v15(),
            hashes.SHA1()
        )
        signature_base64 = base64.b64encode(signature).decode('utf-8')
        signature_base64 = signature_base64.replace('+', '-').replace('=', '_').replace('/', '~')
        
        params = {
            'Policy': policy_base64,
            'Signature': signature_base64,
            'Key-Pair-Id': self.key_pair_id
        }
        
        return f"{url}?{urlencode(params)}"
    
    def _sign_url_with_canned_policy(self, url, expiration):
        """Sign URL with canned policy"""
        policy = f"{{\"Statement\":[{{\"Resource\":\"{url}\",\"Condition\":{{\"DateLessThan\":{{\"AWS:EpochTime\":{int(expiration.timestamp())}}}}}}}}}"
        
        signature = self.private_key.sign(
            policy.encode('utf-8'),
            padding.PKCS1v15(),
            hashes.SHA1()
        )
        signature_base64 = base64.b64encode(signature).decode('utf-8')
        signature_base64 = signature_base64.replace('+', '-').replace('=', '_').replace('/', '~')
        
        params = {
            'Expires': int(expiration.timestamp()),
            'Signature': signature_base64,
            'Key-Pair-Id': self.key_pair_id
        }
        
        return f"{url}?{urlencode(params)}"

# Usage example
if __name__ == "__main__":
    signer = CloudFrontSigner(
        key_pair_id='K2PNHFE2BDB9MN',
        private_key_secret_arn='arn:aws:secretsmanager:us-east-1:123456789012:secret:cloudfront-private-key-abc123'
    )
    
    # Generate upload URL
    upload_url = signer.generate_signed_url_for_upload(
        domain='files.example.com',
        file_path='documents/report.pdf',
        expiration_minutes=15
    )
    print(f"Upload URL: {upload_url}")
    
    # Generate download URL
    download_url = signer.generate_signed_url_for_download(
        domain='files.example.com',
        file_path='documents/report.pdf',
        expiration_minutes=60
    )
    print(f"Download URL: {download_url}")
```

---

## Appendix C: References

This epic builds upon the successful proof of concept documented in the CloudFront Signed URLs Demo repository. The POC validated the technical architecture and demonstrated the business value of the proposed solution. Key learnings from the POC include the requirement for dual CloudFront behaviors to support both uploads and downloads, the importance of key pair synchronization between CloudFront and Secrets Manager, and the need for clear documentation and testing procedures.

The implementation plan incorporates best practices from AWS Well-Architected Framework, particularly the Security Pillar (least privilege access, encryption at rest and in transit, audit logging) and the Operational Excellence Pillar (infrastructure as code, automated testing, runbooks). The modular architecture aligns with the organization's journey toward self-service delegated access and standardized infrastructure patterns.

Cost estimates are based on AWS pricing as of October 2025 and assume US East (N. Virginia) region. Actual costs may vary based on usage patterns, region selection, and AWS pricing changes. Teams should monitor their actual costs through AWS Cost Explorer and implement cost allocation tags for accurate tracking.

---

**Document Version:** 1.0  
**Last Updated:** October 19, 2025  
**Next Review Date:** November 19, 2025

