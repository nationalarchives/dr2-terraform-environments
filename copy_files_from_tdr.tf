locals {
  copy_files_from_tdr_name         = "${local.environment}-dr2-copy-files-from-tdr"
  copy_files_from_tdr_queue_arn    = "arn:aws:sqs:eu-west-2:${data.aws_caller_identity.current.account_id}:${local.copy_files_from_tdr_name}"
  tdr_external_notifications_topic = "arn:aws:sns:eu-west-2:${module.tdr_config.account_numbers[local.environment]}:tdr-external-notifications-${local.environment}"
}
module "dr2_copy_files_from_tdr_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.copy_files_from_tdr_name
  handler         = "lambda_function.lambda_handler"
  timeout_seconds = local.python_timeout_seconds
  lambda_sqs_queue_mappings = [
    { sqs_queue_arn = local.copy_files_from_tdr_queue_arn }
  ]
  policies = {
    "${local.copy_files_from_tdr_name}-policy" = templatefile("./templates/iam_policy/copy_files_from_tdr_policy.json.tpl", {
      copy_files_from_tdr_queue_arn = local.copy_files_from_tdr_queue_arn
      raw_cache_bucket_name         = local.ingest_raw_cache_bucket_name
      tdr_bucket_name               = "tdr-export-${local.environment}"
      aggregator_queue_arn          = local.tdr_aggregator_queue_arn
      account_id                    = data.aws_caller_identity.current.account_id
      lambda_name                   = local.copy_files_from_tdr_name
    })
  }
  memory_size = local.python_lambda_memory_size
  runtime     = local.python_runtime
  plaintext_env_vars = {
    DESTINATION_BUCKET = local.ingest_raw_cache_bucket_name
    DESTINATION_QUEUE  = local.tdr_aggregator_queue_url
  }
  tags = {
    Name = local.copy_files_from_tdr_name
  }
}


module "dr2_copy_files_from_tdr_sqs" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//sqs"
  queue_name = local.copy_files_from_tdr_name
  sqs_policy = templatefile("./templates/sqs/sns_send_message_policy.json.tpl", {
    account_id = var.account_number,
    queue_name = local.copy_files_from_tdr_name
    topic_arn  = "arn:aws:sns:eu-west-2:${module.tdr_config.account_numbers[local.environment]}:tdr-external-notifications-${local.environment}"
  })
  redrive_maximum_receives = 5
  visibility_timeout       = 180
  encryption_type          = local.sse_encryption
}

resource "aws_sns_topic_subscription" "dr2_copy_files_from_tdr_subscription" {
  endpoint             = module.dr2_copy_files_from_tdr_sqs.sqs_arn
  protocol             = "sqs"
  topic_arn            = local.tdr_external_notifications_topic
  raw_message_delivery = true
  filter_policy_scope  = "MessageBody"
  filter_policy        = templatefile("${path.module}/templates/sns/tdr_filter_policy.json.tpl", { environment = local.environment })
}
