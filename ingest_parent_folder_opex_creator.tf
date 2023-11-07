locals {
  ingest_parent_folder_opex_creator_lambda_name = "${local.environment}-ingest-parent-folder-opex-creator"
}
module "ingest_parent_folder_opex_creator_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_parent_folder_opex_creator_lambda_name
  handler         = "uk.gov.nationalarchives.Lambda::handleRequest"
  timeout_seconds = 60
  policies = {
    "${local.ingest_parent_folder_opex_creator_lambda_name}-policy" = templatefile("./templates/iam_policy/ingest_parent_folder_opex_creator_policy.json.tpl", {
      bucket_name = local.ingest_staging_cache_bucket_name
      account_id  = var.account_number
      lambda_name = local.ingest_parent_folder_opex_creator_lambda_name
    })
  }
  memory_size = 512
  runtime     = "java17"
  plaintext_env_vars = {
    STAGING_CACHE_BUCKET = local.ingest_staging_cache_bucket_name
  }
  tags = {
    Name      = local.ingest_parent_folder_opex_creator_lambda_name
    CreatedBy = "dp-terraform-environments"
  }
}
