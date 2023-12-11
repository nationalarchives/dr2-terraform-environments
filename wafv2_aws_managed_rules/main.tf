resource "aws_wafv2_web_acl" "aws_managed_rules" {
  name  = "AWS-Managed-Rules"
  scope = "REGIONAL"
  default_action {
    block {}
  }

  dynamic "rule" {
    for_each = toset(var.aws_managed_rules)
    content {
      name     = rule.value.name
      priority = rule.value.priority
      override_action {
        none {}
      }
      statement {
        managed_rule_group_statement {
          name        = rule.value.managed_rule_group_statement_name
          vendor_name = rule.value.managed_rule_group_statement_vendor_name
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = false
        metric_name                = rule.value.metric_name
        sampled_requests_enabled   = false
      }
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "AWS-Managed-Rules"
    sampled_requests_enabled   = false
  }
  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "waf_association_aws_managed_rules" {
  count        = length(var.arn_associations)
  resource_arn = var.arn_associations[count.index]
  web_acl_arn  = aws_wafv2_web_acl.aws_managed_rules.arn
}

resource "aws_wafv2_web_acl_logging_configuration" "waf_logging_aws_managed_rules" {
  log_destination_configs = var.log_destinations
  resource_arn            = aws_wafv2_web_acl.aws_managed_rules.arn
}
