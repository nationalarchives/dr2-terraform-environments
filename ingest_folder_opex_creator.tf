locals {
  ingest_folder_opex_creator_lambda_name_old = "${local.environment}-ingest-folder-opex-creator"
  ingest_folder_opex_creator_lambda_name     = "${local.environment}-dr2-ingest-folder-opex-creator"
}
module "ingest_folder_opex_creator_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_folder_opex_creator_lambda_name_old
  handler         = "uk.gov.nationalarchives.Lambda::handleRequest"
  timeout_seconds = 60
  policies = {
    "${local.ingest_folder_opex_creator_lambda_name_old}-policy" = templatefile("./templates/iam_policy/ingest_folder_opex_creator_policy.json.tpl", {
      bucket_name   = local.ingest_staging_cache_bucket_name
      account_id    = var.account_number
      lambda_name   = local.ingest_folder_opex_creator_lambda_name_old
      dynamo_db_arn = module.files_table.table_arn
      gsi_name      = local.files_table_global_secondary_index_name

    })
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
  plaintext_env_vars = {
    DYNAMO_TABLE_NAME = local.files_dynamo_table_name
    DYNAMO_GSI_NAME   = local.files_table_global_secondary_index_name
    BUCKET_NAME       = local.ingest_staging_cache_bucket_name
  }
  tags = {
    Name      = local.ingest_folder_opex_creator_lambda_name_old
    CreatedBy = "dp-terraform-environments"
  }
}

module "dr2_ingest_folder_opex_creator_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_folder_opex_creator_lambda_name
  handler         = "uk.gov.nationalarchives.Lambda::handleRequest"
  timeout_seconds = local.java_timeout_seconds
  policies = {
    "${local.ingest_folder_opex_creator_lambda_name}-policy" = templatefile("./templates/iam_policy/ingest_folder_opex_creator_policy.json.tpl", {
      bucket_name   = local.ingest_staging_cache_bucket_name
      account_id    = var.account_number
      lambda_name   = local.ingest_folder_opex_creator_lambda_name
      dynamo_db_arn = module.files_table.table_arn
      gsi_name      = local.files_table_global_secondary_index_name

    })
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
  plaintext_env_vars = {
    DYNAMO_TABLE_NAME = local.files_dynamo_table_name
    DYNAMO_GSI_NAME   = local.files_table_global_secondary_index_name
    BUCKET_NAME       = local.ingest_staging_cache_bucket_name
  }
  tags = {
    Name      = local.ingest_folder_opex_creator_lambda_name
    CreatedBy = "dp-terraform-environments"
  }
}