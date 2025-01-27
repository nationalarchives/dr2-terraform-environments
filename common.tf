locals {
  az_count                                             = local.environment == "prod" ? 2 : 1
  ingest_raw_cache_bucket_name                         = "${local.environment}-dr2-ingest-raw-cache"
  sample_files_bucket_name                             = "${local.environment}-dr2-sample-files"
  ingest_state_bucket_name                             = "${local.environment}-dr2-ingest-state"
  ingest_step_function_name                            = "${local.environment}-dr2-ingest"
  ingest_run_workflow_step_function_name               = "${local.environment}-dr2-ingest-run-workflow"
  additional_user_roles                                = local.environment != "prod" ? [data.aws_ssm_parameter.dev_admin_role.value] : []
  anonymiser_roles                                     = local.environment == "intg" ? flatten([module.dr2_court_document_package_anonymiser_lambda.*.lambda_role_arn]) : []
  e2e_test_roles                                       = local.environment == "intg" ? [module.dr2_run_e2e_tests_role[0].role_arn] : []
  anonymiser_lambda_arns                               = local.environment == "intg" ? flatten([module.dr2_court_document_package_anonymiser_lambda.*.lambda_arn]) : []
  files_dynamo_table_name                              = "${local.environment}-dr2-ingest-files"
  ingest_lock_dynamo_table_name                        = "${local.environment}-dr2-ingest-lock"
  ingest_queue_dynamo_table_name                       = "${local.environment}-dr2-ingest-queue"
  enable_point_in_time_recovery                        = true
  files_table_batch_parent_global_secondary_index_name = "BatchParentPathIdx"
  files_table_ingest_ps_global_secondary_index_name    = "IngestPSIdx"
  ingest_lock_table_group_id_gsi_name                  = "IngestLockGroupIdx"
  ingest_lock_table_hash_key                           = "assetId"
  dev_notifications_channel_id                         = local.environment == "prod" ? "C06EDJPF0VB" : "C052LJASZ08"
  general_notifications_channel_id                     = local.environment == "prod" ? "C06E20AR65V" : "C068RLCPZFE"
  tre_prod_judgment_role                               = "arn:aws:iam::${module.tre_config.account_numbers["prod"]}:role/prod-tre-editorial-judgment-out-copier"
  java_runtime                                         = "java21"
  java_lambda_memory_size                              = 512
  java_timeout_seconds                                 = 180
  python_runtime                                       = "python3.12"
  python_lambda_memory_size                            = 128
  python_timeout_seconds                               = 30
  step_function_failure_log_group                      = "step-function-failures"
  terraform_role_arn                                   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.environment_title}TerraformRole"
  preservica_tenant                                    = local.environment == "prod" ? "tna" : "tnatest"
  preservica_ingest_bucket                             = "com.preservica.${local.preservica_tenant}.bulk1"
  tna_to_preservica_role_arn                           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.environment}-tna-to-preservica-ingest-s3-${local.preservica_tenant}"
  creator                                              = "dr2-terraform-environments"
  sse_encryption                                       = "sse"
  visibility_timeout                                   = 180
  redrive_maximum_receives                             = 5
  ingest_run_workflow_sfn_arn                          = "arn:aws:states:eu-west-2:${data.aws_caller_identity.current.account_id}:stateMachine:${local.ingest_run_workflow_step_function_name}"
  dashboard_lambdas = flatten([[
    local.copy_files_from_tdr_name,

    local.custodial_copy_ingest_lambda_name,
    local.entity_event_lambda_name,
    local.files_change_handler_name,
    local.get_latest_preservica_version,
    local.ingest_asset_opex_creator_lambda_name,
    local.ingest_asset_reconciler_lambda_name,
    local.ingest_failure_notifications_lambda_name,
    local.ingest_find_existing_asset_name,
    local.ingest_folder_opex_creator_lambda_name,
    local.ingest_mapper_lambda_name,
    local.ingest_parent_folder_opex_creator_lambda_name,
    local.ingest_parsed_court_document_event_handler_lambda_name,
    local.ingest_queue_creator_name,
    local.ingest_start_workflow_lambda_name,
    local.ingest_upsert_archive_folders_lambda_name,
    local.ingest_validate_generic_ingest_inputs_lambda_name,
    local.ingest_workflow_monitor_lambda_name, #
    local.ip_lock_checker_lambda_name,
    local.rotate_preservation_system_password_name,
    local.tdr_aggregator_name,
    local.tdr_package_builder_lambda_name
  ], local.environment == "intg" ? [local.court_document_anonymiser_lambda_name] : []])
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

resource "aws_secretsmanager_secret" "preservica_read_metadata_read_content" {
  name = "${local.environment}-preservica-api-read-metadata-read-content"
}

resource "aws_secretsmanager_secret" "preservica_read_metadata" {
  name = "${local.environment}-preservica-api-read-metadata"
}

resource "aws_secretsmanager_secret" "preservica_read_update_metadata_insert_content" {
  name = "${local.environment}-preservica-api-read-update-metadata-insert-content"
}

resource "aws_secretsmanager_secret_rotation" "secret_rotation" {
  for_each = toset([
    aws_secretsmanager_secret.preservica_secret.id,
    aws_secretsmanager_secret.preservica_read_metadata_read_content.id,
    aws_secretsmanager_secret.preservica_read_metadata.id,
    aws_secretsmanager_secret.preservica_read_update_metadata_insert_content.id
  ])
  rotation_lambda_arn = module.dr2_rotate_preservation_system_password_lambda.lambda_arn
  secret_id           = each.key
  rotation_rules {
    schedule_expression = "rate(4 hours)"
  }
}

resource "aws_secretsmanager_secret" "demo_preservica_secret" {
  name = "${local.environment}-demo-preservica-api-login-details-${random_string.preservica_user.result}"
}

data "aws_ssm_parameter" "slack_webhook_url" {
  name = "/${local.environment}/slack/cloudwatch-alarm-webhook"
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
  common_tags = {}
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
      module.ingest_find_existing_asset.lambda_role_arn,
      module.ingest_find_existing_asset.lambda_role_arn,
      module.dr2_ingest_validate_generic_ingest_inputs_lambda.lambda_role_arn,
      module.dr2_ingest_parsed_court_document_event_handler_lambda.lambda_role_arn,
      module.dr2_ingest_mapper_lambda.lambda_role_arn,
      module.dr2_ingest_asset_opex_creator_lambda.lambda_role_arn,
      module.dr2_ingest_folder_opex_creator_lambda.lambda_role_arn,
      module.dr2_ingest_upsert_archive_folders_lambda.lambda_role_arn,
      module.dr2_ingest_parent_folder_opex_creator_lambda.lambda_role_arn,
      module.dr2_ingest_asset_reconciler_lambda.lambda_role_arn,
      module.dr2_ingest_step_function.step_function_role_arn,
      module.dr2_custodial_copy_ingest_lambda.lambda_role_arn,
      module.dr2_ingest_files_change_handler_lambda.lambda_role_arn,
      module.dr2_preingest_tdr_aggregator_lambda.lambda_role_arn,
      module.dr2_preingest_tdr_package_builder_lambda.lambda_role_arn,
      module.dr2_copy_files_from_tdr_lambda.lambda_role_arn,
      local.tna_to_preservica_role_arn,
      local.tre_prod_judgment_role,
    ], local.additional_user_roles, local.anonymiser_roles, local.e2e_test_roles)
    ci_roles = [local.terraform_role_arn]
    service_details = [
      { service_name = "cloudwatch" },
      { service_name = "sns", service_source_account = module.tre_config.account_numbers["prod"] },
      { service_name = "sns" },
    ]
  }
}

module "dr2_developer_key" {
  source   = "git::https://github.com/nationalarchives/da-terraform-modules//kms"
  key_name = "${local.environment}-kms-dr2-dev"
  default_policy_variables = {
    user_roles = [
      data.aws_ssm_parameter.dev_admin_role.value,
      module.dr2_ingest_mapper_lambda.lambda_role_arn,
      module.dr2_ingest_step_function.step_function_role_arn
    ]
    ci_roles = [local.terraform_role_arn]
    service_details = [
      { service_name = "s3" },
      { service_name = "sns" },
      { service_name = "logs.eu-west-2" },
      { service_name = "cloudwatch" }
    ]
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

module "dr2_ingest_step_function" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//sfn"
  step_function_definition = templatefile("${path.module}/templates/sfn/ingest_sfn_definition.json.tpl", {
    step_function_name                                = local.ingest_step_function_name,
    account_id                                        = data.aws_caller_identity.current.account_id
    ingest_validate_generic_ingest_inputs_lambda_name = local.ingest_validate_generic_ingest_inputs_lambda_name
    ingest_mapper_lambda_name                         = local.ingest_mapper_lambda_name
    ingest_find_existing_asset_name_lambda_name       = local.ingest_find_existing_asset_name
    ingest_asset_opex_creator_lambda_name             = local.ingest_asset_opex_creator_lambda_name
    ingest_folder_opex_creator_lambda_name            = local.ingest_folder_opex_creator_lambda_name
    ingest_parent_folder_opex_creator_lambda_name     = local.ingest_parent_folder_opex_creator_lambda_name
    ingest_asset_reconciler_lambda_name               = local.ingest_asset_reconciler_lambda_name
    ingest_lock_table_name                            = local.ingest_lock_dynamo_table_name
    ingest_lock_table_group_id_gsi_name               = local.ingest_lock_table_group_id_gsi_name
    ingest_lock_table_hash_key                        = local.ingest_lock_table_hash_key
    ingest_run_workflow_sfn_name                      = local.ingest_run_workflow_step_function_name
    notifications_topic_name                          = local.notifications_topic_name
    ingest_state_bucket_name                          = local.ingest_state_bucket_name
    preservica_bucket_name                            = local.preservica_ingest_bucket
    ingest_files_table_name                           = local.files_dynamo_table_name
    ingest_queue_table_name                           = local.ingest_queue_dynamo_table_name
  })
  step_function_name = local.ingest_step_function_name
  step_function_role_policy_attachments = {
    step_function_policy = module.dr2_ingest_step_function_policy.policy_arn
  }
}

module "dr2_ingest_run_workflow_step_function" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//sfn"
  step_function_definition = templatefile("${path.module}/templates/sfn/ingest_run_workflow_sfn_definition.json.tpl", {
    step_function_name                        = local.ingest_run_workflow_step_function_name
    account_id                                = data.aws_caller_identity.current.account_id
    ingest_upsert_archive_folders_lambda_name = local.ingest_upsert_archive_folders_lambda_name
    ingest_start_workflow_lambda_name         = local.ingest_start_workflow_lambda_name
    ingest_workflow_monitor_lambda_name       = local.ingest_workflow_monitor_lambda_name
  })
  step_function_name = local.ingest_run_workflow_step_function_name
  step_function_role_policy_attachments = {
    step_function_policy = module.dr2_ingest_run_workflow_step_function_policy.policy_arn
  }
}

module "ingest_state_bucket" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//s3"
  bucket_name = local.ingest_state_bucket_name
  bucket_policy = templatefile("./templates/s3/lambda_access_bucket_policy.json.tpl", {
    lambda_role_arns = jsonencode([module.dr2_ingest_mapper_lambda.lambda_role_arn]),
    bucket_name      = local.ingest_state_bucket_name
  })
  kms_key_arn = module.dr2_developer_key.kms_key_arn
}


resource "aws_cloudwatch_log_group" "datasync_log_group" {
  name = "/aws/datasync/tna-to-preservica-copy"
}

module "dr2_ingest_step_function_policy" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name   = "${local.environment}-dr2-ingest-step-function-policy"
  policy_string = templatefile("${path.module}/templates/iam_policy/ingest_step_function_policy.json.tpl", {
    account_id                                        = data.aws_caller_identity.current.account_id
    ingest_validate_generic_ingest_inputs_lambda_name = local.ingest_validate_generic_ingest_inputs_lambda_name
    ingest_mapper_lambda_name                         = local.ingest_mapper_lambda_name
    ingest_upsert_archive_folders_lambda_name         = local.ingest_upsert_archive_folders_lambda_name
    ingest_find_existing_asset_lambda_name            = local.ingest_find_existing_asset_name
    ingest_asset_opex_creator_lambda_name             = local.ingest_asset_opex_creator_lambda_name
    ingest_folder_opex_creator_lambda_name            = local.ingest_folder_opex_creator_lambda_name
    ingest_parent_folder_opex_creator_lambda_name     = local.ingest_parent_folder_opex_creator_lambda_name
    ingest_start_workflow_lambda_name                 = local.ingest_start_workflow_lambda_name
    ingest_workflow_monitor_lambda_name               = local.ingest_workflow_monitor_lambda_name
    ingest_asset_reconciler_lambda_name               = local.ingest_asset_reconciler_lambda_name
    ingest_lock_table_name                            = local.ingest_lock_dynamo_table_name
    ingest_lock_table_group_id_gsi_name               = local.ingest_lock_table_group_id_gsi_name
    notifications_topic_name                          = local.notifications_topic_name
    ingest_queue_table_name                           = local.ingest_queue_dynamo_table_name
    ingest_state_bucket_name                          = local.ingest_state_bucket_name
    ingest_sfn_name                                   = local.ingest_step_function_name
    ingest_run_workflow_sfn_name                      = local.ingest_run_workflow_step_function_name
    ingest_files_table_name                           = local.files_dynamo_table_name
    tna_to_preservica_role_arn                        = local.tna_to_preservica_role_arn
    preingest_tdr_step_function_arn                   = local.preingest_sfn_arn
    ingest_run_workflow_sfn_arn                       = local.ingest_run_workflow_sfn_arn
  })
}

module "dr2_ingest_run_workflow_step_function_policy" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name   = "${local.environment}-dr2-ingest-run-workflow-step-function-policy"
  policy_string = templatefile("${path.module}/templates/iam_policy/ingest_run_workflow_step_function_policy.json.tpl", {
    account_id                                = data.aws_caller_identity.current.account_id
    ingest_upsert_archive_folders_lambda_name = local.ingest_upsert_archive_folders_lambda_name
    ingest_start_workflow_lambda_name         = local.ingest_start_workflow_lambda_name
    ingest_workflow_monitor_lambda_name       = local.ingest_workflow_monitor_lambda_name
  })
}

module "files_table" {
  source                         = "git::https://github.com/nationalarchives/da-terraform-modules//dynamo"
  hash_key                       = { name = "id", type = "S" }
  range_key                      = { name = "batchId", type = "S" }
  table_name                     = local.files_dynamo_table_name
  server_side_encryption_enabled = true
  kms_key_arn                    = module.dr2_kms_key.kms_key_arn
  ttl_attribute_name             = "ttl"
  stream_enabled                 = true
  stream_view_type               = "NEW_IMAGE"
  deletion_protection_enabled    = true
  additional_attributes = [
    { name = "batchId", type = "S" },
    { name = "parentPath", type = "S" }
  ]
  global_secondary_indexes = [
    {
      name            = local.files_table_batch_parent_global_secondary_index_name
      hash_key        = "batchId"
      range_key       = "parentPath"
      projection_type = "ALL"
    }
  ]
  point_in_time_recovery_enabled = local.enable_point_in_time_recovery
}

module "ingest_lock_table" {
  source                         = "git::https://github.com/nationalarchives/da-terraform-modules//dynamo"
  hash_key                       = { name = local.ingest_lock_table_hash_key, type = "S" }
  table_name                     = local.ingest_lock_dynamo_table_name
  server_side_encryption_enabled = false
  additional_attributes = [
    { name = "groupId", type = "S" }
  ]
  global_secondary_indexes = [
    {
      name            = local.ingest_lock_table_group_id_gsi_name
      hash_key        = "groupId"
      projection_type = "ALL"
    }
  ]
  point_in_time_recovery_enabled = local.enable_point_in_time_recovery
}

module "ingest_queue_table" {
  source                         = "git::https://github.com/nationalarchives/da-terraform-modules//dynamo"
  hash_key                       = { name = "sourceSystem", type = "S" }
  range_key                      = { name = "queuedAt", type = "S" }
  table_name                     = local.ingest_queue_dynamo_table_name
  server_side_encryption_enabled = true
  kms_key_arn                    = module.dr2_kms_key.kms_key_arn
  deletion_protection_enabled    = true
  point_in_time_recovery_enabled = local.enable_point_in_time_recovery
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
      module.dr2_ingest_parsed_court_document_event_handler_sqs.queue_cloudwatch_message_visible_alarm_arn,
      module.dr2_ingest_parsed_court_document_event_handler_sqs.dlq_cloudwatch_message_visible_alarm_arn,
      module.dr2_custodial_copy_queue.queue_cloudwatch_message_visible_alarm_arn,
      module.dr2_custodial_copy_queue.dlq_cloudwatch_message_visible_alarm_arn,
      module.dr2_custodial_copy_queue.recurring_notification_alarm_arns,
      module.dr2_custodial_copy_queue_creator_queue.queue_cloudwatch_message_visible_alarm_arn,
      module.dr2_custodial_copy_queue_creator_queue.dlq_cloudwatch_message_visible_alarm_arn,
      module.dr2_custodial_copy_db_builder_queue.queue_cloudwatch_message_visible_alarm_arn,
      module.dr2_custodial_copy_db_builder_queue.dlq_cloudwatch_message_visible_alarm_arn,
      module.dr2_custodial_copy_notifications_queue.queue_cloudwatch_message_visible_alarm_arn,
      module.dr2_custodial_copy_notifications_queue.dlq_cloudwatch_message_visible_alarm_arn,
      module.dr2_external_notifications_queue.queue_cloudwatch_message_visible_alarm_arn,
      module.dr2_external_notifications_queue.dlq_cloudwatch_message_visible_alarm_arn,
      module.dr2_copy_files_from_tdr_sqs.queue_cloudwatch_message_visible_alarm_arn,
      module.dr2_copy_files_from_tdr_sqs.dlq_cloudwatch_message_visible_alarm_arn
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
    step_function_arns = jsonencode([module.dr2_ingest_step_function.step_function_arn, module.dr2_preingest_tdr_step_function.step_function_arn])
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
  lambda_target_arn = "arn:aws:lambda:eu-west-2:${data.aws_caller_identity.current.account_id}:function:${local.ingest_failure_notifications_lambda_name}"
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

module "secret_rotation_eventbridge_rule" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//eventbridge_api_destination_rule"
  event_pattern = templatefile("${path.module}/templates/eventbridge/secrets_manager_rotation.json.tpl", {
    rotation_event = "RotationFailed"
  })
  name                = "${local.environment}-dr2-failed-secrets-manager-rotation"
  api_destination_arn = module.eventbridge_alarm_notifications_destination.api_destination_arn
  api_destination_input_transformer = {
    input_paths = {
      "secretId" : "$.detail.additionalEventData.SecretId"
    }
    input_template = templatefile("${path.module}/templates/eventbridge/slack_message_input_template.json.tpl", {
      channel_id   = local.dev_notifications_channel_id
      slackMessage = ":alert-noflash-slow: Secret rotation for secret `<secretId>` has failed"
    })
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
