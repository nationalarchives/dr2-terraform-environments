locals {
  custodial_copy_topic_name         = "${local.environment}-dr2-cc-notifications"
  custodial_copy_topic_arn          = "arn:aws:sns:eu-west-2:${data.aws_caller_identity.current.account_id}:${local.custodial_copy_topic_name}"
  custodial_copy_ingest_queue_name  = "${local.environment}-dr2-ingest-cc-notifications"
  custodial_copy_ingest_lambda_name = "${local.environment}-dr2-ingest-cc-notifications"
}

module "dr2_custodial_copy_topic" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//sns"
  sns_policy = templatefile("./templates/sns/custodial_copy_topic_policy.json.tpl", {
    cc_user_arn = aws_iam_user.custodial_copy_user.arn
    sns_topic   = local.custodial_copy_topic_arn
  })
  tags       = {}
  topic_name = local.custodial_copy_topic_name
  sqs_subscriptions = {
    custodial_copy_queue   = module.dr2_custodial_copy_notifications_queue.sqs_arn
    database_builder_queue = module.dr2_custodial_copy_db_builder_queue.sqs_arn
  }
}

module "dr2_custodial_copy_notifications_queue" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//sqs"
  queue_name = local.custodial_copy_ingest_queue_name
  sqs_policy = templatefile("./templates/sqs/sns_send_message_policy.json.tpl", {
    account_id = var.account_number,
    queue_name = local.custodial_copy_ingest_queue_name
    topic_arn  = local.custodial_copy_topic_arn
  })
  encryption_type = local.sse_encryption
}

module "dr2_custodial_copy_ingest_lambda" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name = local.custodial_copy_ingest_lambda_name
  handler       = "lambda_function.lambda_handler"
  policies = {
    dr2_custodial_copy_policy = templatefile("${path.module}/templates/iam_policy/custodial_copy_lambda_policy.json.tpl", {
      account_id               = data.aws_caller_identity.current.account_id
      lambda_name              = local.custodial_copy_ingest_lambda_name
      dynamo_db_file_table_arn = module.files_table.table_arn
      custodial_copy_queue_arn = module.dr2_custodial_copy_notifications_queue.sqs_arn
    })
  }
  lambda_sqs_queue_mappings = [{
    sqs_queue_arn = module.dr2_custodial_copy_notifications_queue.sqs_arn
  }]
  timeout_seconds = local.python_timeout_seconds
  memory_size     = local.python_lambda_memory_size
  runtime         = local.python_runtime
  tags            = {}
  plaintext_env_vars = {
    FILES_DDB_TABLE   = local.files_dynamo_table_name
    DYNAMO_TABLE_NAME = local.files_dynamo_table_name # Remove in DR2-1626/2
  }
}
