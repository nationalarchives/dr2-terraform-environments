locals {
  get_latest_preservica_version              = "${local.environment}-get-latest-preservica-version-lambda"
  latest_preservica_version_event_topic_name = "${local.environment}-latest-preservica-version-topic"
  dr2_preservica_version_table_name          = "${local.environment}-dr2-preservica-version"
  latest_preservica_version_event_topic_arn  = "arn:aws:sns:eu-west-2:${data.aws_caller_identity.current.account_id}:${local.latest_preservica_version_event_topic_name}"
}

module "get_latest_preservica_version_cloudwatch_event" {
  source                  = "git::https://github.com/nationalarchives/da-terraform-modules//cloudwatch_events"
  rule_name               = "${local.environment}-get-latest-preservica-version-event-schedule"
  schedule                = "cron(0 8 * * ? *)"
  lambda_event_target_arn = "arn:aws:lambda:eu-west-2:${data.aws_caller_identity.current.account_id}:function:${local.get_latest_preservica_version}"
}

module "get_latest_preservica_version_lambda" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name = local.get_latest_preservica_version
  handler       = "uk.gov.nationalarchives.Lambda::handleRequest"
  policies = {
    get_latest_preservica_version_event_policy = templatefile("${path.module}/templates/iam_policy/get_latest_preservica_version_lambda_policy.json.tpl", {
      account_id                 = data.aws_caller_identity.current.account_id
      lambda_name                = local.get_latest_preservica_version
      dynamo_db_arn              = module.get_latest_preservica_version_lambda_dr2_preservica_version_table.table_arn
      secrets_manager_secret_arn = aws_secretsmanager_secret.preservica_secret.arn
      sns_arn                    = local.latest_preservica_version_event_topic_arn
    })
  }
  timeout_seconds = 180
  memory_size     = local.java_lambda_memory_size
  runtime         = local.java_runtime
  tags            = {}
  lambda_invoke_permissions = {
    "events.amazonaws.com" = module.get_latest_preservica_version_cloudwatch_event.event_arn
  }
  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.outbound_https_access_only.security_group_id]
  }
  plaintext_env_vars = {
    PRESERVICA_SECRET_NAME                = aws_secretsmanager_secret.preservica_secret.name
    PRESERVICA_VERSION_EVENT_TOPIC_ARN    = local.latest_preservica_version_event_topic_arn
    CURRENT_PRESERVICA_VERSION_TABLE_NAME = local.dr2_preservica_version_table_name
    PRESERVICA_API_URL                    = data.aws_ssm_parameter.preservica_url.value
  }
}

module "get_latest_preservica_version_lambda_dr2_preservica_version_table" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//dynamo"
  hash_key   = { name = "id", type = "S" }
  table_name = local.dr2_preservica_version_table_name
}

resource "aws_dynamodb_table_item" "dr2_preservica_version" {
  hash_key   = "id"
  item       = templatefile("${path.module}/templates/dynamo/dr2_preservica_version.json.tpl", {})
  table_name = local.dr2_preservica_version_table_name
  lifecycle {
    ignore_changes = [item]
  }
}

module "latest_preservica_version_topic" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//sns"
  sns_policy = templatefile("${path.module}/templates/sns/latest_preservica_version_topic_policy.json.tpl", {
    lambda_role_arn = module.get_latest_preservica_version_lambda.lambda_role_arn
    sns_topic       = local.latest_preservica_version_event_topic_arn
  })
  tags       = {}
  topic_name = local.latest_preservica_version_event_topic_name
}
