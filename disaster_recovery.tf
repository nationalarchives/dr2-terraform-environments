locals {
  disaster_recovery_name = "dr2-${local.environment}-disaster-recovery"
}
module "disaster_recovery_bucket" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//s3"
  bucket_name = local.disaster_recovery_bucket_name
  common_tags = {
    CreatedBy = local.creator
  }
  bucket_policy = templatefile("./templates/s3/lambda_access_bucket_policy.json.tpl", {
    lambda_role_arns = jsonencode([module.download_metadata_and_files_lambda.lambda_role_arn]),
    bucket_name      = local.disaster_recovery_bucket_name
  })
  kms_key_arn = module.dr2_kms_key.kms_key_arn
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
  name  = "dr2-${local.environment}-disaster-recovery-policy"
  policy = templatefile("${path.module}/templates/iam_policy/disaster_recovery_policy.json.tpl", {
    account_id                 = data.aws_caller_identity.current.account_id
    secrets_manager_secret_arn = aws_secretsmanager_secret.preservica_secret.arn
    entity_event_queue         = module.entity_event_generator_queue.sqs_arn
  })
}