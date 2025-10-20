import boto3
import OpenSSL
import time

# Initialize AWS clients
cloudfront = boto3.client('cloudfront')
secretsmanager = boto3.client('secretsmanager')
ssm = boto3.client('ssm')

PROJECT_NAME = "cloudfront-signed-urls-demo"

def rotate_keys():
    """Automates the zero-downtime key rotation for CloudFront signed URLs."""
    print("Starting CloudFront key rotation...")

    try:
        # 1. Get current inactive key details from SSM
        print("Step 1: Fetching current inactive key details from SSM...")
        inactive_key_id = ssm.get_parameter(Name='/cloudfront-signer/inactive-key-id')['Parameter']['Value']
        inactive_secret_arn = ssm.get_parameter(Name='/cloudfront-signer/inactive-secret-arn')['Parameter']['Value']
        inactive_key_group_id = cloudfront.list_key_groups()['KeyGroupList']['Items'][0]['KeyGroup']['Id'] # Simplified for demo

        print(f"  - Inactive Key ID: {inactive_key_id}")
        print(f"  - Inactive Secret ARN: {inactive_secret_arn}")

        # 2. Generate a new RSA key pair
        print("\nStep 2: Generating new RSA-2048 key pair...")
        key = OpenSSL.crypto.PKey()
        key.generate_key(OpenSSL.crypto.TYPE_RSA, 2048)

        private_key_pem = OpenSSL.crypto.dump_privatekey(OpenSSL.crypto.FILETYPE_PEM, key).decode('utf-8')
        public_key_pem = OpenSSL.crypto.dump_publickey(OpenSSL.crypto.FILETYPE_PEM, key).decode('utf-8')
        print("  - New key pair generated successfully.")

        # 3. Create a new CloudFront public key
        print("\nStep 3: Uploading new public key to CloudFront...")
        new_public_key_name = f"{PROJECT_NAME}-key-{int(time.time())}"
        cf_key_response = cloudfront.create_public_key(
            PublicKeyConfig={
                'CallerReference': str(int(time.time())),
                'Name': new_public_key_name,
                'EncodedKey': public_key_pem,
                'Comment': 'Rotated key'
            }
        )
        new_public_key_id = cf_key_response['PublicKey']['Id']
        new_public_key_etag = cf_key_response['ETag']
        print(f"  - New Public Key ID: {new_public_key_id}")

        # 4. Update the inactive key group with the new public key
        print("\nStep 4: Updating inactive key group...")
        key_group_config = cloudfront.get_key_group_config(Id=inactive_key_group_id)
        key_group_etag = key_group_config['ETag']
        cloudfront.update_key_group(
            KeyGroupConfig={
                'Name': f"{PROJECT_NAME}-inactive-key-group",
                'Items': [new_public_key_id],
                'Comment': 'Updated with new rotated key'
            },
            Id=inactive_key_group_id,
            IfMatch=key_group_etag
        )
        print(f"  - Key group {inactive_key_group_id} updated with new key {new_public_key_id}.")

        # 5. Update the inactive secret with the new private key
        print("\nStep 5: Storing new private key in Secrets Manager...")
        secretsmanager.put_secret_value(
            SecretId=inactive_secret_arn,
            SecretString=private_key_pem
        )
        print(f"  - Secret {inactive_secret_arn} updated with new private key.")

        # 6. Promote inactive to active by updating SSM parameters
        print("\nStep 6: Promoting new key to 'active' in SSM Parameter Store...")
        ssm.put_parameter(
            Name='/cloudfront-signer/active-key-id',
            Value=new_public_key_id,
            Type='String',
            Overwrite=True
        )
        ssm.put_parameter(
            Name='/cloudfront-signer/active-secret-arn',
            Value=inactive_secret_arn,
            Type='String',
            Overwrite=True
        )
        ssm.put_parameter(
            Name='/cloudfront-signer/last-rotation',
            Value=str(int(time.time())),
            Type='String',
            Overwrite=True
        )
        print("  - SSM parameters updated. New key is now active.")

        # 7. Demote old active to inactive
        print("\nStep 7: Demoting old active key to 'inactive'...")
        ssm.put_parameter(
            Name='/cloudfront-signer/inactive-key-id',
            Value=inactive_key_id, # The key we started with
            Type='String',
            Overwrite=True
        )
        # The secret ARN for inactive is now the one that was previously active.
        # This requires a bit more complex state management in a real scenario,
        # but for this script, we assume a simple swap.

        # 8. Clean up the old public key from CloudFront
        print("\nStep 8: Cleaning up old public key from CloudFront...")
        old_key_etag = cloudfront.get_public_key_config(Id=inactive_key_id)['ETag']
        cloudfront.delete_public_key(Id=inactive_key_id, IfMatch=old_key_etag)
        print(f"  - Old public key {inactive_key_id} deleted.")

        print("\n✅ Key rotation completed successfully!")
        print(f"  - New Active Key ID: {new_public_key_id}")

    except Exception as e:
        print(f"\n❌ An error occurred during key rotation: {e}")
        # Add rollback logic here if necessary

if __name__ == "__main__":
    rotate_keys()

