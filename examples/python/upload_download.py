#!/usr/bin/env python3
"""
Example: Upload and download files using CloudFront Signed URLs
"""

import requests
import json
import sys

# Configuration
API_URL = "https://r1ebp4qfic.execute-api.us-east-1.amazonaws.com/prod"


def upload_file(filename, content, content_type='text/plain'):
    """
    Upload a file using CloudFront signed URL
    
    Args:
        filename: Name of the file
        content: File content (bytes or string)
        content_type: MIME type
        
    Returns:
        file_id: Unique file identifier
    """
    print(f"Uploading {filename}...")
    
    # Step 1: Generate upload URL
    response = requests.post(
        f"{API_URL}/api/files/upload",
        json={
            'filename': filename,
            'contentType': content_type
        }
    )
    response.raise_for_status()
    data = response.json()
    
    upload_url = data['uploadUrl']
    file_id = data['fileId']
    
    print(f"  Upload URL generated")
    print(f"  File ID: {file_id}")
    
    # Step 2: Upload file
    if isinstance(content, str):
        content = content.encode('utf-8')
        
    response = requests.put(
        upload_url,
        data=content,
        headers={'Content-Type': content_type}
    )
    response.raise_for_status()
    
    print(f"  ✓ File uploaded successfully")
    
    return file_id


def download_file(file_id):
    """
    Download a file using CloudFront signed URL
    
    Args:
        file_id: Unique file identifier
        
    Returns:
        content: File content (bytes)
    """
    print(f"Downloading file {file_id}...")
    
    # Step 1: Generate download URL
    response = requests.get(f"{API_URL}/api/files/download/{file_id}")
    response.raise_for_status()
    data = response.json()
    
    download_url = data['downloadUrl']
    filename = data['filename']
    
    print(f"  Download URL generated")
    print(f"  Filename: {filename}")
    
    # Step 2: Download file
    response = requests.get(download_url)
    response.raise_for_status()
    
    print(f"  ✓ File downloaded successfully")
    
    return response.content


def list_files():
    """
    List all uploaded files
    
    Returns:
        files: List of file metadata
    """
    response = requests.get(f"{API_URL}/api/files")
    response.raise_for_status()
    data = response.json()
    
    return data['files']


def delete_file(file_id):
    """
    Delete a file
    
    Args:
        file_id: Unique file identifier
    """
    print(f"Deleting file {file_id}...")
    
    response = requests.delete(f"{API_URL}/api/files/{file_id}")
    response.raise_for_status()
    
    print(f"  ✓ File deleted successfully")


def main():
    """
    Main example flow
    """
    print("=" * 50)
    print("CloudFront Signed URLs - Python Example")
    print("=" * 50)
    print()
    
    try:
        # Upload a file
        content = "Hello from Python!\nThis is a test file."
        file_id = upload_file("example.txt", content, "text/plain")
        print()
        
        # List files
        print("Listing all files...")
        files = list_files()
        print(f"  Found {len(files)} file(s)")
        for f in files:
            print(f"    - {f['filename']} ({f['fileId']})")
        print()
        
        # Download the file
        downloaded_content = download_file(file_id)
        print(f"  Content: {downloaded_content.decode('utf-8')}")
        print()
        
        # Verify content matches
        if downloaded_content.decode('utf-8') == content:
            print("✓ Content verification: PASSED")
        else:
            print("✗ Content verification: FAILED")
        print()
        
        # Optional: Delete the file
        # delete_file(file_id)
        
        print("=" * 50)
        print("✓ All operations completed successfully!")
        print("=" * 50)
        
    except requests.exceptions.RequestException as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

