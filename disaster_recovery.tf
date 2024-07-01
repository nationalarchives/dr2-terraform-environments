locals {
  disaster_recovery_name       = "${local.environment}-dr2-disaster-recovery"
  disaster_recovery_topic_name = "${local.environment}-dr2-cc-notifications"
  disaster_recovery_topic_arn  = "arn:aws:sns:eu-west-2:${data.aws_caller_identity.current.account_id}:${local.disaster_recovery_topic_name}"
  disaster_recovery_queue_name = "${local.environment}-dr2-cc-queue"
}

resource "aws_iam_user" "disaster_recovery_user" {
  name = local.disaster_recovery_name
}

resource "aws_iam_access_key" "disaster_recovery_user_access_key" {
  user = local.disaster_recovery_name
}

resource "aws_iam_user_group_membership" "disaster_recovery_group_membership" {
  groups = [aws_iam_group.disaster_recovery_group.name]
  user   = aws_iam_user.disaster_recovery_user.name
}

resource "aws_iam_group" "disaster_recovery_group" {
  name = local.disaster_recovery_name
}

resource "aws_iam_group_policy" "disaster_recovery_group_policy" {
  group = aws_iam_group.disaster_recovery_group.name
  name  = "${local.environment}-dr2-disaster-recovery-policy"
  policy = templatefile("${path.module}/templates/iam_policy/disaster_recovery_policy.json.tpl", {
    account_id                 = data.aws_caller_identity.current.account_id
    secrets_manager_secret_arn = aws_secretsmanager_secret.preservica_secret.arn
    entity_event_queue         = module.dr2_entity_event_generator_queue.sqs_arn
    management_account_id      = module.config.account_numbers["mgmt"]
  })
}

module "dr2_disaster_recovery_topic" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//sns"
  sns_policy = templatefile("${path.module}/templates/sns/disaster_recovery_topic_policy.json.tpl", {
    dr_user_arn = aws_iam_user.disaster_recovery_user.arn
    sns_topic   = local.disaster_recovery_topic_arn
  })
  tags       = {}
  topic_name = local.disaster_recovery_topic_name
}

module "dr2_disaster_recovery_queue" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//sqs"
  queue_name = local.disaster_recovery_queue_name
  sqs_policy = templatefile("./templates/sqs/sns_send_message_policy.json.tpl", {
    account_id = var.account_number,
    queue_name = local.disaster_recovery_queue_name
    topic_arn  = local.disaster_recovery_topic_arn
  })
  encryption_type = "sse"
}

resource "aws_sns_topic_subscription" "dr2_disaster_recovery_queue_subscription" {
  topic_arn = local.disaster_recovery_topic_arn
  protocol  = "sqs"
  endpoint  = module.dr2_disaster_recovery_queue.sqs_arn
}