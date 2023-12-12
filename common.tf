locals {
  az_count                                = local.environment == "prod" ? 2 : 1
  ingest_raw_cache_bucket_name            = "${local.environment}-dr2-ingest-raw-cache"
  sample_files_bucket_name                = "${local.environment}-dr2-sample-files"
  ingest_staging_cache_bucket_name        = "${local.environment}-dr2-ingest-staging-cache"
  ingest_step_function_name               = "${local.environment_title}-ingest"
  additional_user_roles                   = local.environment != "prod" ? [data.aws_ssm_parameter.dev_admin_role.value] : []
  files_dynamo_table_name                 = "${local.environment}-dr2-files"
  files_table_global_secondary_index_name = "BatchParentPathIdx"
  dev_notifications_channel_id            = "C052LJASZ08"
  general_notifications_channel_id        = "C068RLCPZFE"
  tre_prod_judgment_role                  = "arn:aws:iam::${module.tre_config.account_numbers["prod"]}:role/prod-tre-editorial-judgment-out-copier"
  java_runtime                            = "java21"
  java_lambda_memory_size                 = 512
  python_runtime                          = "python3.11"
  python_lambda_memory_size               = 128
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
  source                    = "git::https://github.com/nationalarchives/da-terraform-modules//vpc"
  vpc_name                  = "${local.environment}-vpc"
  az_count                  = local.az_count
  elastic_ip_allocation_ids = data.aws_eip.eip.*.id
  use_nat_gateway           = true
  environment               = local.environment
  private_nacl_rules = [
    { rule_no = 100, cidr_block = "0.0.0.0/0", action = "allow", from_port = 443, to_port = 443, egress = true },
    { rule_no = 100, cidr_block = "0.0.0.0/0", action = "allow", from_port = 1024, to_port = 65535, egress = false },
  ]
  public_nacl_rules = [
    { rule_no = 100, cidr_block = "0.0.0.0/0", action = "allow", from_port = 443, to_port = 443, egress = false },
    { rule_no = 200, cidr_block = "0.0.0.0/0", action = "allow", from_port = 1024, to_port = 65535, egress = false },
    { rule_no = 100, cidr_block = "0.0.0.0/0", action = "allow", from_port = 443, to_port = 443, egress = true },
    { rule_no = 200, cidr_block = "0.0.0.0/0", action = "allow", from_port = 1024, to_port = 65535, egress = true },
  ]
}

data "aws_eip" "eip" {
  count = local.az_count
  filter {
    name   = "tag:Name"
    values = ["${local.environment}-eip-${count.index}"]
  }
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
      module.ingest_upsert_archive_folders_lambda.lambda_role_arn,
      module.ingest_parent_folder_opex_creator_lambda.lambda_role_arn,
      module.e2e_tests_ecs_task_role.role_arn,
      module.copy_tna_to_preservica_role.role_arn,
      local.tre_prod_judgment_role,
      module.s3_copy_lambda.lambda_role_arn,
      module.court_document_package_anonymiser_lambda.lambda_role_arn
    ], local.additional_user_roles)
    ci_roles = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.environment_title}TerraformRole"]
    service_details = [
      { service_name = "cloudwatch" },
      { service_name = "sns", service_source_account = module.tre_config.account_numbers["prod"] },
      { service_name = "sns" },
    ]
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
  bucket_policy = templatefile("./templates/s3/lambda_access_bucket_policy.json.tpl", {
    lambda_role_arns = jsonencode([module.ingest_parsed_court_document_event_handler_lambda.lambda_role_arn]),
    bucket_name      = local.ingest_raw_cache_bucket_name
  })
  kms_key_arn = module.dr2_kms_key.kms_key_arn
}

module "sample_files_bucket" {
  source            = "git::https://github.com/nationalarchives/da-terraform-modules//s3"
  bucket_name       = local.sample_files_bucket_name
  create_log_bucket = false
  kms_key_arn       = module.dr2_kms_key.kms_key_arn
}

module "ingest_staging_cache_bucket" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//s3"
  bucket_name = local.ingest_staging_cache_bucket_name
  bucket_policy = templatefile("./templates/s3/lambda_access_bucket_policy.json.tpl", {
    lambda_role_arns = jsonencode([
      module.ingest_mapper_lambda.lambda_role_arn,
      module.ingest_parsed_court_document_event_handler_lambda.lambda_role_arn,
      module.ingest_parent_folder_opex_creator_lambda.lambda_role_arn
    ]),
    bucket_name = local.ingest_staging_cache_bucket_name
  })
  kms_key_arn = module.dr2_kms_key.kms_key_arn
}

module "ingest_step_function" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//sfn"
  step_function_definition = templatefile("${path.module}/templates/sfn/ingest_sfn_definition.json.tpl", {
    step_function_name                            = local.ingest_step_function_name,
    account_id                                    = var.account_number
    ingest_mapper_lambda_name                     = local.ingest_mapper_lambda_name
    ingest_upsert_archive_folders_lambda_name     = local.ingest_upsert_archive_folders_lambda_name
    ingest_asset_opex_creator_lambda_name         = local.ingest_asset_opex_creator_lambda_name
    ingest_folder_opex_creator_lambda_name        = local.ingest_folder_opex_creator_lambda_name
    ingest_parent_folder_opex_creator_lambda_name = local.ingest_parent_folder_opex_creator_lambda_name
    ingest_start_workflow_lambda_name             = local.ingest_start_workflow_lambda_name
    ingest_s3_copy_lambda_name                    = local.s3_copy_lambda_name
    ingest_staging_cache_bucket_name              = local.ingest_staging_cache_bucket_name
    preservica_bucket_name                        = local.preservica_ingest_bucket
  })
  step_function_name = local.ingest_step_function_name
  step_function_role_policy_attachments = {
    step_function_policy = module.ingest_step_function_policy.policy_arn
  }
}

module "ingest_step_function_policy" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name   = "${local.environment_title}IngestStepFunctionPolicy"
  policy_string = templatefile("${path.module}/templates/iam_policy/ingest_step_function_policy.json.tpl", {
    account_id                                    = var.account_number
    ingest_mapper_lambda_name                     = local.ingest_mapper_lambda_name
    ingest_upsert_archive_folders_lambda_name     = local.ingest_upsert_archive_folders_lambda_name
    ingest_asset_opex_creator_lambda_name         = local.ingest_asset_opex_creator_lambda_name
    ingest_folder_opex_creator_lambda_name        = local.ingest_folder_opex_creator_lambda_name
    ingest_parent_folder_opex_creator_lambda_name = local.ingest_parent_folder_opex_creator_lambda_name
    ingest_start_workflow_lambda_name             = local.ingest_start_workflow_lambda_name
    ingest_s3_copy_lambda_name                    = local.s3_copy_lambda_name
    ingest_staging_cache_bucket_name              = local.ingest_staging_cache_bucket_name
    ingest_sfn_name                               = local.ingest_step_function_name
  })
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
      channel_id   = local.dev_notifications_channel_id
      slackMessage = ":${each.value == "OK" ? "green-tick" : "alert-noflash-slow"}: Cloudwatch alarm <alarmName> has entered state <currentValue>"
    })
  }
}

module "failed_ingest_step_function_event_bridge_rule" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//eventbridge_api_destination_rule"
  event_pattern = templatefile("${path.module}/templates/eventbridge/step_function_failed_event_pattern.json.tpl", {
    step_function_arn = module.ingest_step_function.step_function_arn
  })
  name                = "${local.environment}-eventbridge-ingest-step-function-failure"
  api_destination_arn = module.eventbridge_alarm_notifications_destination.api_destination_arn
  input_transformer = {
    input_paths = {
      "name"   = "$.detail.name",
      "status" = "$.detail.status"
    }
    input_template = templatefile("${path.module}/templates/eventbridge/slack_message_input_template.json.tpl", {
      channel_id   = local.dev_notifications_channel_id
      slackMessage = ":alert-noflash-slow: Step function ${local.ingest_step_function_name} with name <name> has <status>"
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
      channel_id   = local.dev_notifications_channel_id
      slackMessage = "<slackMessage>"
    })
  }
}

module "general_slack_message_eventbridge_rule" {
  source              = "git::https://github.com/nationalarchives/da-terraform-modules//eventbridge_api_destination_rule"
  api_destination_arn = module.eventbridge_alarm_notifications_destination.api_destination_arn
  event_pattern       = templatefile("${path.module}/templates/eventbridge/custom_detail_type_event_pattern.json.tpl", { detail_type = "DR2Message" })
  name                = "${local.environment}-eventbridge-general-slack-message"
  input_transformer = {
    input_paths = {
      "slackMessage" = "$.detail.slackMessage"
    }
    input_template = templatefile("${path.module}/templates/eventbridge/slack_message_input_template.json.tpl", {
      channel_id   = local.general_notifications_channel_id
      slackMessage = "<slackMessage>"
    })
  }
}

module "security_hub_eventbridge_rule" {
  source              = "git::https://github.com/nationalarchives/da-terraform-modules//eventbridge_api_destination_rule"
  api_destination_arn = module.eventbridge_alarm_notifications_destination.api_destination_arn
  event_pattern       = templatefile("${path.module}/templates/eventbridge/security_hub_event_pattern.json.tpl", {})
  name                = "${local.environment}-security-hub"
  input_transformer = {
    input_paths = {
      "id" : "$.detail.findings[0].Resources[0].Id",
      "title" : "$.detail.findings[0].Title"
    }
    input_template = templatefile("${path.module}/templates/eventbridge/slack_message_input_template.json.tpl", {
      channel_id   = local.dev_notifications_channel_id
      slackMessage = ":alert-noflash-slow: Security Hub finding for `<id>` <title>"
    })
  }
}
