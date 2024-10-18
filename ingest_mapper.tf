locals {
  ingest_mapper_lambda_name = "${local.environment}-dr2-ingest-mapper"
}

module "dr2_ingest_mapper_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_mapper_lambda_name
  handler         = "uk.gov.nationalarchives.ingestmapper.Lambda::handleRequest"
  timeout_seconds = local.java_timeout_seconds
  policies = {
    "${local.ingest_mapper_lambda_name}-policy" = templatefile("./templates/iam_policy/ingest_mapper_policy.json.tpl", {
      raw_cache_bucket_name    = local.ingest_raw_cache_bucket_name
      ingest_state_bucket_name = local.ingest_state_bucket_name
      account_id               = var.account_number
      lambda_name              = local.ingest_mapper_lambda_name
      dynamo_db_file_table_arn = module.files_table.table_arn
    })
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
  plaintext_env_vars = {
    DYNAMO_TABLE_NAME   = local.files_dynamo_table_name  # Remove in DR2-1626/2
    INGEST_STATE_BUCKET = local.ingest_state_bucket_name # Remove in DR2-1626/2
    FILES_DDB_TABLE     = local.files_dynamo_table_name
    OUTPUT_BUCKET_NAME  = local.ingest_state_bucket_name
  }
  tags = {
    Name = local.ingest_mapper_lambda_name
  }
}
