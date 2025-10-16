# DNS and SSL/TLS Configuration for Custom Domain

# ACM Certificate (must be in us-east-1 for CloudFront)
resource "aws_acm_certificate" "main" {
  count = var.custom_domain_enabled && var.domain_name != "" ? 1 : 0
  
  provider          = aws.us_east_1
  domain_name       = local.full_domain_name
  validation_method = "DNS"
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-certificate"
    }
  )
}

# Route53 Record for ACM Certificate Validation
resource "aws_route53_record" "cert_validation" {
  for_each = var.custom_domain_enabled && var.domain_name != "" ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}
  
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main[0].zone_id
}

# ACM Certificate Validation
resource "aws_acm_certificate_validation" "main" {
  count = var.custom_domain_enabled && var.domain_name != "" ? 1 : 0
  
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Route53 Record for CloudFront Distribution
resource "aws_route53_record" "cloudfront" {
  count = var.custom_domain_enabled && var.domain_name != "" ? 1 : 0
  
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = local.full_domain_name
  type    = "A"
  
  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 Record for CloudFront Distribution (IPv6)
resource "aws_route53_record" "cloudfront_ipv6" {
  count = var.custom_domain_enabled && var.domain_name != "" ? 1 : 0
  
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = local.full_domain_name
  type    = "AAAA"
  
  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

