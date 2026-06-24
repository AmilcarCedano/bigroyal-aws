# CloudWatch log group para WAF (nombre obligatorio: aws-waf-logs-*) — CKV2_AWS_31
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.resource_prefix}"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
  tags              = var.common_tags
}

resource "aws_wafv2_web_acl" "this" {
  name  = "${var.resource_prefix}-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.resource_prefix}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.resource_prefix}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Regla IP Reputation — bloquea IPs maliciosas conocidas, incluye Log4JRCE — CKV2_AWS_47
  rule {
    name     = "AWSManagedRulesAMRIPReputation"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.resource_prefix}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.resource_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = var.common_tags
}

# Logging del WAF a CloudWatch Logs — CKV2_AWS_31
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.this.arn
}
