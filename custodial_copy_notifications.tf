locals {
  custodial_copy_topic_name = "${local.environment}-dr2-cc-notifications"
  custodial_copy_topic_arn  = "arn:aws:sns:eu-west-2:${data.aws_caller_identity.current.account_id}:${local.custodial_copy_topic_name}"
  custodial_copy_queue_name = "${local.environment}-dr2-cc-notifications"
  custodial_copy_lambda_name = "${local.environment}-dr2-cc-notifications"
}

module "dr2_custodial_copy_topic" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//sns"
  sns_policy = templatefile("./templates/sns/custodial_copy_topic_policy.json.tpl", {
    dr_user_arn = aws_iam_user.disaster_recovery_user.arn
    sns_topic   = local.custodial_copy_topic_arn
  })
  tags       = {}
  topic_name = local.custodial_copy_topic_name
}

module "dr2_custodial_copy_queue" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//sqs"
  queue_name = local.custodial_copy_queue_name
  sqs_policy = templatefile("./templates/sqs/sns_send_message_policy.json.tpl", {
    account_id = var.account_number,
    queue_name = local.custodial_copy_queue_name
    topic_arn  = local.custodial_copy_topic_arn
  })
  encryption_type = "sse"
}

resource "aws_sns_topic_subscription" "dr2_custodial_copy_queue_subscription" {
  topic_arn = local.custodial_copy_topic_arn
  protocol  = "sqs"
  endpoint  = module.dr2_custodial_copy_queue.sqs_arn
}

module "dr2_custodial_copy_lambda" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name = local.custodial_copy_lambda_name
  handler       = "uk.gov.nationalarchives.custodialcopy.Lambda::handleRequest"
  policies = {
    dr2_custodial_copy_policy = templatefile("${path.module}/templates/iam_policy/custodial_copy_lambda_policy.json.tpl", {
      account_id                 = data.aws_caller_identity.current.account_id
      lambda_name                = local.custodial_copy_lambda_name
      dynamo_db_file_table_arn   = module.files_table.table_arn
      custodial_copy_queue_arn = module.dr2_custodial_copy_queue.sqs_arn
    })
  }
  timeout_seconds = 180
  memory_size     = local.java_lambda_memory_size
  runtime         = local.java_runtime
  tags            = {}
  plaintext_env_vars = {
    DYNAMO_TABLE_NAME      = local.files_dynamo_table_name
  }
}