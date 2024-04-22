locals {
  ingest_parent_folder_opex_creator_lambda_name_old = "${local.environment}-ingest-parent-folder-opex-creator"
  ingest_parent_folder_opex_creator_lambda_name     = "${local.environment}-dr2-ingest-parent-folder-opex-creator"
}
module "ingest_parent_folder_opex_creator_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_parent_folder_opex_creator_lambda_name_old
  handler         = "uk.gov.nationalarchives.Lambda::handleRequest"
  timeout_seconds = 60
  policies = {
    "${local.ingest_parent_folder_opex_creator_lambda_name_old}-policy" = templatefile("./templates/iam_policy/ingest_parent_folder_opex_creator_policy.json.tpl", {
      bucket_name = local.ingest_staging_cache_bucket_name
      account_id  = var.account_number
      lambda_name = local.ingest_parent_folder_opex_creator_lambda_name_old
    })
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
  plaintext_env_vars = {
    STAGING_CACHE_BUCKET = local.ingest_staging_cache_bucket_name
  }
  tags = {
    Name = local.ingest_parent_folder_opex_creator_lambda_name_old
  }
}

module "dr2_ingest_parent_folder_opex_creator_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_parent_folder_opex_creator_lambda_name
  handler         = "uk.gov.nationalarchives.Lambda::handleRequest"
  timeout_seconds = local.java_timeout_seconds
  policies = {
    "${local.ingest_parent_folder_opex_creator_lambda_name}-policy" = templatefile("./templates/iam_policy/ingest_parent_folder_opex_creator_policy.json.tpl", {
      bucket_name = local.ingest_staging_cache_bucket_name
      account_id  = var.account_number
      lambda_name = local.ingest_parent_folder_opex_creator_lambda_name
    })
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
  plaintext_env_vars = {
    STAGING_CACHE_BUCKET = local.ingest_staging_cache_bucket_name
  }
  tags = {
    Name = local.ingest_parent_folder_opex_creator_lambda_name
  }
}
