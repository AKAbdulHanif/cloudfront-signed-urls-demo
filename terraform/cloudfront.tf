# CloudFront Distribution with Signed URLs Support

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${var.project_name}-oac"
  description                       = "Origin Access Control for ${var.project_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Public Key
resource "aws_cloudfront_public_key" "main" {
  name        = "${var.project_name}-public-key"
  encoded_key = local.cloudfront_public_key_pem
  comment     = "Public key for CloudFront signed URLs"
}

# CloudFront Key Group
resource "aws_cloudfront_key_group" "main" {
  name    = "${var.project_name}-key-group"
  comment = "Key group for CloudFront signed URLs"
  items   = [aws_cloudfront_public_key.main.id]
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} distribution"
  default_root_object = ""
  price_class         = var.cloudfront_price_class
  
  # Custom domain (if enabled)
  aliases = var.custom_domain_enabled && var.domain_name != "" ? [local.full_domain_name] : []
  
  # S3 Origin
  origin {
    domain_name              = aws_s3_bucket.main.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.main.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }
  
  # Default cache behavior
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.main.id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    
    # Trusted key groups for signed URLs
    trusted_key_groups = [aws_cloudfront_key_group.main.id]
    
    # Cache settings (disabled for signed URLs)
    min_ttl     = var.cloudfront_min_ttl
    default_ttl = var.cloudfront_default_ttl
    max_ttl     = var.cloudfront_max_ttl
    
    forwarded_values {
      query_string = true
      headers      = ["Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"]
      
      cookies {
        forward = "none"
      }
    }
  }
  
  # Geo restriction
  restrictions {
    geo_restriction {
      restriction_type = var.cloudfront_geo_restriction_type
      locations        = var.cloudfront_geo_restriction_locations
    }
  }
  
  # SSL/TLS certificate
  viewer_certificate {
    cloudfront_default_certificate = var.custom_domain_enabled && var.domain_name != "" ? false : true
    acm_certificate_arn            = var.custom_domain_enabled && var.domain_name != "" ? aws_acm_certificate.main[0].arn : null
    ssl_support_method             = var.custom_domain_enabled && var.domain_name != "" ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-distribution"
    }
  )
  
  depends_on = [
    aws_acm_certificate_validation.main
  ]
}

