locals {
  az_count                                = local.environment == "prod" ? 2 : 1
  ingest_raw_cache_bucket_name            = "${local.environment}-dr2-ingest-raw-cache"
  ingest_staging_cache_bucket_name        = "${local.environment}-dr2-ingest-staging-cache"
  pre_ingest_step_function_name           = "${local.environment_title}-ingest-step-function"
  additional_user_roles                   = local.environment == "intg" ? [data.aws_ssm_parameter.dev_admin_role.value] : []
  files_dynamo_table_name                 = "${local.environment}-dr2-files"
  files_table_global_secondary_index_name = "BatchParentPathIdx"
}
resource "random_password" "preservica_password" {
  length = 20
}

resource "random_string" "preservica_user" {
  length  = 10
  special = false
}

resource "aws_secretsmanager_secret" "preservica_secret" {
  name = "${local.environment}-preservica-api-login-details-${random_string.preservica_user.result}"
}

data "aws_ssm_parameter" "slack_webhook_url" {
  name = "/${local.environment}/slack/cloudwatch-alarm-webhook"
}

resource "aws_secretsmanager_secret_version" "preservica_secret_version" {
  secret_id     = aws_secretsmanager_secret.preservica_secret.id
  secret_string = jsonencode({ (random_string.preservica_user.result) = random_password.preservica_password.result })
  lifecycle {
    ignore_changes = [secret_string]
  }
}

module "vpc" {
  source                       = "git::https://github.com/nationalarchives/da-terraform-modules//vpc"
  vpc_name                     = "${local.environment}-vpc"
  az_count                     = local.az_count
  elastic_ip_allocation_ids    = data.aws_eip.eip.*.id
  nat_instance_security_groups = [module.nat_instance_security_group.security_group_id]
  environment                  = local.environment
}

data "aws_eip" "eip" {
  count = local.az_count
  filter {
    name   = "tag:Name"
    values = ["${local.environment}-eip-${count.index}"]
  }
}

module "nat_instance_security_group" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//security_group"
  common_tags = { CreatedBy = "dr2-terraform-environments" }
  description = "A security group to allow access to the NAT instance"
  name        = "${local.environment}-nat-instance-security-group"
  vpc_id      = module.vpc.vpc_id
  ingress_security_group_rules = [{
    port              = 443,
    description       = "Inbound HTTPS",
    security_group_id = module.outbound_https_access_only.security_group_id
  }]
  egress_cidr_rules = [{
    port        = 443
    description = "Outbound https access",
    cidr_blocks = ["0.0.0.0/0"],
    protocol    = "tcp"
  }]
}

module "outbound_https_access_only" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//security_group"
  common_tags = { CreatedBy = "dr2-terraform-environments" }
  description = "A security group to allow outbound access only"
  name        = "${local.environment}-outbound-https"
  vpc_id      = module.vpc.vpc_id
  egress_cidr_rules = [{
    port        = 443
    description = "Outbound https access",
    cidr_blocks = ["0.0.0.0/0"],
    protocol    = "tcp"
  }]
}

module "dr2_kms_key" {
  source   = "git::https://github.com/nationalarchives/da-terraform-modules//kms"
  key_name = "${local.environment}-kms-dr2"
  default_policy_variables = {
    user_roles = concat([
      module.ingest_parsed_court_document_event_handler_lambda.lambda_role_arn,
      module.download_metadata_and_files_lambda.lambda_role_arn,
      module.ingest_mapper_lambda.lambda_role_arn,
      module.ingest_asset_opex_creator_lambda.lambda_role_arn,
      module.ingest_folder_opex_creator_lambda.lambda_role_arn,
      module.ingest_upsert_archives_folder_lambda.lambda_role_arn
    ], local.additional_user_roles)
    ci_roles      = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.environment_title}TerraformRole"]
    service_names = ["cloudwatch", "sns"]
  }
}

module "dr2_developer_key" {
  source   = "git::https://github.com/nationalarchives/da-terraform-modules//kms"
  key_name = "${local.environment}-kms-dr2-dev"
  default_policy_variables = {
    user_roles = [
      data.aws_ssm_parameter.dev_admin_role.value,
      module.preservica_config_lambda.lambda_role_arn
    ]
    ci_roles      = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.environment_title}TerraformRole"]
    service_names = ["s3", "sns", "logs.eu-west-2", "cloudwatch"]
  }
}

data "aws_ssm_parameter" "dev_admin_role" {
  name = "/${local.environment}/developer_role"
}

module "ingest_raw_cache_bucket" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//s3"
  bucket_name = local.ingest_raw_cache_bucket_name
  logging_bucket_policy = templatefile("./templates/s3/log_bucket_policy.json.tpl", {
    bucket_name = "${local.ingest_raw_cache_bucket_name}-logs", account_id = var.account_number
  })
  bucket_policy = templatefile("./templates/s3/lambda_access_bucket_policy.json.tpl", {
    lambda_role_arns = jsonencode([module.ingest_parsed_court_document_event_handler_lambda.lambda_role_arn]),
    bucket_name      = local.ingest_raw_cache_bucket_name
  })
  kms_key_arn = module.dr2_kms_key.kms_key_arn
}

module "ingest_staging_cache_bucket" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//s3"
  bucket_name = local.ingest_staging_cache_bucket_name
  logging_bucket_policy = templatefile("./templates/s3/log_bucket_policy.json.tpl", {
    bucket_name = "${local.ingest_staging_cache_bucket_name}-logs", account_id = var.account_number
  })
  bucket_policy = templatefile("./templates/s3/lambda_access_bucket_policy.json.tpl", {
    lambda_role_arns = jsonencode([module.ingest_mapper_lambda.lambda_role_arn, module.ingest_parsed_court_document_event_handler_lambda.lambda_role_arn]),
    bucket_name      = local.ingest_staging_cache_bucket_name
  })
  kms_key_arn = module.dr2_kms_key.kms_key_arn
}

module "pre_ingest_step_function" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//sfn"
  step_function_definition = templatefile("${path.module}/templates/sfn/pre_ingest_sfn_definition.json.tpl", {
    step_function_name = local.pre_ingest_step_function_name
  })
  step_function_name                    = local.pre_ingest_step_function_name
  step_function_role_policy_attachments = {}
}

module "files_table" {
  source                         = "git::https://github.com/nationalarchives/da-terraform-modules//dynamo"
  hash_key                       = { name = "id", type = "S" }
  table_name                     = local.files_dynamo_table_name
  server_side_encryption_enabled = true
  kms_key_arn                    = module.dr2_kms_key.kms_key_arn
  additional_attributes = [
    { name = "batchId", type = "S" },
    { name = "parentPath", type = "S" }
  ]
  global_secondary_indexes = [
    {
      name            = local.files_table_global_secondary_index_name
      hash_key        = "batchId"
      range_key       = "parentPath"
      projection_type = "ALL"
    }
  ]
}

data "aws_ssm_parameter" "slack_token" {
  name            = "/mgmt/slack/token"
  with_decryption = true
}

data "aws_ssm_parameter" "dr2_notifications_slack_channel" {
  name = "/mgmt/slack/notifications/channel"
}

module "eventbridge_alarm_notifications_destination" {
  source                     = "git::https://github.com/nationalarchives/da-terraform-modules//eventbridge_api_destination"
  authorisation_header_value = "Bearer ${data.aws_ssm_parameter.slack_token.value}"
  name                       = "${local.environment}-eventbridge-slack-destination"
}

module "cloudwatch_alarm_event_bridge_rule" {
  for_each = toset(["OK", "ALARM"])
  source   = "git::https://github.com/nationalarchives/da-terraform-modules//eventbridge_api_destination_rule"
  event_pattern = templatefile("${path.module}/templates/eventbridge/cloudwatch_alarm_event_pattern.json.tpl", {
    cloudwatch_alarms = jsonencode(flatten([
      module.download_files_sqs.dlq_cloudwatch_alarm_arn,
      module.ingest_parsed_court_document_event_handler_sqs.dlq_cloudwatch_alarm_arn,
      module.preservica_config_queue.dlq_cloudwatch_alarm_arn
    ])),
    state_value = each.value
  })
  name                = "${local.environment}-eventbridge-alarm-state-change-${lower(each.value)}"
  api_destination_arn = module.eventbridge_alarm_notifications_destination.api_destination_arn
  input_transformer = {
    input_paths = {
      "alarmName"    = "$.detail.alarmName",
      "currentValue" = "$.detail.state.value"
    }
    input_template = templatefile("${path.module}/templates/eventbridge/slack_message_input_template.json.tpl", {
      channel_id   = data.aws_ssm_parameter.dr2_notifications_slack_channel.value
      slackMessage = ":${each.value == "OK" ? "green-tick" : "alert-noflash-slow"}: Cloudwatch alarm <alarmName> has entered state <currentValue>"
    })
  }
}

module "dev_slack_message_eventbridge_rule" {
  source              = "git::https://github.com/nationalarchives/da-terraform-modules//eventbridge_api_destination_rule"
  api_destination_arn = module.eventbridge_alarm_notifications_destination.api_destination_arn
  event_pattern       = templatefile("${path.module}/templates/eventbridge/custom_detail_type_event_pattern.json.tpl", { detail_type = "DR2DevMessage" })
  name                = "${local.environment}-eventbridge-dev-slack-message"
  input_transformer = {
    input_paths = {
      "slackMessage" = "$.detail.slackMessage"
    }
    input_template = templatefile("${path.module}/templates/eventbridge/slack_message_input_template.json.tpl", {
      channel_id   = data.aws_ssm_parameter.dr2_notifications_slack_channel.value
      slackMessage = "<slackMessage>"
    })
  }
}
