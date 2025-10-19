"""
Lambda function for generating CloudFront signed URLs
Uses boto3's CloudFrontSigner - no external dependencies needed
"""

import json
import os
import time
import boto3
from datetime import datetime, timedelta
from botocore.signers import CloudFrontSigner
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding
import uuid

# Initialize AWS clients
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
secretsmanager = boto3.client('secretsmanager')

# Environment variables
BUCKET_NAME = os.environ['BUCKET_NAME']
TABLE_NAME = os.environ['TABLE_NAME']
CLOUDFRONT_DOMAIN = os.environ['CLOUDFRONT_DOMAIN']
CLOUDFRONT_KEY_PAIR_ID = os.environ['CLOUDFRONT_KEY_PAIR_ID']
PRIVATE_KEY_SECRET_ARN = os.environ['PRIVATE_KEY_SECRET_ARN']
UPLOAD_EXPIRATION = int(os.environ.get('UPLOAD_EXPIRATION', '900'))
DOWNLOAD_EXPIRATION = int(os.environ.get('DOWNLOAD_EXPIRATION', '3600'))

# Cache for private key and signer
_private_key_cache = None
_cloudfront_signer_cache = None


def rsa_signer(message):
    """
    RSA signer function for CloudFrontSigner
    """
    private_key = get_private_key()
    return private_key.sign(message, padding.PKCS1v15(), hashes.SHA1())


def get_private_key():
    """
    Retrieve CloudFront private key from Secrets Manager (with caching)
    """
    global _private_key_cache
    
    if _private_key_cache is not None:
        return _private_key_cache
    
    try:
        response = secretsmanager.get_secret_value(SecretId=PRIVATE_KEY_SECRET_ARN)
        private_key_pem = response['SecretString']
        
        # Load private key
        _private_key_cache = serialization.load_pem_private_key(
            private_key_pem.encode('utf-8'),
            password=None,
            backend=default_backend()
        )
        
        return _private_key_cache
    except Exception as e:
        print(f"Error loading private key: {str(e)}")
        raise


def get_cloudfront_signer():
    """
    Get CloudFront signer instance (with caching)
    """
    global _cloudfront_signer_cache
    
    if _cloudfront_signer_cache is not None:
        return _cloudfront_signer_cache
    
    # Create CloudFront signer
    _cloudfront_signer_cache = CloudFrontSigner(
        CLOUDFRONT_KEY_PAIR_ID,
        rsa_signer
    )
    
    return _cloudfront_signer_cache


def generate_signed_url(object_key, expiration_seconds, method='GET'):
    """
    Generate CloudFront signed URL using boto3's CloudFrontSigner
    """
    try:
        # Get signer
        signer = get_cloudfront_signer()
        
        # Build CloudFront URL
        url = f"https://{CLOUDFRONT_DOMAIN}/{object_key}"
        
        # Calculate expiration time
        expire_date = datetime.utcnow() + timedelta(seconds=expiration_seconds)
        
        # Generate signed URL
        signed_url = signer.generate_presigned_url(
            url,
            date_less_than=expire_date
        )
        
        return signed_url
    
    except Exception as e:
        print(f"Error generating signed URL: {str(e)}")
        raise


def create_response(status_code, body):
    """
    Create API Gateway response
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        },
        'body': json.dumps(body)
    }


def handle_upload(event, body_data):
    """
    Generate S3 presigned URL for file upload (PUT)
    Note: Uploads go directly to S3, not through CloudFront
    """
    try:
        # Get parameters
        filename = body_data.get('filename')
        content_type = body_data.get('contentType', 'application/octet-stream')
        
        if not filename:
            return create_response(400, {'success': False, 'error': 'filename is required'})
        
        # Generate unique file ID
        file_id = f"{uuid.uuid4().hex[:8]}_{filename}"
        object_key = f"uploads/{file_id}"
        
        # Generate S3 presigned URL for upload (not CloudFront signed URL)
        # Uploads must go directly to S3, CloudFront signed URLs don't support PUT
        signed_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': object_key,
                'ContentType': content_type
            },
            ExpiresIn=UPLOAD_EXPIRATION
        )
        
        # Store metadata in DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        table.put_item(
            Item={
                'file_id': file_id,
                'original_filename': filename,
                'content_type': content_type,
                'object_key': object_key,
                'upload_url_generated_at': datetime.utcnow().isoformat(),
                'status': 'pending',
                'ttl': int(time.time()) + (24 * 3600)  # 24 hours TTL
            }
        )
        
        return create_response(200, {
            'success': True,
            'uploadUrl': signed_url,
            'fileId': file_id,
            'expiresIn': UPLOAD_EXPIRATION
        })
    
    except Exception as e:
        print(f"Error in handle_upload: {str(e)}")
        return create_response(500, {'success': False, 'error': str(e)})


def handle_download(event, file_id):
    """
    Generate signed URL for file download (GET)
    """
    try:
        # Get file metadata from DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        response = table.get_item(Key={'file_id': file_id})
        
        if 'Item' not in response:
            return create_response(404, {'success': False, 'error': 'File not found'})
        
        item = response['Item']
        object_key = item['object_key']
        
        # Generate signed URL for download
        signed_url = generate_signed_url(object_key, DOWNLOAD_EXPIRATION, method='GET')
        
        return create_response(200, {
            'success': True,
            'downloadUrl': signed_url,
            'filename': item['original_filename'],
            'contentType': item.get('content_type', 'application/octet-stream'),
            'expiresIn': DOWNLOAD_EXPIRATION
        })
    
    except Exception as e:
        print(f"Error in handle_download: {str(e)}")
        return create_response(500, {'success': False, 'error': str(e)})


def handle_list_files(event):
    """
    List all files from DynamoDB
    """
    try:
        table = dynamodb.Table(TABLE_NAME)
        response = table.scan()
        
        files = []
        for item in response.get('Items', []):
            files.append({
                'fileId': item['file_id'],
                'filename': item['original_filename'],
                'contentType': item.get('content_type', 'application/octet-stream'),
                'uploadedAt': item.get('upload_url_generated_at'),
                'status': item.get('status', 'unknown')
            })
        
        return create_response(200, {
            'success': True,
            'files': files,
            'count': len(files)
        })
    
    except Exception as e:
        print(f"Error in handle_list_files: {str(e)}")
        return create_response(500, {'success': False, 'error': str(e)})


def handle_delete_file(event, file_id):
    """
    Delete file from S3 and DynamoDB
    """
    try:
        # Get file metadata
        table = dynamodb.Table(TABLE_NAME)
        response = table.get_item(Key={'file_id': file_id})
        
        if 'Item' not in response:
            return create_response(404, {'success': False, 'error': 'File not found'})
        
        item = response['Item']
        object_key = item['object_key']
        
        # Delete from S3
        try:
            s3_client.delete_object(Bucket=BUCKET_NAME, Key=object_key)
        except Exception as s3_error:
            print(f"S3 delete error (non-fatal): {str(s3_error)}")
        
        # Delete from DynamoDB
        table.delete_item(Key={'file_id': file_id})
        
        return create_response(200, {
            'success': True,
            'message': 'File deleted successfully'
        })
    
    except Exception as e:
        print(f"Error in handle_delete_file: {str(e)}")
        return create_response(500, {'success': False, 'error': str(e)})


def handle_config(event):
    """
    Return configuration information
    """
    config = {
        'success': True,
        'config': {
            'cloudfront_domain': CLOUDFRONT_DOMAIN,
            'upload_expiration': UPLOAD_EXPIRATION,
            'download_expiration': DOWNLOAD_EXPIRATION,
            'bucket': BUCKET_NAME
        }
    }
    return create_response(200, config)


def lambda_handler(event, context):
    """
    Main Lambda handler for API Gateway
    """
    try:
        # Parse request
        http_method = event.get('httpMethod', 'GET')
        path = event.get('path', '')
        body = event.get('body', '{}')
        
        print(f"Request: {http_method} {path}")
        
        # Parse body if present
        if body:
            try:
                body_data = json.loads(body) if isinstance(body, str) else body
            except:
                body_data = {}
        else:
            body_data = {}
        
        # Route to appropriate handler
        # New clean routes
        if path == '/api/files/upload' and http_method == 'POST':
            return handle_upload(event, body_data)
        elif path.startswith('/api/files/download/'):
            file_id = path.split('/')[-1]
            return handle_download(event, file_id)
        elif path == '/api/files' and http_method == 'GET':
            return handle_list_files(event)
        elif path.startswith('/api/files/') and http_method == 'DELETE':
            file_id = path.split('/')[-1]
            return handle_delete_file(event, file_id)
        elif path == '/api/files/config':
            return handle_config(event)
        # Old routes (backward compatibility)
        elif path == '/api/files/generate-upload-url':
            return handle_upload(event, body_data)
        elif path.startswith('/api/files/generate-download-url/'):
            file_id = path.split('/')[-1]
            return handle_download(event, file_id)
        elif path == '/api/files/list':
            return handle_list_files(event)
        elif path.startswith('/api/files/delete/'):
            file_id = path.split('/')[-1]
            return handle_delete_file(event, file_id)
        else:
            return create_response(404, {'error': 'Not found', 'path': path})
    
    except Exception as e:
        print(f"Error in lambda_handler: {str(e)}")
        import traceback
        traceback.print_exc()
        return create_response(500, {'error': 'Internal server error', 'message': str(e)})

