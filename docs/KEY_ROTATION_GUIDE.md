# CloudFront Signed URLs - Key Rotation Guide

**Author:** Platform Engineering Team  
**Last Updated:** October 19, 2025

---

## 1. Overview

This guide provides instructions for rotating the CloudFront signing keys used by the CloudFront Signed URLs solution. Regular key rotation is a critical security practice that limits the impact of a compromised key. The process is designed to be zero-downtime, ensuring that service is not interrupted for end-users.

This guide covers both automated and manual rotation procedures.

**Rotation Frequency:** It is recommended to rotate keys every **90 days**.

## 2. Architecture Overview

The key rotation strategy relies on an active/inactive key model:

- **Two Key Pairs:** An `active` key pair for signing new URLs and an `inactive` key pair staged for the next rotation.
- **Two Key Groups:** The CloudFront distribution is configured to trust both the `active-key-group` and `inactive-key-group`, allowing old URLs to remain valid during rotation.
- **SSM Parameter Store:** Manages the state of which key is currently active.
- **Java Lambda:** Reads the active key configuration from SSM to sign new URL requests.

For a detailed architectural breakdown, see `docs/KEY_ROTATION_STRATEGY.md`.

## 3. Automated Key Rotation

The recommended method for key rotation is to use the provided automation script. This script can be executed manually or scheduled to run periodically (e.g., via a cron job or a scheduled Lambda function).

### 3.1. Prerequisites

- **Python 3.8+** and `boto3` installed.
- **AWS Credentials:** Your environment must be configured with AWS credentials that have the necessary IAM permissions to manage CloudFront keys, Secrets Manager secrets, and SSM parameters.

### 3.2. Running the Script

```bash
# Navigate to the scripts directory
cd /home/ubuntu/cloudfront-signed-urls-demo/scripts

# Install dependencies (if not already installed)
pip install boto3 pyopenssl

# Execute the rotation script
python rotate-keys.py
```

### 3.3. What the Script Does

The `rotate-keys.py` script performs the following steps:

1.  **Fetches** the current `inactive` key details from SSM.
2.  **Generates** a new RSA-2048 key pair.
3.  **Uploads** the new public key to CloudFront.
4.  **Updates** the `inactive-key-group` to use the new public key.
5.  **Stores** the new private key in the `inactive-private-key` secret in Secrets Manager.
6.  **Promotes** the new key to `active` by updating the SSM parameters (`/cloudfront-signer/active-key-id` and `/cloudfront-signer/active-secret-arn`).
7.  **Demotes** the old active key to `inactive`.
8.  **Deletes** the old, unused public key from CloudFront.

### 3.4. Scheduling the Automation

For a fully automated solution, you can create a new Lambda function that runs the rotation logic on a schedule (e.g., every 90 days using an EventBridge rule).

## 4. Manual Key Rotation

If manual rotation is required, follow these steps carefully. **Warning:** Performing these steps incorrectly can lead to service disruption.

### Step 1: Generate a New Key Pair

```bash
# Generate a new private key
openssl genrsa -out new_private_key.pem 2048

# Extract the public key
openssl rsa -in new_private_key.pem -pubout -out new_public_key.pem
```

### Step 2: Upload New Public Key to CloudFront

1.  Go to the **CloudFront Console** -> **Public keys**.
2.  Click **Create public key**.
3.  Give it a name (e.g., `my-app-key-2025-10-19`).
4.  Copy the contents of `new_public_key.pem` into the `Key` field.
5.  Click **Create public key** and note the **ID** of the new key.

### Step 3: Update Inactive Key Group

1.  Go to **CloudFront Console** -> **Key groups**.
2.  Select the `inactive-key-group`.
3.  Click **Edit**.
4.  Remove the existing public key from the group.
5.  Add the new public key you just created.
6.  Click **Save changes**.

### Step 4: Update Inactive Private Key in Secrets Manager

1.  Go to **Secrets Manager Console**.
2.  Select the `inactive-private-key` secret.
3.  Click **Retrieve secret value**, then **Edit**.
4.  Paste the contents of `new_private_key.pem` into the secret value field.
5.  Click **Save**.

### Step 5: Promote New Key to Active

1.  Go to **SSM Parameter Store Console**.
2.  Update the value of `/cloudfront-signer/active-key-id` to the new public key ID from Step 2.
3.  Update the value of `/cloudfront-signer/active-secret-arn` to the ARN of the `inactive-private-key` secret.
4.  Update the value of `/cloudfront-signer/last-rotation` to the current timestamp.

### Step 6: Clean Up Old Key

After waiting a sufficient period (e.g., 24 hours) to ensure all old signed URLs have expired, you can delete the old public key from CloudFront.

1.  Go to the **CloudFront Console** -> **Public keys**.
2.  Select the old public key.
3.  Click **Delete**.

## 5. Monitoring and Verification

### 5.1. Verify Lambda Function

After a rotation, check the CloudWatch Logs for the signing Lambda. You should see it successfully initializing with the new active key ID.

### 5.2. Check SSM Parameters

Verify that the SSM parameters have been updated correctly:

- `/cloudfront-signer/active-key-id` should point to the new public key.
- `/cloudfront-signer/last-rotation` should have a recent timestamp.

### 5.3. Test URL Signing

Invoke the API to generate a new signed URL. The URL should contain the new `Key-Pair-Id` in its query string. Verify that you can access the resource using this new URL.

## 6. Rollback Procedure

If a rotation fails and causes an outage, you can perform a rollback by reversing the SSM parameter update.

**Immediate Action:**

1.  Go to **SSM Parameter Store Console**.
2.  Revert the values of `/cloudfront-signer/active-key-id` and `/cloudfront-signer/active-secret-arn` to their **previous** values.

This will immediately instruct the Lambda function to start using the previous (known good) key pair for signing new URLs. Since the CloudFront distribution still trusts the old key group, service will be restored for all new requests.

Once the service is stable, you can investigate the root cause of the rotation failure.

---

