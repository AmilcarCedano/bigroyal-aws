data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_route53_zone" "this" {
  name = var.domain_name
  tags = var.common_tags
}

resource "aws_route53_record" "cloudfront" {
  zone_id = aws_route53_zone.this.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.cloudfront_domain_name]
}

# IAM + CloudWatch para DNS query logging — CKV2_AWS_39
resource "aws_iam_role" "dns_query_logs" {
  name = "${var.resource_prefix}-dns-query-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "route53.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "dns_query_logs" {
  provider          = aws.us_east_1
  name              = "/aws/route53/${var.resource_prefix}"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
  tags              = var.common_tags
}

resource "aws_cloudwatch_log_resource_policy" "dns_query_logs" {
  provider        = aws.us_east_1
  policy_name     = "${var.resource_prefix}-route53-query-logs"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "route53.amazonaws.com" }
      Action    = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource  = "${aws_cloudwatch_log_group.dns_query_logs.arn}:*"
      Condition = {
        ArnLike = { "aws:SourceArn" = "arn:aws:route53:::*" }
      }
    }]
  })
}

resource "aws_route53_query_log" "this" {
  zone_id                  = aws_route53_zone.this.zone_id
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.dns_query_logs.arn

  depends_on = [aws_cloudwatch_log_resource_policy.dns_query_logs]
}

# Clave KMS asimétrica para DNSSEC — CKV2_AWS_38
resource "aws_kms_key" "dnssec" {
  provider                 = aws.us_east_1
  description              = "Clave KMS para DNSSEC de ${var.domain_name}"
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"
  deletion_window_in_days  = 7
  enable_key_rotation      = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRoot"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowRoute53DNSSEC"
        Effect = "Allow"
        Principal = { Service = "dnssec-route53.amazonaws.com" }
        Action   = ["kms:DescribeKey", "kms:GetPublicKey", "kms:Sign"]
        Resource = "*"
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_route53_key_signing_key" "this" {
  hosted_zone_id             = aws_route53_zone.this.zone_id
  key_management_service_arn = aws_kms_key.dnssec.arn
  name                       = "${var.resource_prefix}-ksk"
}

resource "aws_route53_hosted_zone_dnssec" "this" {
  hosted_zone_id = aws_route53_key_signing_key.this.hosted_zone_id

  depends_on = [aws_route53_key_signing_key.this]
}
