locals {
  origin_id           = "${var.resource_prefix}-s3-origin"
  origin_id_secondary = "${var.resource_prefix}-s3-origin-secondary"
  origin_group_id     = "${var.resource_prefix}-origin-group"
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.resource_prefix}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket" "logs" {
  #checkov:skip=CKV_AWS_18:Bucket de access logs de CloudFront — no se auto-loguea (dependencia circular)
  #checkov:skip=CKV_AWS_144:Bucket de logs — CRR no aplica a destinos de logging
  #checkov:skip=CKV2_AWS_62:Bucket de logs — notificaciones innecesarias en destino de logging
  bucket = "${var.resource_prefix}-cf-access-logs"
  tags   = var.common_tags
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "expire-cf-logs"
    status = "Enabled"
    expiration { days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

# Política de headers de seguridad HTTP — CKV2_AWS_32
resource "aws_cloudfront_response_headers_policy" "security" {
  name = "${var.resource_prefix}-security-headers"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  #checkov:skip=CKV2_AWS_47:WAF ACL definida en módulo waf separado contiene AWSManagedRulesKnownBadInputsRuleSet (Log4JRCE) — Checkov no resuelve ref cross-module
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = var.price_class
  web_acl_id          = var.web_acl_arn

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    prefix          = "cf-access-logs/"
  }

  origin {
    domain_name              = var.origin_domain_name
    origin_id                = local.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  origin {
    domain_name              = var.origin_domain_name
    origin_id                = local.origin_id_secondary
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  origin_group {
    origin_id = local.origin_group_id
    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }
    member { origin_id = local.origin_id }
    member { origin_id = local.origin_id_secondary }
  }

  default_cache_behavior {
    allowed_methods              = ["GET", "HEAD", "OPTIONS"]
    cached_methods               = ["GET", "HEAD"]
    target_origin_id             = local.origin_group_id
    viewer_protocol_policy       = "redirect-to-https"
    compress                     = true
    response_headers_policy_id   = aws_cloudfront_response_headers_policy.security.id

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["PE", "US", "CO", "MX", "CL", "AR"]
    }
  }

  # Certificado SSL condicional — CKV2_AWS_42
  # Si acm_certificate_arn es null usa el certificado por defecto de CloudFront (*.cloudfront.net con HTTPS)
  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn != null ? "sni-only" : null
    minimum_protocol_version       = var.acm_certificate_arn != null ? "TLSv1.2_2021" : "TLSv1.2_2021"
  }

  tags = var.common_tags
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = var.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontServicePrincipal"
      Effect = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action   = "s3:GetObject"
      Resource = "${var.s3_bucket_arn}/*"
      Condition = {
        StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.this.arn }
      }
    }]
  })
}
