locals {
  notifications_topic_name = "${local.environment}-dr2-notifications"
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
  topic_name = local.notifications_topic_name
  sqs_subscriptions = {
    log_external_notifications_queue = module.dr2_external_notifications_queue.sqs_arn
  }
}
