# CloudFront Signed URLs - User Stories

## Epic 1: CloudFront Signed URLs POC

**Epic Description**: Implement and validate CloudFront Signed URLs as a solution to enable GBS customers in secured environments to download files without requiring wildcard S3 URL whitelisting.

**Business Context**: 
- GBS customers cannot download files from presigned S3 URLs (`https://*.s3.eu-west-1.amazonaws.com`) due to corporate firewall restrictions
- Impacts: Export, Secure Messaging, Paperless, and future FI Journey features
- Wildcard whitelisting poses security risks and accountability concerns
- Bucket-by-bucket whitelisting creates operational challenges
- V1 to DCP migration would require re-whitelisting

**Success Criteria**:
- POC deployed and tested in local/test environment
- Custom domain approach validated
- Documentation and deployment artifacts published to GitHub
- Solution approved for DCP deployment

---

### User Story 1.1: Infrastructure Setup and Key Generation

**As a** DevOps Engineer  
**I want to** set up the CloudFront infrastructure with automatic RSA key pair generation  
**So that** we can securely sign URLs without manual key management

**Acceptance Criteria**:
- [ ] Terraform infrastructure creates CloudFront distribution
- [ ] RSA key pair (2048-bit) is automatically generated
- [ ] Private key is stored in AWS Secrets Manager with encryption
- [ ] Public key is registered with CloudFront
- [ ] Key group is created and associated with CloudFront distribution
- [ ] S3 bucket is configured with Origin Access Control (OAC)
- [ ] All resources are tagged appropriately

**Technical Notes**:
- Use Terraform `tls_private_key` resource
- Private key must be in PKCS#1 format for CloudFront
- Secrets Manager provides automatic encryption with KMS

**Definition of Done**:
- Infrastructure deployed successfully
- Keys validated and working
- Security scan passed

---

### User Story 1.2: Custom Domain Configuration

**As a** Platform Engineer  
**I want to** configure a custom domain for CloudFront distribution  
**So that** customers can whitelist a single, predictable domain instead of wildcard S3 URLs

**Acceptance Criteria**:
- [ ] Route53 hosted zone is configured for the domain
- [ ] ACM certificate is created and validated for custom domain
- [ ] CloudFront distribution uses custom domain as CNAME
- [ ] DNS A and AAAA records point to CloudFront distribution
- [ ] SSL/TLS certificate is properly configured (TLS 1.2+)
- [ ] Custom domain is verified and accessible

**Example**:
- Custom domain: `cdn-demo.pe-labs.com`
- Customers whitelist: `cdn-demo.pe-labs.com` (single domain)
- No wildcard S3 URLs required

**Definition of Done**:
- Custom domain resolves correctly
- HTTPS works with valid certificate
- Files accessible via custom domain

---

### User Story 1.3: Lambda Function for Signed URL Generation

**As a** Backend Developer  
**I want to** implement a Lambda function that generates CloudFront signed URLs  
**So that** the API can provide time-limited, secure upload and download URLs

**Acceptance Criteria**:
- [ ] Lambda function retrieves private key from Secrets Manager
- [ ] Function generates signed URLs for uploads (PUT operations)
- [ ] Function generates signed URLs for downloads (GET operations)
- [ ] URLs include Policy, Signature, and Key-Pair-Id parameters
- [ ] Upload URLs expire after 15 minutes (configurable)
- [ ] Download URLs expire after 1 hour (configurable)
- [ ] Function caches private key per container for performance
- [ ] Error handling for key retrieval failures
- [ ] CloudWatch logging enabled

**Technical Implementation**:
- Use `cryptography` library for RSA-SHA1 signing
- Policy includes resource path and expiration time
- Signature is base64-encoded

**Definition of Done**:
- Lambda function deployed
- Unit tests passed
- Integration tests passed
- Performance benchmarks met (<500ms response time)

---

### User Story 1.4: API Gateway Integration

**As a** Frontend Developer  
**I want to** access RESTful API endpoints to generate upload and download URLs  
**So that** I can integrate file operations into the application

**Acceptance Criteria**:
- [ ] POST `/api/files/upload` endpoint generates upload URL
- [ ] GET `/api/files/download/{fileId}` endpoint generates download URL
- [ ] GET `/api/files` endpoint lists all files
- [ ] DELETE `/api/files/{fileId}` endpoint deletes files
- [ ] GET `/api/config` endpoint returns configuration
- [ ] CORS is properly configured for cross-origin requests
- [ ] API Gateway throttling is configured (5000 burst, 10000 rate)
- [ ] API documentation is available

**Request/Response Examples**:
```json
// POST /api/files/upload
Request: {"filename": "document.pdf", "contentType": "application/pdf"}
Response: {
  "success": true,
  "uploadUrl": "https://cdn-demo.pe-labs.com/uploads/abc123_document.pdf?Policy=...&Signature=...&Key-Pair-Id=...",
  "fileId": "abc123_document.pdf"
}
```

**Definition of Done**:
- All endpoints functional
- API documentation complete
- Postman collection created
- Integration tests passed

---

### User Story 1.5: File Metadata Management

**As a** System Administrator  
**I want to** track file metadata in DynamoDB  
**So that** we can manage file lifecycle and provide file listing functionality

**Acceptance Criteria**:
- [ ] DynamoDB table stores file metadata (file_id, filename, upload_time, etc.)
- [ ] TTL is configured to automatically delete old metadata (24 hours)
- [ ] Metadata is created when upload URL is generated
- [ ] Metadata is updated when file is uploaded
- [ ] Metadata is deleted when file is deleted
- [ ] List API queries DynamoDB for file information
- [ ] Point-in-time recovery is enabled (optional)

**Schema**:
```json
{
  "file_id": "abc123_document.pdf",
  "original_filename": "document.pdf",
  "content_type": "application/pdf",
  "object_key": "uploads/abc123_document.pdf",
  "upload_url_generated_at": "2025-10-16T10:00:00Z",
  "status": "uploaded",
  "ttl": 1697654321
}
```

**Definition of Done**:
- DynamoDB table created
- TTL working correctly
- Metadata operations functional

---

### User Story 1.6: End-to-End Testing

**As a** QA Engineer  
**I want to** validate the complete upload and download flow  
**So that** we can ensure the solution works for GBS customers

**Acceptance Criteria**:
- [ ] Upload flow tested: Generate URL → Upload file → Verify in S3
- [ ] Download flow tested: Generate URL → Download file → Verify content
- [ ] Custom domain verified in all signed URLs
- [ ] Expired URLs return 403 Forbidden
- [ ] Invalid signatures return 403 Forbidden
- [ ] File integrity verified (uploaded = downloaded)
- [ ] Performance benchmarks met (upload/download < 5s for 10MB file)
- [ ] Cross-browser testing completed (Chrome, Firefox, Safari, Edge)
- [ ] Mobile testing completed (iOS, Android)

**Test Scenarios**:
1. Happy path: Upload and download file successfully
2. Expired URL: URL expires after configured time
3. Invalid signature: Tampered URL returns 403
4. Large file: Upload/download 100MB file
5. Concurrent uploads: Multiple files uploaded simultaneously
6. Network interruption: Resume upload after connection loss

**Definition of Done**:
- All test scenarios passed
- Test report generated
- No critical or high-severity bugs

---

### User Story 1.7: Documentation and Knowledge Transfer

**As a** Technical Writer  
**I want to** create comprehensive documentation  
**So that** the team can understand, deploy, and maintain the solution

**Acceptance Criteria**:
- [ ] README.md with project overview and quick start
- [ ] Architecture documentation with diagrams
- [ ] API documentation with request/response examples
- [ ] Security best practices documented
- [ ] Custom domain testing guide created
- [ ] Deployment guide with step-by-step instructions
- [ ] Troubleshooting guide with common issues
- [ ] Integration examples (Python, JavaScript, cURL)
- [ ] Contributing guidelines

**Documentation Sections**:
1. Overview and business context
2. Architecture and components
3. Custom domain setup
4. API reference
5. Security considerations
6. Deployment instructions
7. Testing procedures
8. Troubleshooting
9. FAQ

**Definition of Done**:
- All documentation complete
- Peer review completed
- Published to GitHub
- Team walkthrough conducted

---

### User Story 1.8: GitHub Repository Publication

**As a** DevOps Engineer  
**I want to** publish the POC to a public GitHub repository  
**So that** the solution is version-controlled, shareable, and reusable

**Acceptance Criteria**:
- [ ] Repository created on GitHub
- [ ] All Terraform code committed
- [ ] Lambda function code committed
- [ ] Documentation committed
- [ ] Examples and scripts committed
- [ ] .gitignore excludes sensitive files (keys, state files)
- [ ] Repository topics added (aws, cloudfront, terraform, etc.)
- [ ] MIT license added
- [ ] README badges added (AWS, Terraform, Python)
- [ ] Repository is public

**Repository Structure**:
```
cloudfront-signed-urls-demo/
├── terraform/          # Infrastructure as Code
├── lambda/             # Lambda function
├── docs/               # Documentation
├── examples/           # Integration examples
├── scripts/            # Utility scripts
└── README.md           # Main documentation
```

**Definition of Done**:
- Repository published
- All files committed
- No sensitive data in repository
- Repository accessible to team

---

### User Story 1.9: POC Validation and Sign-off

**As a** Product Owner  
**I want to** validate the POC against business requirements  
**So that** we can approve the solution for DCP deployment

**Acceptance Criteria**:
- [ ] Solution addresses GBS customer firewall issue
- [ ] Custom domain approach eliminates wildcard S3 URL requirement
- [ ] Single domain whitelisting validated
- [ ] No operational overhead for new buckets/features
- [ ] V1 to DCP migration path clear
- [ ] Security review completed and approved
- [ ] Cost analysis completed (estimated $19/month for moderate usage)
- [ ] Stakeholder demo conducted
- [ ] Sign-off obtained from Product, Engineering, and Security teams

**Validation Checklist**:
- [x] Solves GBS customer issue
- [x] Custom domain works
- [x] No wildcard URLs required
- [x] Scalable solution
- [x] Secure implementation
- [x] Cost-effective
- [x] Well-documented

**Definition of Done**:
- POC approved for DCP deployment
- Formal sign-off documented
- Next steps defined

---

## Epic 2: DCP Deployment and Propagation

**Epic Description**: Deploy CloudFront Signed URLs solution to DCP (Digital Cloud Platform) environment, starting with infra-test account and propagating to DCP dev, test, and prod AWS accounts.

**Business Context**:
- POC validated and approved
- Need to deploy to DCP multi-account environment
- Must follow DCP governance and compliance requirements
- Requires environment-specific configurations
- Must support V1 to DCP migration path

**Success Criteria**:
- Solution deployed to infra-test account
- Solution deployed to DCP dev, test, and prod accounts
- Environment-specific configurations validated
- Monitoring and alerting configured
- Runbooks and operational procedures documented
- Production cutover completed

---

### User Story 2.1: DCP Environment Assessment

**As a** Cloud Architect  
**I want to** assess DCP environment requirements and constraints  
**So that** we can plan the deployment strategy

**Acceptance Criteria**:
- [ ] DCP account structure documented (infra-test, dev, test, prod)
- [ ] Network topology understood (VPCs, subnets, security groups)
- [ ] IAM policies and roles reviewed
- [ ] Service Control Policies (SCPs) identified
- [ ] Naming conventions documented
- [ ] Tagging requirements understood
- [ ] Compliance requirements identified (PCI-DSS, SOC2, etc.)
- [ ] Cost allocation tags defined
- [ ] Multi-region requirements clarified

**DCP Accounts**:
1. **infra-test**: Infrastructure testing and validation
2. **DCP Dev**: Development environment
3. **DCP Test**: Testing and QA environment
4. **DCP Prod**: Production environment

**Definition of Done**:
- Assessment document created
- Constraints identified
- Deployment plan drafted

---

### User Story 2.2: Terraform Backend Configuration for DCP

**As a** DevOps Engineer  
**I want to** configure Terraform remote backend for DCP environments  
**So that** state files are securely stored and shared across the team

**Acceptance Criteria**:
- [ ] S3 bucket created for Terraform state (per environment)
- [ ] DynamoDB table created for state locking
- [ ] Bucket versioning enabled
- [ ] Bucket encryption enabled (SSE-S3 or KMS)
- [ ] IAM policies configured for state access
- [ ] Backend configuration added to Terraform code
- [ ] State migration from local to remote completed
- [ ] Team access validated

**Backend Configuration Example**:
```hcl
terraform {
  backend "s3" {
    bucket         = "dcp-terraform-state-prod"
    key            = "cloudfront-signed-urls/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "dcp-terraform-locks"
    encrypt        = true
  }
}
```

**Definition of Done**:
- Remote backend configured
- State files migrated
- Team can collaborate on infrastructure

---

### User Story 2.3: Environment-Specific Configuration

**As a** Platform Engineer  
**I want to** create environment-specific Terraform configurations  
**So that** each DCP environment has appropriate settings

**Acceptance Criteria**:
- [ ] Separate `.tfvars` files for each environment
- [ ] Environment-specific domain names configured
- [ ] Environment-specific resource naming
- [ ] Environment-specific scaling parameters
- [ ] Environment-specific security settings
- [ ] Environment-specific monitoring settings
- [ ] Workspace strategy defined (if using Terraform workspaces)

**Environment Configurations**:

**infra-test.tfvars**:
```hcl
environment           = "infra-test"
custom_domain_enabled = true
domain_name          = "dcp-test.natwest.com"
subdomain            = "cdn-signed-urls"
lambda_memory_size   = 256
enable_cloudwatch_logs = true
```

**dev.tfvars**:
```hcl
environment           = "dev"
custom_domain_enabled = true
domain_name          = "dcp-dev.natwest.com"
subdomain            = "cdn"
lambda_memory_size   = 512
```

**test.tfvars**:
```hcl
environment           = "test"
custom_domain_enabled = true
domain_name          = "dcp-test.natwest.com"
subdomain            = "cdn"
lambda_memory_size   = 512
```

**prod.tfvars**:
```hcl
environment                   = "prod"
custom_domain_enabled         = true
domain_name                  = "natwest.com"
subdomain                    = "cdn"
lambda_memory_size           = 1024
enable_point_in_time_recovery = true
cloudfront_price_class       = "PriceClass_All"
```

**Definition of Done**:
- Environment configs created
- Configs reviewed and approved
- Naming conventions followed

---

### User Story 2.4: Infra-Test Deployment

**As a** DevOps Engineer  
**I want to** deploy the solution to infra-test account first  
**So that** we can validate the deployment process before promoting to higher environments

**Acceptance Criteria**:
- [ ] Terraform code deployed to infra-test account
- [ ] All resources created successfully
- [ ] Custom domain configured and validated
- [ ] Lambda function deployed and tested
- [ ] API Gateway endpoints tested
- [ ] CloudFront distribution tested
- [ ] Signed URLs validated
- [ ] Upload and download flows tested
- [ ] Monitoring dashboards created
- [ ] Logs verified in CloudWatch
- [ ] Security scan completed
- [ ] Deployment runbook validated

**Deployment Steps**:
1. Configure AWS credentials for infra-test account
2. Initialize Terraform with remote backend
3. Run `terraform plan` and review changes
4. Run `terraform apply` with infra-test.tfvars
5. Validate deployment
6. Run integration tests
7. Document any issues or deviations

**Definition of Done**:
- Infra-test deployment successful
- All tests passed
- Deployment documented
- Lessons learned captured

---

### User Story 2.5: DCP Dev Environment Deployment

**As a** DevOps Engineer  
**I want to** deploy the solution to DCP dev account  
**So that** developers can integrate and test the solution

**Acceptance Criteria**:
- [ ] Deployment plan reviewed and approved
- [ ] Change request submitted (if required)
- [ ] Terraform deployed to DCP dev account
- [ ] All resources created successfully
- [ ] Integration tests passed
- [ ] API documentation shared with dev team
- [ ] SDK/client libraries provided
- [ ] Developer onboarding completed
- [ ] Monitoring and alerting configured

**Integration Support**:
- API endpoint URLs provided
- Sample code and examples shared
- Postman collection provided
- Integration workshop conducted

**Definition of Done**:
- DCP dev deployment successful
- Developers can integrate
- No blocking issues

---

### User Story 2.6: DCP Test Environment Deployment

**As a** DevOps Engineer  
**I want to** deploy the solution to DCP test account  
**So that** QA team can perform comprehensive testing

**Acceptance Criteria**:
- [ ] Deployment plan reviewed and approved
- [ ] Change request submitted (if required)
- [ ] Terraform deployed to DCP test account
- [ ] All resources created successfully
- [ ] Test data loaded (if applicable)
- [ ] QA team onboarded
- [ ] Test scenarios documented
- [ ] Performance testing completed
- [ ] Security testing completed
- [ ] UAT sign-off obtained

**Testing Scope**:
- Functional testing
- Integration testing
- Performance testing
- Security testing
- User acceptance testing (UAT)

**Definition of Done**:
- DCP test deployment successful
- All testing completed
- UAT approved
- Ready for production

---

### User Story 2.7: DCP Prod Environment Deployment

**As a** Release Manager  
**I want to** deploy the solution to DCP prod account  
**So that** the solution is available for production use

**Acceptance Criteria**:
- [ ] Production readiness review completed
- [ ] Change Advisory Board (CAB) approval obtained
- [ ] Deployment window scheduled
- [ ] Rollback plan documented
- [ ] Communication plan executed
- [ ] Terraform deployed to DCP prod account
- [ ] All resources created successfully
- [ ] Smoke tests passed
- [ ] Monitoring dashboards validated
- [ ] Alerting tested
- [ ] Runbooks validated
- [ ] On-call team briefed
- [ ] Post-deployment validation completed

**Production Deployment Checklist**:
- [ ] CAB approval
- [ ] Deployment window: [Date/Time]
- [ ] Stakeholders notified
- [ ] Rollback plan ready
- [ ] On-call team available
- [ ] Deployment executed
- [ ] Smoke tests passed
- [ ] Monitoring active
- [ ] Post-deployment review scheduled

**Definition of Done**:
- Production deployment successful
- No critical issues
- Monitoring active
- Team trained

---

### User Story 2.8: Feature Migration Strategy

**As a** Product Manager  
**I want to** define a migration strategy for existing features  
**So that** Export, Secure Messaging, and Paperless can use CloudFront signed URLs

**Acceptance Criteria**:
- [ ] Current features using presigned S3 URLs identified
- [ ] Migration approach defined (big bang vs. phased)
- [ ] Feature flags implemented for gradual rollout
- [ ] API integration changes documented
- [ ] Frontend changes documented
- [ ] Backward compatibility maintained during migration
- [ ] Customer communication plan created
- [ ] Rollback strategy defined

**Features to Migrate**:
1. **Export**: Document export functionality
2. **Secure Messaging**: Attachment downloads
3. **Paperless**: Statement downloads
4. **FI Journey** (future): Payment-related file downloads

**Migration Approach**:
- **Phase 1**: Deploy infrastructure to all environments
- **Phase 2**: Migrate Export feature (low risk, low usage)
- **Phase 3**: Migrate Secure Messaging (medium risk)
- **Phase 4**: Migrate Paperless (high usage)
- **Phase 5**: Enable for FI Journey (revenue-critical)

**Definition of Done**:
- Migration strategy documented
- Stakeholders aligned
- Timeline agreed

---

### User Story 2.9: Customer Whitelisting Communication

**As a** Customer Success Manager  
**I want to** communicate the new domain to GBS customers  
**So that** they can whitelist the CloudFront domain and access files

**Acceptance Criteria**:
- [ ] Customer communication template created
- [ ] Whitelisting instructions documented
- [ ] Domain information provided: `cdn.natwest.com` (example)
- [ ] Timeline for migration communicated
- [ ] Support contact information provided
- [ ] FAQ document created
- [ ] Customer feedback mechanism established
- [ ] Communication sent to affected customers
- [ ] Customer confirmations tracked

**Communication Template**:
```
Subject: Action Required: Whitelist New Domain for File Downloads

Dear [Customer],

To improve security and reliability, we are migrating file downloads to a new 
CloudFront-based infrastructure. 

Action Required:
Please whitelist the following domain in your corporate firewall:
- Domain: cdn.natwest.com
- Protocol: HTTPS only
- Port: 443

This change will enable:
- Export functionality
- Secure messaging attachments
- Paperless statement downloads

Timeline:
- Migration Date: [Date]
- Support: [Contact Information]

Thank you for your cooperation.
```

**Definition of Done**:
- Communication sent
- Customer confirmations received
- Support tickets tracked

---

### User Story 2.10: Monitoring and Alerting

**As a** Site Reliability Engineer  
**I want to** implement comprehensive monitoring and alerting  
**So that** we can proactively detect and resolve issues

**Acceptance Criteria**:
- [ ] CloudWatch dashboards created for all environments
- [ ] Key metrics monitored (Lambda invocations, API Gateway requests, CloudFront requests)
- [ ] Error rate alerts configured
- [ ] Latency alerts configured
- [ ] Cost alerts configured
- [ ] Security alerts configured (failed signature validations)
- [ ] SNS topics created for notifications
- [ ] PagerDuty/OpsGenie integration configured
- [ ] Runbooks linked to alerts

**Key Metrics**:
- Lambda invocations, errors, duration
- API Gateway 4xx, 5xx errors, latency
- CloudFront requests, error rate, cache hit ratio
- S3 storage, requests
- DynamoDB read/write capacity, throttling
- Secrets Manager API calls

**Alerts**:
- **Critical**: Lambda errors > 10 in 5 minutes
- **Critical**: API Gateway 5xx > 5 in 5 minutes
- **Warning**: Lambda duration > 10 seconds
- **Warning**: CloudFront 5xx > 1% of requests
- **Info**: Daily cost exceeds threshold

**Definition of Done**:
- Monitoring configured
- Alerts tested
- On-call team trained

---

### User Story 2.11: Operational Runbooks

**As a** Operations Engineer  
**I want to** create operational runbooks  
**So that** the team can respond to incidents and perform routine operations

**Acceptance Criteria**:
- [ ] Deployment runbook created
- [ ] Rollback runbook created
- [ ] Incident response runbook created
- [ ] Key rotation runbook created
- [ ] Scaling runbook created
- [ ] Disaster recovery runbook created
- [ ] Troubleshooting guide created
- [ ] Runbooks tested in non-prod environments
- [ ] Runbooks published to team wiki/confluence

**Runbook Topics**:
1. **Deployment**: Step-by-step deployment procedure
2. **Rollback**: How to rollback a failed deployment
3. **Incident Response**: How to respond to alerts
4. **Key Rotation**: How to rotate CloudFront key pair
5. **Scaling**: How to adjust Lambda/API Gateway capacity
6. **DR**: How to recover from regional failure
7. **Troubleshooting**: Common issues and solutions

**Definition of Done**:
- All runbooks created
- Runbooks tested
- Team trained

---

### User Story 2.12: Security and Compliance Validation

**As a** Security Engineer  
**I want to** validate the solution against security and compliance requirements  
**So that** we meet NatWest security standards

**Acceptance Criteria**:
- [ ] Security architecture review completed
- [ ] Threat model created and reviewed
- [ ] Penetration testing completed
- [ ] Vulnerability scanning completed
- [ ] Compliance requirements validated (PCI-DSS, SOC2, GDPR)
- [ ] Data encryption validated (in transit and at rest)
- [ ] IAM policies reviewed (least privilege)
- [ ] Secrets management validated
- [ ] Audit logging enabled
- [ ] Security sign-off obtained

**Security Checklist**:
- [x] S3 bucket is private (no public access)
- [x] CloudFront validates signed URLs
- [x] Private key encrypted in Secrets Manager
- [x] HTTPS only (TLS 1.2+)
- [x] IAM roles follow least privilege
- [x] Encryption at rest for S3 and DynamoDB
- [x] Time-limited access (URLs expire)
- [x] CloudTrail logging enabled
- [x] VPC endpoints for AWS services (optional)

**Definition of Done**:
- Security review passed
- Compliance validated
- Sign-off obtained

---

### User Story 2.13: Cost Optimization and FinOps

**As a** FinOps Analyst  
**I want to** optimize costs and implement cost monitoring  
**So that** we operate within budget and identify optimization opportunities

**Acceptance Criteria**:
- [ ] Cost baseline established for each environment
- [ ] Cost allocation tags applied to all resources
- [ ] AWS Cost Explorer configured
- [ ] Budget alerts configured
- [ ] Reserved capacity evaluated (if applicable)
- [ ] Savings plans evaluated
- [ ] Cost optimization recommendations implemented
- [ ] Monthly cost review process established

**Cost Optimization Opportunities**:
1. **CloudFront**: Use appropriate price class
2. **Lambda**: Right-size memory allocation
3. **S3**: Use Intelligent-Tiering for infrequently accessed files
4. **DynamoDB**: Use on-demand vs. provisioned capacity
5. **CloudWatch**: Optimize log retention
6. **Data Transfer**: Minimize cross-region transfers

**Estimated Monthly Costs (Prod)**:
- CloudFront: $85 per TB transfer
- S3 Storage: $2.30 per 100GB
- Lambda: $2.00 per 1M requests
- API Gateway: $3.50 per 1M requests
- DynamoDB: $1.25 per 1M requests
- Other: $1.50
- **Total**: ~$95/month (assuming 1TB transfer, 100GB storage, 1M requests)

**Definition of Done**:
- Cost monitoring active
- Budget alerts configured
- Optimization plan documented

---

### User Story 2.14: V1 to DCP Migration Support

**As a** Migration Engineer  
**I want to** ensure seamless transition from V1 to DCP  
**So that** customers experience no disruption during migration

**Acceptance Criteria**:
- [ ] V1 presigned S3 URLs identified
- [ ] DCP CloudFront signed URLs ready
- [ ] Dual-run period defined (both V1 and DCP active)
- [ ] Feature flags implemented for gradual cutover
- [ ] Customer communication plan executed
- [ ] Monitoring for both V1 and DCP active
- [ ] Rollback plan documented
- [ ] V1 decommissioning plan created

**Migration Phases**:
1. **Pre-Migration**: Deploy DCP infrastructure
2. **Dual-Run**: Both V1 and DCP active (feature flag controlled)
3. **Gradual Cutover**: Migrate customers in batches
4. **Validation**: Monitor for issues
5. **Full Cutover**: All traffic to DCP
6. **V1 Decommission**: Shutdown V1 infrastructure

**Customer Impact**:
- **Before**: Whitelist `https://*.s3.eu-west-1.amazonaws.com` (wildcard)
- **After**: Whitelist `https://cdn.natwest.com` (single domain)
- **Benefit**: No re-whitelisting needed for new features/buckets

**Definition of Done**:
- Migration plan documented
- Stakeholders aligned
- Rollback tested

---

### User Story 2.15: Production Validation and Hypercare

**As a** Service Owner  
**I want to** monitor the solution closely post-production deployment  
**So that** we can quickly identify and resolve any issues

**Acceptance Criteria**:
- [ ] Hypercare period defined (e.g., 2 weeks post-deployment)
- [ ] Enhanced monitoring active
- [ ] Daily health checks performed
- [ ] Incident response team on standby
- [ ] Customer feedback monitored
- [ ] Performance metrics tracked
- [ ] Issue log maintained
- [ ] Daily standup meetings held
- [ ] Hypercare report created at end of period

**Hypercare Activities**:
- Daily health checks
- Real-time monitoring
- Customer feedback review
- Performance analysis
- Issue triage and resolution
- Stakeholder updates

**Success Metrics**:
- 99.9% uptime
- < 500ms average latency
- < 0.1% error rate
- Zero customer-impacting incidents
- Positive customer feedback

**Definition of Done**:
- Hypercare period completed
- No critical issues
- Service stable
- Hypercare report published

---

## Summary

### Epic 1: POC (9 User Stories)
1. Infrastructure Setup and Key Generation
2. Custom Domain Configuration
3. Lambda Function for Signed URL Generation
4. API Gateway Integration
5. File Metadata Management
6. End-to-End Testing
7. Documentation and Knowledge Transfer
8. GitHub Repository Publication
9. POC Validation and Sign-off

### Epic 2: DCP Deployment (15 User Stories)
1. DCP Environment Assessment
2. Terraform Backend Configuration for DCP
3. Environment-Specific Configuration
4. Infra-Test Deployment
5. DCP Dev Environment Deployment
6. DCP Test Environment Deployment
7. DCP Prod Environment Deployment
8. Feature Migration Strategy
9. Customer Whitelisting Communication
10. Monitoring and Alerting
11. Operational Runbooks
12. Security and Compliance Validation
13. Cost Optimization and FinOps
14. V1 to DCP Migration Support
15. Production Validation and Hypercare

### Total Story Points Estimate
- **Epic 1 (POC)**: ~55 story points
- **Epic 2 (DCP Deployment)**: ~89 story points
- **Total**: ~144 story points

### Timeline Estimate
- **Epic 1 (POC)**: 3-4 sprints (6-8 weeks)
- **Epic 2 (DCP Deployment)**: 5-6 sprints (10-12 weeks)
- **Total**: 8-10 sprints (16-20 weeks)

---

**Document Version**: 1.0  
**Last Updated**: October 16, 2025  
**Status**: Ready for Sprint Planning

