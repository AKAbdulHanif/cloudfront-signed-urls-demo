# Service Catalog Module Architecture: CloudFront Signed URLs

This document outlines the proposed architecture for a set of AWS Service Catalog modules that enable teams to provision the necessary infrastructure for using CloudFront Signed URLs with custom domains for secure file uploads and downloads.

## Guiding Principles

- **Modularity:** Each core component of the architecture is broken down into a separate, composable module.
- **Self-Service:** Modules are designed to be provisioned by development teams with minimal operational overhead.
- **Flexibility:** Teams can choose to provision only the modules they need, integrating with their existing applications and infrastructure.
- **Security by Design:** The modules enforce security best practices, such as private S3 buckets, secure key storage, and time-limited access.

## Proposed Module Architecture

The following diagram illustrates the proposed Service Catalog modules and their relationships:

```mermaid
graph TD
    subgraph "Service Catalog Products"
        A[CloudFront Distribution Module]
        B[S3 Bucket Module]
        C[CloudFront Key Pair Module]
        D[Secrets Manager Private Key Module]
        E[DynamoDB Metadata Table Module (Optional)]
        F[IAM Integration Role Module]
    end

    subgraph "Team's Existing Application"
        G[Application API (e.g., Lambda, ECS)]
    end

    A --> B
    A --> C
    A --> D
    G --> D
    G --> E
    G --> F
```

## Module Descriptions

### 1. CloudFront Distribution Module

- **Purpose:** Provisions a CloudFront distribution configured for signed URLs and dual-path (upload/download) behaviors.
- **Inputs:**
    - `CustomDomainName` (e.g., `files.example.com`)
    - `AcmCertificateArn`
    - `S3BucketName`
    - `CloudFrontKeyGroupId`
- **Outputs:**
    - `CloudFrontDistributionId`
    - `CloudFrontDistributionDomainName`

### 2. S3 Bucket Module

- **Purpose:** Provisions a private S3 bucket for storing files.
- **Inputs:**
    - `BucketName` (optional, can be auto-generated)
    - `LifecycleConfiguration` (optional)
- **Outputs:**
    - `S3BucketName`
    - `S3BucketArn`

### 3. CloudFront Key Pair Module

- **Purpose:** Generates a public/private key pair for CloudFront signed URLs. The public key is created in CloudFront, and the private key is stored in Secrets Manager.
- **Inputs:**
    - `KeyGroupName`
- **Outputs:**
    - `CloudFrontPublicKeyId`
    - `CloudFrontKeyGroupId`
    - `PrivateKeySecretArn`

### 4. Secrets Manager Private Key Module

- **Purpose:** Stores the private key for signing CloudFront URLs in AWS Secrets Manager.
- **Inputs:**
    - `SecretName`
    - `PrivateKey`
- **Outputs:**
    - `PrivateKeySecretArn`

### 5. DynamoDB Metadata Table Module (Optional)

- **Purpose:** Provisions a DynamoDB table for storing file metadata.
- **Inputs:**
    - `TableName`
    - `PrimaryKey`
- **Outputs:**
    - `DynamoDbTableName`
    - `DynamoDbTableArn`

### 6. IAM Integration Role Module

- **Purpose:** Creates an IAM role that a team's application can assume to get temporary credentials for generating signed URLs.
- **Inputs:**
    - `ApplicationRoleName`
    - `PrivateKeySecretArn`
    - `DynamoDbTableArn` (optional)
- **Outputs:**
    - `IntegrationRoleArn`

## Consumption Workflow

1.  A development team decides to implement secure file uploads.
2.  They provision the required Service Catalog modules, either individually or as a portfolio.
3.  They configure their application to assume the `IntegrationRoleArn` provided by the IAM Integration Role Module.
4.  The application uses the assumed credentials to retrieve the private key from Secrets Manager.
5.  The application can now generate CloudFront signed URLs for upload and download operations.

This modular approach provides a clear and secure path for teams to adopt CloudFront signed URLs without needing to become experts in the underlying infrastructure.

