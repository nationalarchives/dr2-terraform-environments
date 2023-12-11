variable "log_destinations" {
  description = "A list of destinations to send the waf logs to"
  type        = list(string)
  default     = []
}

variable "arn_associations" {
  description = "List of AWS resource ARNs for WAF rule association"
}

variable "aws_managed_rules" {
  description = "List of AWS managed rules to be applied"
  type        = list(object({
    name = string
    priority = number
    managed_rule_group_statement_name = string
    managed_rule_group_statement_vendor_name = string
    metric_name = optional(string, "")
  }))
  default = [
    {
      name                                     = "AWS-AWSManagedRulesAmazonIpReputationList"
      priority                                 = 0
      managed_rule_group_statement_name        = "AAWS-AWSManagedRulesAmazonIpReputationList"
      managed_rule_group_statement_vendor_name = "AWS"
      metric_name                              = "AWS-AWSManagedRulesAmazonIpReputationList"
    },
    {
      name                                     = "AWS-AWSManagedRulesCommonRuleSet"
      priority                                 = 1
      managed_rule_group_statement_name        = "AWS-AWSManagedRulesCommonRuleSet"
      managed_rule_group_statement_vendor_name = "AWS"
      metric_name                              = "AWS-AWSManagedRulesCommonRuleSet"
    },
    {
      name                                     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      priority                                 = 2
      managed_rule_group_statement_name        = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      managed_rule_group_statement_vendor_name = "AWS"
      metric_name                              = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    },
  ]
}

variable "tags" {
  description = "tags used across the project"
}
