locals {
  files_change_handler_name = "${local.environment}-dr2-ingest-files-change-handler"
}
module "dr2_ingest_files_change_handler_lambda" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name = local.files_change_handler_name
  handler       = "uk.gov.nationalarchives.ingestfileschangehandler.Lambda::handleRequest"
  policies = {
    dr2_ingest_files_change_handler_policy = templatefile("${path.module}/templates/iam_policy/file_change_handler_policy.json.tpl", {
      dynamo_db_file_table_stream_arn = module.files_table.stream_arn
      account_id                      = data.aws_caller_identity.current.account_id
      lambda_name                     = local.files_change_handler_name
      dynamo_db_file_table_arn        = module.files_table.table_arn
      gsi_name                        = local.files_table_batch_parent_global_secondary_index_name
      sns_arn                         = module.dr2_notifications_sns.sns_arn
    })
  }
  timeout_seconds = 180
  memory_size     = local.java_lambda_memory_size
  runtime         = local.java_runtime
  tags            = {}
  plaintext_env_vars = {
    DYNAMO_TABLE_NAME = local.files_dynamo_table_name
    DYNAMO_GSI_NAME   = local.files_table_batch_parent_global_secondary_index_name
    TOPIC_ARN         = module.dr2_notifications_sns.sns_arn
  }
  dynamo_stream_config = {
    stream_arn = module.files_table.stream_arn
  }
}
