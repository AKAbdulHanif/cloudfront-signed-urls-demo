"""
Lambda function for generating CloudFront signed URLs
Supports both PUT (upload) and GET (download) operations
Updated with cleaner REST API routes
"""

import json
import os
import time
import boto3
from datetime import datetime, timedelta
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.backends import default_backend
import base64
import hashlib
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
UPLOAD_EXPIRATION = int(os.environ.get('UPLOAD_EXPIRATION', '900'))  # 15 minutes
DOWNLOAD_EXPIRATION = int(os.environ.get('DOWNLOAD_EXPIRATION', '3600'))  # 1 hour

# Cache for private key (loaded once per Lambda container)
_private_key_cache = None


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


def generate_cloudfront_signed_url(resource_url, expiration_seconds):
    """
    Generate CloudFront signed URL using RSA-SHA1 signature
    Works for both GET (download) and PUT (upload) operations
    """
    try:
        # Get private key
        private_key = get_private_key()
        
        # Calculate expiration time
        expire_timestamp = int(time.time()) + expiration_seconds
        
        # Create policy statement
        policy = {
            "Statement": [
                {
                    "Resource": resource_url,
                    "Condition": {
                        "DateLessThan": {
                            "AWS:EpochTime": expire_timestamp
                        }
                    }
                }
            ]
        }
        
        # Convert policy to JSON and encode
        policy_json = json.dumps(policy, separators=(',', ':'))
        policy_bytes = policy_json.encode('utf-8')
        
        # Sign the policy
        signature = private_key.sign(
            policy_bytes,
            padding.PKCS1v15(),
            hashes.SHA1()
        )
        
        # Base64 encode and make URL-safe
        def url_safe_base64(data):
            return base64.b64encode(data).decode('utf-8').replace('+', '-').replace('=', '_').replace('/', '~')
        
        encoded_policy = url_safe_base64(policy_bytes)
        encoded_signature = url_safe_base64(signature)
        
        # Build signed URL
        separator = '&' if '?' in resource_url else '?'
        signed_url = f"{resource_url}{separator}Policy={encoded_policy}&Signature={encoded_signature}&Key-Pair-Id={CLOUDFRONT_KEY_PAIR_ID}"
        
        return signed_url
    
    except Exception as e:
        print(f"Error generating signed URL: {str(e)}")
        raise


def handle_generate_upload_url(event, body_data):
    """
    Generate CloudFront signed URL for file upload (PUT)
    POST /api/files/upload
    """
    try:
        filename = body_data.get('filename')
        content_type = body_data.get('contentType', 'application/octet-stream')
        
        if not filename:
            return create_response(400, {
                'success': False,
                'error': 'Missing filename'
            })
        
        # Generate unique filename
        file_extension = filename.split('.')[-1] if '.' in filename else ''
        unique_id = str(uuid.uuid4())[:8]
        unique_filename = f"{unique_id}_{filename}"
        object_key = f"uploads/{unique_filename}"
        
        # Create CloudFront resource URL
        resource_url = f"https://{CLOUDFRONT_DOMAIN}/{object_key}"
        
        # Generate signed URL for PUT operation
        signed_url = generate_cloudfront_signed_url(resource_url, UPLOAD_EXPIRATION)
        
        # Store metadata in DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        timestamp = datetime.utcnow().isoformat()
        
        table.put_item(Item={
            'file_id': unique_filename,
            'original_filename': filename,
            'object_key': object_key,
            'content_type': content_type,
            'upload_url_generated_at': timestamp,
            'status': 'pending',
            'ttl': int(time.time()) + 86400  # 24 hours
        })
        
        return create_response(200, {
            'uploadUrl': signed_url,
            'fileId': unique_filename,
            'filename': unique_filename,
            'expiresIn': UPLOAD_EXPIRATION,
            'method': 'PUT',
            'headers': {
                'Content-Type': content_type
            }
        })
    
    except Exception as e:
        print(f"Error generating upload URL: {str(e)}")
        return create_response(500, {
            'error': 'Failed to generate upload URL',
            'message': str(e)
        })


def handle_generate_download_url(event, file_id):
    """
    Generate CloudFront signed URL for file download (GET)
    GET /api/files/download/{fileId}
    """
    try:
        if not file_id:
            return create_response(400, {
                'error': 'Missing file ID'
            })
        
        # Check if file exists in DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        
        try:
            response = table.get_item(Key={'file_id': file_id})
            if 'Item' not in response:
                return create_response(404, {
                    'error': 'File not found'
                })
            
            item = response['Item']
            object_key = item['object_key']
            original_filename = item.get('original_filename', file_id)
        except Exception as e:
            print(f"DynamoDB error: {str(e)}")
            # Fallback: assume file exists in uploads/
            object_key = f"uploads/{file_id}"
            original_filename = file_id
        
        # Create CloudFront resource URL
        resource_url = f"https://{CLOUDFRONT_DOMAIN}/{object_key}"
        
        # Generate signed URL for GET operation
        signed_url = generate_cloudfront_signed_url(resource_url, DOWNLOAD_EXPIRATION)
        
        return create_response(200, {
            'downloadUrl': signed_url,
            'filename': original_filename,
            'fileId': file_id,
            'expiresIn': DOWNLOAD_EXPIRATION
        })
    
    except Exception as e:
        print(f"Error generating download URL: {str(e)}")
        return create_response(500, {
            'error': 'Failed to generate download URL',
            'message': str(e)
        })


def handle_list_files(event):
    """
    List all files in DynamoDB
    GET /api/files
    """
    try:
        table = dynamodb.Table(TABLE_NAME)
        response = table.scan()
        
        files = []
        for item in response.get('Items', []):
            files.append({
                'fileId': item.get('file_id'),
                'filename': item.get('original_filename', item.get('file_id')),
                'contentType': item.get('content_type'),
                'uploadedAt': item.get('upload_url_generated_at'),
                'status': item.get('status', 'unknown')
            })
        
        return create_response(200, {
            'files': files,
            'count': len(files)
        })
    
    except Exception as e:
        print(f"Error listing files: {str(e)}")
        return create_response(500, {
            'error': 'Failed to list files',
            'message': str(e)
        })


def handle_delete_file(event, file_id):
    """
    Delete file from S3 and DynamoDB
    DELETE /api/files/{fileId}
    """
    try:
        if not file_id:
            return create_response(400, {
                'error': 'Missing file ID'
            })
        
        # Get file metadata
        table = dynamodb.Table(TABLE_NAME)
        response = table.get_item(Key={'file_id': file_id})
        
        if 'Item' not in response:
            return create_response(404, {
                'error': 'File not found'
            })
        
        object_key = response['Item']['object_key']
        
        # Delete from S3
        s3_client.delete_object(Bucket=BUCKET_NAME, Key=object_key)
        
        # Delete from DynamoDB
        table.delete_item(Key={'file_id': file_id})
        
        return create_response(200, {
            'message': 'File deleted successfully',
            'fileId': file_id
        })
    
    except Exception as e:
        print(f"Error deleting file: {str(e)}")
        return create_response(500, {
            'error': 'Failed to delete file',
            'message': str(e)
        })


def handle_config(event):
    """
    Return configuration information
    GET /api/config
    """
    config = {
        'cloudfront': {
            'domain': CLOUDFRONT_DOMAIN,
            'keyPairId': CLOUDFRONT_KEY_PAIR_ID
        },
        's3': {
            'bucket': BUCKET_NAME
        },
        'dynamodb': {
            'table': TABLE_NAME
        },
        'expiration': {
            'upload': UPLOAD_EXPIRATION,
            'download': DOWNLOAD_EXPIRATION
        }
    }
    
    return create_response(200, config)


def create_response(status_code, body):
    """
    Create API Gateway response with CORS headers
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


def lambda_handler(event, context):
    """
    Main Lambda handler for API Gateway REST API
    
    Routes:
    - POST   /api/files/upload           -> Generate upload URL
    - GET    /api/files                  -> List all files
    - GET    /api/files/download/{id}    -> Generate download URL
    - DELETE /api/files/{id}             -> Delete file
    - GET    /api/config                 -> Get configuration
    
    Legacy routes (for backward compatibility):
    - POST   /api/files/generate-upload-url
    - GET    /api/files/generate-download-url/{filename}
    - GET    /api/files/list
    - DELETE /api/files/delete/{filename}
    """
    try:
        # Parse request
        http_method = event.get('httpMethod', 'GET')
        path = event.get('path', '')
        body = event.get('body', '{}')
        path_parameters = event.get('pathParameters', {})
        
        print(f"Request: {http_method} {path}")
        
        # Parse body if present
        if body:
            try:
                body_data = json.loads(body) if isinstance(body, str) else body
            except:
                body_data = {}
        else:
            body_data = {}
        
        # Handle OPTIONS for CORS preflight
        if http_method == 'OPTIONS':
            return create_response(200, {'message': 'OK'})
        
        # Route to appropriate handler
        # New cleaner routes
        if path == '/api/files/upload' and http_method == 'POST':
            return handle_generate_upload_url(event, body_data)
        
        elif path == '/api/files' and http_method == 'GET':
            return handle_list_files(event)
        
        elif path.startswith('/api/files/download/') and http_method == 'GET':
            file_id = path.split('/')[-1]
            return handle_generate_download_url(event, file_id)
        
        elif path.startswith('/api/files/') and http_method == 'DELETE':
            # Extract file ID from path
            parts = path.split('/')
            if len(parts) >= 4:
                file_id = parts[3]
                return handle_delete_file(event, file_id)
        
        elif path == '/api/config' and http_method == 'GET':
            return handle_config(event)
        
        # Legacy routes for backward compatibility
        elif path == '/api/files/generate-upload-url' and http_method == 'POST':
            return handle_generate_upload_url(event, body_data)
        
        elif path.startswith('/api/files/generate-download-url/') and http_method == 'GET':
            file_id = path.split('/')[-1]
            return handle_generate_download_url(event, file_id)
        
        elif path == '/api/files/list' and http_method == 'GET':
            return handle_list_files(event)
        
        elif path.startswith('/api/files/delete/') and http_method == 'DELETE':
            file_id = path.split('/')[-1]
            return handle_delete_file(event, file_id)
        
        # Config endpoint
        elif path == '/api/files/config' and http_method == 'GET':
            return handle_config(event)
        
        else:
            return create_response(404, {
                'error': 'Not found',
                'path': path,
                'method': http_method,
                'message': 'The requested endpoint does not exist'
            })
    
    except Exception as e:
        print(f"Error in lambda_handler: {str(e)}")
        import traceback
        traceback.print_exc()
        return create_response(500, {
            'error': 'Internal server error',
            'message': str(e)
        })

