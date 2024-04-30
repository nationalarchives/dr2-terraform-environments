locals {
  az_count                                             = local.environment == "prod" ? 2 : 1
  ingest_raw_cache_bucket_name                         = "${local.environment}-dr2-ingest-raw-cache"
  sample_files_bucket_name                             = "${local.environment}-dr2-sample-files"
  ingest_staging_cache_bucket_name                     = "${local.environment}-dr2-ingest-staging-cache"
  ingest_step_function_name                            = "${local.environment}-dr2-ingest"
  additional_user_roles                                = local.environment != "prod" ? [data.aws_ssm_parameter.dev_admin_role.value] : []
  anonymiser_roles                                     = local.environment == "intg" ? flatten([module.dr2_court_document_package_anonymiser_lambda.*.lambda_role_arn]) : []
  anonymiser_lambda_arns                               = local.environment == "intg" ? flatten([module.dr2_court_document_package_anonymiser_lambda.*.lambda_arn]) : []
  files_dynamo_table_name                              = "${local.environment}-dr2-files"
  ingest_lock_dynamo_table_name                        = "${local.environment}-dr2-ingest-lock"
  files_table_batch_parent_global_secondary_index_name = "BatchParentPathIdx"
  files_table_ingest_ps_global_secondary_index_name    = "IngestPSIdx"
  ingest_lock_table_global_secondary_index_name        = "IngestLockBatchIdx"
  dev_notifications_channel_id                         = local.environment == "prod" ? "C06EDJPF0VB" : "C052LJASZ08"
  general_notifications_channel_id                     = local.environment == "prod" ? "C06E20AR65V" : "C068RLCPZFE"
  tre_prod_judgment_role                               = "arn:aws:iam::${module.tre_config.account_numbers["prod"]}:role/prod-tre-editorial-judgment-out-copier"
  tdr_export_notifications_role                        = "arn:aws:sns:eu-west-2:${module.tdr_config.account_numbers[local.environment]}:tdr-export-notifications-${local.environment}"
  java_runtime                                         = "java21"
  java_lambda_memory_size                              = 512
  java_timeout_seconds                                 = 60
  python_runtime                                       = "python3.12"
  python_lambda_memory_size                            = 128
  python_timeout_seconds                               = 30
  step_function_failure_log_group                      = "step-function-failures"
  terraform_role_arn                                   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.environment_title}TerraformRole"
  preservica_tenant                                    = local.environment == "prod" ? "tna" : "tnatest"
  preservica_ingest_bucket                             = "com.preservica.${local.preservica_tenant}.bulk1"
  tna_to_preservica_role_arn                           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.environment}-tna-to-preservica-ingest-s3-${local.preservica_tenant}"
  creator                                              = "dr2-terraform-environments"
  dashboard_lambdas = [
    local.ingest_asset_opex_creator_lambda_name,
    local.ingest_asset_reconciler_lambda_name,
    local.ingest_check_preservica_for_existing_io_lambda_name,
    local.ingest_folder_opex_creator_lambda_name,
    local.ingest_mapper_lambda_name,
    local.ingest_parent_folder_opex_creator_lambda_name,
    local.ingest_parsed_court_document_event_handler_lambda_name,
    local.ingest_start_workflow_lambda_name,
    local.ingest_upsert_archive_folders_lambda_name,
    local.ingest_workflow_monitor_lambda_name
  ]
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

resource "aws_secretsmanager_secret" "demo_preservica_secret" {
  name = "${local.environment}-demo-preservica-api-login-details-${random_string.preservica_user.result}"
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
  common_tags = { CreatedBy = local.creator }
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
      module.ingest_check_preservica_for_existing_io_lambda.lambda_role_arn,
      module.dr2_ingest_parsed_court_document_event_handler_lambda.lambda_role_arn,
      module.dr2_ingest_mapper_lambda.lambda_role_arn,
      module.dr2_ingest_asset_opex_creator_lambda.lambda_role_arn,
      module.dr2_ingest_folder_opex_creator_lambda.lambda_role_arn,
      module.dr2_ingest_upsert_archive_folders_lambda.lambda_role_arn,
      module.dr2_ingest_parent_folder_opex_creator_lambda.lambda_role_arn,
      module.dr2_ingest_asset_reconciler_lambda.lambda_role_arn,
      module.e2e_tests_ecs_task_role.role_arn,
      local.tna_to_preservica_role_arn,
      local.tre_prod_judgment_role,
    ], local.additional_user_roles, local.anonymiser_roles)
    ci_roles = [local.terraform_role_arn]
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
      module.dr2_preservica_config_lambda.lambda_role_arn
    ]
    ci_roles      = [local.terraform_role_arn]
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
    lambda_role_arns = jsonencode([module.dr2_ingest_parsed_court_document_event_handler_lambda.lambda_role_arn]),
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
      module.dr2_ingest_mapper_lambda.lambda_role_arn,
      module.dr2_ingest_parsed_court_document_event_handler_lambda.lambda_role_arn,
      module.dr2_ingest_parent_folder_opex_creator_lambda.lambda_role_arn
    ]),
    bucket_name = local.ingest_staging_cache_bucket_name
  })
  kms_key_arn = module.dr2_kms_key.kms_key_arn
}

module "dr2_ingest_step_function" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//sfn"
  step_function_definition = templatefile("${path.module}/templates/sfn/ingest_sfn_definition.json.tpl", {
    step_function_name                            = local.ingest_step_function_name,
    account_id                                    = var.account_number
    ingest_mapper_lambda_name                     = local.ingest_mapper_lambda_name
    ingest_upsert_archive_folders_lambda_name     = local.ingest_upsert_archive_folders_lambda_name
    ingest_check_preservica_for_existing_io       = local.ingest_check_preservica_for_existing_io_lambda_name
    ingest_asset_opex_creator_lambda_name         = local.ingest_asset_opex_creator_lambda_name
    ingest_folder_opex_creator_lambda_name        = local.ingest_folder_opex_creator_lambda_name
    ingest_parent_folder_opex_creator_lambda_name = local.ingest_parent_folder_opex_creator_lambda_name
    ingest_start_workflow_lambda_name             = local.ingest_start_workflow_lambda_name
    ingest_workflow_monitor_lambda_name           = local.ingest_workflow_monitor_lambda_name
    ingest_asset_reconciler_lambda_name           = local.ingest_asset_reconciler_lambda_name
    ingest_staging_cache_bucket_name              = local.ingest_staging_cache_bucket_name
    preservica_bucket_name                        = local.preservica_ingest_bucket
    datasync_task_arn                             = aws_datasync_task.dr2_copy_tna_to_preservica.arn
    tna_to_preservica_role_arn                    = local.tna_to_preservica_role_arn
  })
  step_function_name = local.ingest_step_function_name
  step_function_role_policy_attachments = {
    step_function_policy = module.dr2_ingest_step_function_policy.policy_arn
  }
}


resource "aws_datasync_location_s3" "tna_staging_location" {
  provider      = aws.datasync_tna_to_preservica
  s3_bucket_arn = "arn:aws:s3:::${local.ingest_staging_cache_bucket_name}"
  subdirectory  = "/"
  s3_config {
    bucket_access_role_arn = local.tna_to_preservica_role_arn
  }
}

resource "aws_datasync_location_s3" "preservica_staging_location" {
  provider      = aws.datasync_tna_to_preservica
  s3_bucket_arn = "arn:aws:s3:::${local.preservica_ingest_bucket}"
  subdirectory  = "/"
  s3_config {
    bucket_access_role_arn = local.tna_to_preservica_role_arn
  }
}

resource "aws_cloudwatch_log_group" "datasync_log_group" {
  name = "/aws/datasync/tna-to-preservica-copy"
}

resource "aws_datasync_task" "tna_to_preservica_copy" {
  provider                 = aws.datasync_tna_to_preservica
  destination_location_arn = aws_datasync_location_s3.preservica_staging_location.arn
  source_location_arn      = aws_datasync_location_s3.tna_staging_location.arn
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.datasync_log_group.arn
  options {
    log_level         = "TRANSFER"
    posix_permissions = "NONE"
    uid               = "NONE"
    gid               = "NONE"
  }
  name = "${local.environment}-tna-to-preservica-copy"
}

resource "aws_datasync_task" "dr2_copy_tna_to_preservica" {
  provider                 = aws.datasync_tna_to_preservica
  destination_location_arn = aws_datasync_location_s3.preservica_staging_location.arn
  source_location_arn      = aws_datasync_location_s3.tna_staging_location.arn
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.datasync_log_group.arn
  options {
    log_level         = "TRANSFER"
    posix_permissions = "NONE"
    uid               = "NONE"
    gid               = "NONE"
  }
  name = "${local.environment}-dr2-tna-to-preservica-copy"
}

module "dr2_ingest_step_function_policy" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name   = "${local.environment}-dr2-ingest-step-function-policy"
  policy_string = templatefile("${path.module}/templates/iam_policy/ingest_step_function_policy.json.tpl", {
    account_id                                    = var.account_number
    ingest_mapper_lambda_name                     = local.ingest_mapper_lambda_name
    ingest_upsert_archive_folders_lambda_name     = local.ingest_upsert_archive_folders_lambda_name
    ingest_check_preservica_for_existing_io       = local.ingest_check_preservica_for_existing_io_lambda_name
    ingest_asset_opex_creator_lambda_name         = local.ingest_asset_opex_creator_lambda_name
    ingest_folder_opex_creator_lambda_name        = local.ingest_folder_opex_creator_lambda_name
    ingest_parent_folder_opex_creator_lambda_name = local.ingest_parent_folder_opex_creator_lambda_name
    ingest_start_workflow_lambda_name             = local.ingest_start_workflow_lambda_name
    ingest_workflow_monitor_lambda_name           = local.ingest_workflow_monitor_lambda_name
    ingest_asset_reconciler_lambda_name           = local.ingest_asset_reconciler_lambda_name
    ingest_staging_cache_bucket_name              = local.ingest_staging_cache_bucket_name
    ingest_sfn_name                               = local.ingest_step_function_name
    tna_to_preservica_role_arn                    = local.tna_to_preservica_role_arn
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
    { name = "parentPath", type = "S" },
    { name = "ingested_PS", type = "S" }
  ]
  global_secondary_indexes = [
    {
      name            = local.files_table_batch_parent_global_secondary_index_name
      hash_key        = "batchId"
      range_key       = "parentPath"
      projection_type = "ALL"
    },
    {
      name            = local.files_table_ingest_ps_global_secondary_index_name
      hash_key        = "ingested_PS"
      projection_type = "ALL"
    }
  ]
}

module "ingest_lock_table" {
  source                         = "git::https://github.com/nationalarchives/da-terraform-modules//dynamo"
  hash_key                       = { name = "ioId", type = "S" }
  table_name                     = local.ingest_lock_dynamo_table_name
  server_side_encryption_enabled = true
  kms_key_arn                    = module.dr2_kms_key.kms_key_arn
  additional_attributes = [
    { name = "batchId", type = "S" }
  ]
  global_secondary_indexes = [
    {
      name            = local.ingest_lock_table_global_secondary_index_name
      hash_key        = "batchId"
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
  name                       = "${local.environment}-dr2-eventbridge-slack-destination"
}

module "cloudwatch_alarm_event_bridge_rule" {
  for_each = toset(["OK", "ALARM"])
  source   = "git::https://github.com/nationalarchives/da-terraform-modules//eventbridge_api_destination_rule"
  event_pattern = templatefile("${path.module}/templates/eventbridge/cloudwatch_alarm_event_pattern.json.tpl", {
    cloudwatch_alarms = jsonencode(flatten([
      module.dr2_ingest_parsed_court_document_event_handler_sqs.dlq_cloudwatch_alarm_arn,
      module.dr2_preservica_config_queue.dlq_cloudwatch_alarm_arn
    ])),
    state_value = each.value
  })
  name                = "${local.environment}-dr2-eventbridge-alarm-state-change-${lower(each.value)}"
  api_destination_arn = module.eventbridge_alarm_notifications_destination.api_destination_arn
  api_destination_input_transformer = {
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
    step_function_arn = module.dr2_ingest_step_function.step_function_arn
  })
  name                = "${local.environment}-dr2-eventbridge-ingest-step-function-failure"
  api_destination_arn = module.eventbridge_alarm_notifications_destination.api_destination_arn
  api_destination_input_transformer = {
    input_paths = {
      "name"   = "$.detail.name",
      "status" = "$.detail.status"
    }
    input_template = templatefile("${path.module}/templates/eventbridge/slack_message_input_template.json.tpl", {
      channel_id   = local.dev_notifications_channel_id
      slackMessage = ":alert-noflash-slow: Step function ${local.ingest_step_function_name} with name <name> has <status>"
    })
  }
  log_group_destination_input_transformer = {
    log_group_name = local.step_function_failure_log_group
    input_paths = {
      "name"      = "$.detail.name",
      "status"    = "$.detail.status",
      "startDate" = "$.detail.startDate"
    }
    input_template = templatefile("${path.module}/templates/eventbridge/cloudwatch_message_input_template.json.tpl", {
      message = "Step function ${local.ingest_step_function_name} with name <name> has <status>"
    })
  }

}

module "guard_duty_findings_eventbridge_rule" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//eventbridge_api_destination_rule"
  event_pattern = templatefile("${path.module}/templates/eventbridge/source_detail_type_event_pattern.json.tpl", {
    source = "aws.guardduty", detail_type = "GuardDuty Finding"
  })
  name                = "${local.environment}-dr2-guard-duty-notify"
  api_destination_arn = module.eventbridge_alarm_notifications_destination.api_destination_arn
  api_destination_input_transformer = {
    input_paths = {
      "account" : "$.account",
      "id" : "$.detail.id",
      "region" : "$.region",
      "title" : "$.detail.title"
    }
    input_template = templatefile("${path.module}/templates/eventbridge/guard_duty_slack_message.json.tpl", {})
  }
}

module "dev_slack_message_eventbridge_rule" {
  source              = "git::https://github.com/nationalarchives/da-terraform-modules//eventbridge_api_destination_rule"
  api_destination_arn = module.eventbridge_alarm_notifications_destination.api_destination_arn
  event_pattern       = templatefile("${path.module}/templates/eventbridge/custom_detail_type_event_pattern.json.tpl", { detail_type = "DR2DevMessage" })
  name                = "${local.environment}-dr2-eventbridge-dev-slack-message"
  api_destination_input_transformer = {
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
  name                = "${local.environment}-dr2-eventbridge-general-slack-message"
  api_destination_input_transformer = {
    input_paths = {
      "slackMessage" = "$.detail.slackMessage"
    }
    input_template = templatefile("${path.module}/templates/eventbridge/slack_message_input_template.json.tpl", {
      channel_id   = local.general_notifications_channel_id
      slackMessage = "<slackMessage>"
    })
  }
}

resource "aws_cloudwatch_log_resource_policy" "eventbridge_resource_policy" {
  policy_document = templatefile("${path.module}/templates/logs/logs_resource_policy.json.tpl", { account_id = data.aws_caller_identity.current.account_id })
  policy_name     = "${local.environment}-dr2-trust-events-to-store-log-events"
}

resource "aws_cloudwatch_dashboard" "ingest_dashboard" {
  dashboard_body = templatefile("${path.module}/templates/logs/ingest_dashboard.json.tpl", {
    account_id                      = data.aws_caller_identity.current.account_id,
    environment                     = local.environment,
    step_function_failure_log_group = local.step_function_failure_log_group
    source_list                     = join(" | ", [for lambda in local.dashboard_lambdas : format("SOURCE '/aws/lambda/%s'", lambda)])
  })
  dashboard_name = "${local.environment}-dr2-ingest-dashboard"
}

module "tdr_export_notifications_subscription_role" {
  source             = "git::https://github.com/nationalarchives/da-terraform-modules//iam_role"
  assume_role_policy = templatefile("${path.module}/templates/iam_role/aws_principal_assume_role.json.tpl", { aws_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" })
  name               = "${local.environment}-tdr-export-notifications-role"
  policy_attachments = {
    subscribe_policy = module.tdr_export_notifications_subscription_policy.policy_arn
  }
  tags = {}
}

module "tdr_export_notifications_subscription_policy" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name          = "${local.environment}-tdr-export-notifications-policy"
  policy_string = templatefile("${path.module}/templates/iam_policy/subscribe_to_tdr_export_notifications.json.tpl", { tdr_sns_arn = local.tdr_export_notifications_role })
}
