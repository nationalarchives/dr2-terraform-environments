locals {
  disaster_recovery_name = "${local.environment}-dr2-disaster-recovery"
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
  })
}
