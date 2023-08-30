locals {
  ingest_asset_opex_creator_lambda_name = "${local.environment}-ingest-mapper-opex-creator"
}
module "ingest_asset_opex_creator_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_asset_opex_creator_lambda_name
  handler         = "uk.gov.nationalarchives.Lambda::handleRequest"
  timeout_seconds = 60
  policies = {
    "${local.ingest_asset_opex_creator_lambda_name}-policy" = templatefile("./templates/iam_policy/ingest_asset_opex_creator_policy.json.tpl", {
      source_bucket_name      = local.ingest_raw_cache_bucket_name
      destination_bucket_name = local.ingest_staging_cache_bucket_name
      account_id              = var.account_number
      lambda_name             = local.ingest_asset_opex_creator_lambda_name
      dynamo_db_arn           = module.files_table.table_arn
      gsi_name                = local.files_table_global_secondary_index_name

    })
  }
  memory_size = 512
  runtime     = "java17"
  plaintext_env_vars = {
    DYNAMO_TABLE_NAME  = local.files_dynamo_table_name
    DYNAMO_GSI_NAME    = local.files_table_global_secondary_index_name
    SOURCE_BUCKET      = local.ingest_raw_cache_bucket_name
    DESTINATION_BUCKET = local.ingest_staging_cache_bucket_name
  }
  tags = {
    Name      = local.ingest_asset_opex_creator_lambda_name
    CreatedBy = "dp-terraform-environments"
  }
}
