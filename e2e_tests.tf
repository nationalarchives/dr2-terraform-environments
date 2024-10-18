locals {
  e2e_tests_name  = "${local.environment}-dr2-e2e-tests"
  e2e_tests_count = local.environment == "intg" ? 1 : 0
}

module "dr2_run_e2e_tests_role" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_role"
  count  = local.e2e_tests_count
  assume_role_policy = templatefile("${path.module}/templates/iam_role/github_assume_role.json.tpl", {
    account_id = data.aws_caller_identity.current.account_id,
    repo_filters = jsonencode([
      "repo:nationalarchives/dr2-ingest:environment:${local.environment}"
    ])
  })
  name = "${local.environment}-dr2-run-e2e-tests-role"
  policy_attachments = {
    run_e2e_tests_policy = module.dr2_e2e_tests_policy[count.index].policy_arn
  }
  tags = {}
}

module "dr2_e2e_tests_policy" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  count  = local.e2e_tests_count
  name   = "${local.e2e_tests_name}-policy"
  policy_string = templatefile("${path.module}/templates/iam_policy/e2e_tests_policy.json.tpl", {
    input_bucket_name         = local.ingest_raw_cache_bucket_name
    copy_files_from_tdr_queue = module.dr2_copy_files_from_tdr_sqs.sqs_arn
    copy_files_dlq            = module.dr2_copy_files_from_tdr_sqs.dlq_sqs_arn
    e2e_tests_queue           = module.dr2_e2e_tests_queue[count.index].sqs_arn
    preingest_sfn_arn         = module.dr2_preingest_tdr_step_function.step_function_arn,
    dynamo_db_lock_table_arn  = module.ingest_lock_table.table_arn
  })
}

module "dr2_e2e_tests_queue" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//sqs"
  count      = local.e2e_tests_count
  queue_name = local.e2e_tests_name
  sqs_policy = templatefile("./templates/sqs/sns_send_message_policy.json.tpl", {
    account_id = var.account_number,
    queue_name = local.e2e_tests_name
    topic_arn  = module.dr2_notifications_sns.sns_arn
  })
  visibility_timeout        = 10
  message_retention_seconds = 7200
  encryption_type           = "sse"
}