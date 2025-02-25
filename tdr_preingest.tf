locals {
  tdr_preingest_name              = "${local.environment}-dr2-preingest-tdr"
  tdr_aggregator_name             = "${local.tdr_preingest_name}-aggregator"
  tdr_aggregator_queue_arn        = "arn:aws:sqs:eu-west-2:${data.aws_caller_identity.current.account_id}:${local.tdr_aggregator_name}"
  tdr_aggregator_queue_url        = "https://sqs.eu-west-2.amazonaws.com/${data.aws_caller_identity.current.account_id}/${local.tdr_aggregator_name}"
  tdr_package_builder_lambda_name = "${local.tdr_preingest_name}-package-builder"
  preingest_sfn_arn               = "arn:aws:states:eu-west-2:${data.aws_caller_identity.current.account_id}:stateMachine:${local.tdr_preingest_name}"
  ingest_sfn_arn                  = "arn:aws:states:eu-west-2:${data.aws_caller_identity.current.account_id}:stateMachine:${local.ingest_step_function_name}"

  # Min time before starting ingest: tdr_aggregator_lambda_timeout_seconds + tdr_aggregator_secondary_grouping_window_seconds
  # Max time before starting ingest: tdr_aggregator_primary_grouping_window_seconds + tdr_aggregator_lambda_timeout_seconds + tdr_aggregator_secondary_grouping_window_seconds
  # (assumes that the Lambda doesn't fail)
  tdr_aggregator_primary_grouping_window_seconds   = 300                                                                                                # How long the SQS Poller waits before invoking the Lambda after receiving the first message. <=300 for Lambda.
  tdr_aggregator_lambda_timeout_seconds            = 60                                                                                                 # <=900 for Lambda.
  tdr_aggregator_secondary_grouping_window_seconds = 180                                                                                                # Additional time we wait before starting preingest to allow multiple invocations to form a single group, this is added to the tdr_aggregator_lambda_timeout_seconds when we start a group.
  tdr_aggregator_invocation_batch_size             = 10000                                                                                              # Max number of messages to invoke the Lambda with, but all messages need to be processed before the Lambda times out. <=10000 for Lambda.
  tdr_aggregator_group_size                        = 10000                                                                                              # Max size of an aggregation group.
  tdr_aggregator_queue_visibility_timeout          = local.tdr_aggregator_primary_grouping_window_seconds + local.tdr_aggregator_lambda_timeout_seconds # <=43200 for SQS.
}

module "dr2_preingest_tdr_aggregator_queue" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//sqs"
  queue_name = local.tdr_aggregator_name
  sqs_policy = templatefile("./templates/sqs/sns_send_message_policy.json.tpl", {
    account_id = data.aws_caller_identity.current.account_id,
    queue_name = local.tdr_aggregator_name
    topic_arn  = "arn:aws:sns:eu-west-2:${module.tdr_config.account_numbers[local.environment]}:tdr-external-notifications-${local.environment}"
  })
  visibility_timeout = local.tdr_aggregator_queue_visibility_timeout
  encryption_type    = "sse"
}

module "dr2_preingest_tdr_aggregator_lambda" {
  source                         = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name                  = local.tdr_aggregator_name
  handler                        = "uk.gov.nationalarchives.preingesttdraggregator.Lambda::handleRequest"
  sqs_queue_batching_window      = local.tdr_aggregator_primary_grouping_window_seconds
  sqs_queue_mapping_batch_size   = local.tdr_aggregator_invocation_batch_size
  sqs_report_batch_item_failures = true
  lambda_sqs_queue_mappings = [{
    sqs_queue_arn         = local.tdr_aggregator_queue_arn
    sqs_queue_concurrency = 2
    ignore_enabled_status = true
  }]
  timeout_seconds = local.tdr_aggregator_lambda_timeout_seconds
  policies = {
    "${local.tdr_aggregator_name}-policy" = templatefile("./templates/iam_policy/preingest_tdr_aggregator_policy.json.tpl", {
      account_id                 = data.aws_caller_identity.current.account_id
      lambda_name                = local.tdr_aggregator_name
      dynamo_db_lock_table_arn   = module.ingest_lock_table.table_arn
      preingest_sfn_arn          = local.preingest_sfn_arn
      preingest_aggregator_queue = local.tdr_aggregator_queue_arn
    })
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
  plaintext_env_vars = {
    LOCK_DDB_TABLE                = local.ingest_lock_dynamo_table_name
    MAX_BATCH_SIZE                = local.tdr_aggregator_group_size
    MAX_SECONDARY_BATCHING_WINDOW = local.tdr_aggregator_secondary_grouping_window_seconds
    PREINGEST_SFN_ARN             = local.preingest_sfn_arn
    SOURCE_SYSTEM                 = "TDR"
  }
  tags = {
    Name = local.tdr_aggregator_name
  }
}

module "dr2_preingest_tdr_step_function" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//sfn"
  step_function_definition = templatefile("${path.module}/templates/sfn/preingest_tdr_sfn_definition.json.tpl", {
    ingest_step_function_arn    = local.ingest_sfn_arn
    account_id                  = data.aws_caller_identity.current.account_id
    package_builder_lambda_name = local.tdr_package_builder_lambda_name
  })
  step_function_name = local.tdr_preingest_name
  step_function_role_policy_attachments = {
    tdr_preingest_step_function_policy = module.dr2_preingest_tdr_step_function_policy.policy_arn
  }
}

module "dr2_preingest_tdr_step_function_policy" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name   = "${local.tdr_preingest_name}-step-function-policy"
  policy_string = templatefile("${path.module}/templates/iam_policy/preingest_tdr_step_function_policy.json.tpl", {
    ingest_step_function_arn    = local.ingest_sfn_arn
    account_id                  = data.aws_caller_identity.current.account_id
    package_builder_lambda_name = local.tdr_package_builder_lambda_name
  })
}

module "dr2_preingest_tdr_package_builder_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.tdr_package_builder_lambda_name
  handler         = "uk.gov.nationalarchives.preingesttdrpackagebuilder.Lambda::handleRequest"
  timeout_seconds = local.java_timeout_seconds
  policies = {
    "${local.tdr_package_builder_lambda_name}-policy" = templatefile("./templates/iam_policy/preingest_tdr_package_builder_policy.json.tpl", {
      account_id               = data.aws_caller_identity.current.account_id
      lambda_name              = local.tdr_package_builder_lambda_name
      dynamo_db_lock_table_arn = module.ingest_lock_table.table_arn
      gsi_name                 = local.ingest_lock_table_group_id_gsi_name
      raw_cache_bucket_name    = local.ingest_raw_cache_bucket_name
    })
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
  plaintext_env_vars = {
    LOCK_DDB_TABLE                  = local.ingest_lock_dynamo_table_name
    LOCK_DDB_TABLE_GROUPID_GSI_NAME = local.ingest_lock_table_group_id_gsi_name
    OUTPUT_BUCKET_NAME              = local.ingest_raw_cache_bucket_name
  }
  tags = {
    Name = local.tdr_package_builder_lambda_name
  }
}
