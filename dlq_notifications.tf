module "dlq_metadata_and_files_cloudwatch_alarm" {
  source              = "git::https://github.com/nationalarchives/da-terraform-modules//cloudwatch_alarms"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  name                = "${local.environment}-dlq-notifications"
  threshold           = "0"
  comparison_operator = "GreaterThanThreshold"
  statistic           = "Sum"
  datapoints_to_alarm = 1
  dimensions = {
    QueueName = "${local.download_metadata_and_files_queue_name}-dlq"
  }
  notification_topic = "arn:aws:sns:eu-west-2:${data.aws_caller_identity.current.account_id}:${local.environment}-dlq-notifications"
}

module "dlq_notifications_sns" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//sns"
  sns_policy = templatefile("${path.module}/templates/sns/cloudwatch_alarm_policy.json.tpl", {
    topic_name           = "${local.environment}-dlq-notifications"
    account_id           = data.aws_caller_identity.current.account_id
    cloudwatch_alarm_arn = module.dlq_metadata_and_files_cloudwatch_alarm.cloudwatch_alarm_arn
  })
  tags = {
    Name = "Preservica Config SNS"
  }
  topic_name  = "${local.environment}-dlq-notifications"
  kms_key_arn = module.dr2_kms_key.kms_key_arn
  sqs_subscriptions = {
    dlq_notifications_queue = module.dlq_notifications_queue.sqs_arn
  }
}

module "dlq_notifications_queue" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//sqs"
  queue_name = "${local.environment}-dlq-notifications"
  sqs_policy = templatefile("${path.module}/templates/sqs/sns_send_message_policy.json.tpl", {
    account_id = data.aws_caller_identity.current.account_id,
    queue_name = "${local.environment}-dlq-notifications",
    topic_arn  = module.dlq_notifications_sns.sns_arn
  })
  kms_key_id = module.dr2_kms_key.kms_key_arn
}
