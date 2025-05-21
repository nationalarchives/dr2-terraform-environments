locals {
  post_ingest_table_name              = "${var.environment}-dr2-postingest-state"
  post_ingest_gsi_name                = "QueueLastQueuedIdx"
  custodial_copy_confirmer_queue_name = "${var.environment}-dr2-custodial-copy-confirmer"
  state_change_lambda_name            = "${var.environment}-dr2-postingest-state-change-handler"
  resender_lambda_name                = "${var.environment}-dr2-postingest-message-resender"
}

data "aws_caller_identity" "current" {}

module "post_ingest_table" {
  source                         = "git::https://github.com/nationalarchives/da-terraform-modules//dynamo"
  hash_key                       = { name = "ioRef", type = "S" }
  range_key                      = { name = "batchId", type = "S" }
  table_name                     = local.post_ingest_table_name
  server_side_encryption_enabled = false
  ttl_attribute_name             = "ttl"
  stream_enabled                 = true
  stream_view_type               = "NEW_AND_OLD_IMAGES"
  deletion_protection_enabled    = true
  additional_attributes = [
    { name = "queue", type = "S" },
    { name = "lastQueued", type = "S" }
  ]
  global_secondary_indexes = [
    {
      name            = local.post_ingest_gsi_name
      hash_key        = "queue"
      range_key       = "lastQueued"
      projection_type = "ALL"
    }
  ]
  point_in_time_recovery_enabled = true
}

module "dr2_custodial_copy_confirmer_queue" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//sqs?ref=make-dlq-creation-optional"
  queue_name = local.custodial_copy_confirmer_queue_name
  sqs_policy = templatefile("./templates/sqs/sqs_access_policy.json.tpl", {
    account_id = data.aws_caller_identity.current.account_id,
    queue_name = local.custodial_copy_confirmer_queue_name
  })
  create_dlq                                        = false
  queue_cloudwatch_alarm_visible_messages_threshold = 50
  visibility_timeout                                = 3600
  encryption_type                                   = "sse"
}


module "dr2_stage_change_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.state_change_lambda_name
  handler         = "uk.gov.nationalarchives.postingeststatechangehandler.Lambda::handleRequest"
  timeout_seconds = 900

  policies = {
    "${local.state_change_lambda_name}-policy" = templatefile("${path.module}/templates/policies/state_change_lambda_policy.json.tpl", {
      custodial_copy_checker_queue_arn = module.dr2_custodial_copy_confirmer_queue.sqs_arn
      dynamo_db_post_ingest_arn        = module.post_ingest_table.table_arn
      sns_external_notifications_arn   = var.notifications_topic_arn
      account_id                       = data.aws_caller_identity.current.account_id
      lambda_name                      = local.state_change_lambda_name
      dynamo_db_post_ingest_stream_arn = module.post_ingest_table.stream_arn
    })
  }
  memory_size = 1024
  runtime     = "java21"
  dynamo_stream_config = {
    stream_arn = module.post_ingest_table.stream_arn
  }
  tags = {
    Name = local.state_change_lambda_name
  }
}

module "dr2_resender_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.resender_lambda_name
  handler         = "uk.gov.nationalarchives.postingestresender.Lambda::handleRequest"
  timeout_seconds = 900

  policies = {
    "${local.resender_lambda_name}-policy" = templatefile("${path.module}/templates/policies/resender_lambda_policy.json.tpl", {
      custodial_copy_checker_queue_arn = module.dr2_custodial_copy_confirmer_queue.sqs_arn
      dynamo_db_post_ingest_arn        = module.post_ingest_table.table_arn
      account_id                       = data.aws_caller_identity.current.account_id
      lambda_name                      = local.resender_lambda_name
    })
  }
  memory_size = 1024
  runtime     = "java21"
  tags = {
    Name = local.resender_lambda_name
  }
}

module "dr2_entity_event_cloudwatch_event" {
  source                  = "git::https://github.com/nationalarchives/da-terraform-modules//cloudwatch_events"
  rule_name               = "${var.environment}-dr2-post-ingest-resender-schedule"
  schedule                = "rate(1 hour)"
  lambda_event_target_arn = "arn:aws:lambda:eu-west-2:${data.aws_caller_identity.current.account_id}:function:${local.resender_lambda_name}"
}