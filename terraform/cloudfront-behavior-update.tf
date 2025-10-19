# CloudFront Distribution with Separate Behaviors for Upload and Download
# This configuration allows:
# - /uploads/* - PUT operations without OAC (for uploads)
# - /* (default) - GET operations with OAC (for downloads)

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront Signed URLs Demo with separate upload/download behaviors"
  default_root_object = ""
  price_class         = "PriceClass_100"
  
  # Custom domain
  aliases = ["cdn-demo.pe-labs.com"]

  # Origin - S3 bucket
  origin {
    domain_name              = aws_s3_bucket.main.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.main.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  # BEHAVIOR 1: /uploads/* - For file uploads (PUT operations)
  # No OAC - allows CloudFront to forward PUT requests to S3
  ordered_cache_behavior {
    path_pattern     = "/uploads/*"
    target_origin_id = "S3-${aws_s3_bucket.main.id}"
    
    # Allow all HTTP methods including PUT
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    
    # Viewer protocol
    viewer_protocol_policy = "redirect-to-https"
    compress               = false
    
    # Disable caching for uploads (each upload is unique)
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
    
    # Forward all headers for PUT requests
    forwarded_values {
      query_string = true
      headers      = ["*"]
      
      cookies {
        forward = "none"
      }
    }
    
    # Require signed URLs
    trusted_key_groups = [aws_cloudfront_key_group.main.id]
  }

  # BEHAVIOR 2: /* (default) - For file downloads (GET operations)
  # With OAC - secure access to S3
  default_cache_behavior {
    target_origin_id = "S3-${aws_s3_bucket.main.id}"
    
    # Allow only read methods
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    
    # Viewer protocol
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    
    # Cache settings for downloads
    min_ttl     = 0
    default_ttl = 86400   # 1 day
    max_ttl     = 31536000 # 1 year
    
    forwarded_values {
      query_string = true
      
      cookies {
        forward = "none"
      }
    }
    
    # Require signed URLs
    trusted_key_groups = [aws_cloudfront_key_group.main.id]
  }

  # SSL certificate
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.main.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name        = "cloudfront-signedurl-demo"
    Environment = "demo"
  }
}

# Origin Access Control - Used only for default behavior (downloads)
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "S3-OAC-cloudfront-signedurl-demo"
  description                       = "Origin Access Control for S3 bucket (downloads only)"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 Bucket Policy - Updated to allow CloudFront for both GET and PUT
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Allow CloudFront OAC to read objects (for downloads)
      {
        Sid    = "AllowCloudFrontOACRead"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.main.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      },
      # Allow CloudFront to write objects to /uploads/* (for uploads)
      {
        Sid    = "AllowCloudFrontPutUploads"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.main.arn}/uploads/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}

