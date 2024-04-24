locals {
  notifications_topic_name = "${local.environment}-dr2-notifications"
}

module "dr2_notifications_kms_key" {
  source   = "git::https://github.com/nationalarchives/da-terraform-modules//kms"
  key_name = "${local.environment}-dr2-notifications"
  default_policy_variables = {
    user_roles = concat(local.additional_user_roles)
    ci_roles   = [local.terraform_role_arn]
    service_details = [
      { service_name = "sns" },
    ]
  }
}

module "dr2_notifications_sns" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//sns"
  sns_policy = templatefile("${path.module}/templates/sns/default_sns_policy.json.tpl", {
    topic_name = local.notifications_topic_name
    account_id = data.aws_caller_identity.current.account_id
  })
  tags = {
    Name = local.notifications_topic_name
  }
  topic_name  = local.notifications_topic_name
  kms_key_arn = module.dr2_notifications_kms_key.kms_key_arn
}

