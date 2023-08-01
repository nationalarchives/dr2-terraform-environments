locals {
  entity_event_lambda_name = "${local.environment}-entity-event-generator-lambda"
  entity_event_topic_name  = "${local.environment}-entity-event-generator-topic"
  last_polled_table_name   = "${local.environment}-entity-event-lambda-updated-since-query-start-datetime"
  entity_event_topic_arn   = "arn:aws:sns:eu-west-2:${data.aws_caller_identity.current.account_id}:${local.entity_event_topic_name}"
}

module "entity_event_cloudwatch_event" {
  source                  = "git::https://github.com/nationalarchives/da-terraform-modules//cloudwatch_events"
  rule_name               = "${local.environment}-entity-event-schedule"
  schedule                = "rate(1 minute)"
  lambda_event_target_arn = "arn:aws:lambda:eu-west-2:${data.aws_caller_identity.current.account_id}:function:${local.entity_event_lambda_name}"
}

module "entity_event_generator_lambda" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name = local.entity_event_lambda_name
  handler       = "uk.gov.nationalarchives.Lambda::handleRequest"
  policies = {
    entity_event_policy = templatefile("${path.module}/templates/iam_policy/entity_event_lambda_policy.json.tpl", {
      account_id                 = data.aws_caller_identity.current.account_id
      lambda_name                = local.entity_event_lambda_name
      dynamo_db_arn              = module.entity_event_lambda_updated_since_query_start_datetime_table.table_arn
      secrets_manager_secret_arn = aws_secretsmanager_secret.preservica_secret.arn
      sns_arn                    = local.entity_event_topic_arn
    })
  }
  runtime     = "java17"
  memory_size = 512
  tags        = {}
  lambda_invoke_permissions = {
    "events.amazonaws.com" = module.entity_event_cloudwatch_event.event_arn
  }
  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.outbound_https_access_only.security_group_id]
  }
  plaintext_env_vars = {
    PRESERVICA_SECRET_NAME       = aws_secretsmanager_secret.preservica_secret.name
    ENTITY_EVENT_TOPIC_ARN       = local.entity_event_topic_arn
    LAST_EVENT_ACTION_TABLE_NAME = local.last_polled_table_name
    PRESERVICA_API_URL           = data.aws_ssm_parameter.preservica_url.value
  }
}

module "entity_event_lambda_updated_since_query_start_datetime_table" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//dynamo"
  hash_key      = "id"
  hash_key_type = "S"
  table_name    = local.last_polled_table_name
}

resource "aws_dynamodb_table_item" "initial_start_date_time" {
  hash_key   = "id"
  item       = templatefile("${path.module}/templates/dynamo/initial_last_updated_item.json.tpl", {})
  table_name = local.last_polled_table_name
  lifecycle {
    ignore_changes = [item]
  }
}

module "entity_event_generator_topic" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//sns"
  sns_policy = templatefile("${path.module}/templates/sns/entity_event_topic_policy.json.tpl", {
    lambda_role_arn = module.entity_event_generator_lambda.lambda_role_arn
    sns_topic       = local.entity_event_topic_arn
  })
  tags       = {}
  topic_name = local.entity_event_topic_name
}
