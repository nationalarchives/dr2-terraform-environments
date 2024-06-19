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
      bucket_name              = local.ingest_raw_cache_bucket_name
      account_id               = var.account_number
      lambda_name              = local.ingest_mapper_lambda_name
      dynamo_db_file_table_arn = module.files_table.table_arn
    })
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
  plaintext_env_vars = {
    DYNAMO_TABLE_NAME = local.files_dynamo_table_name
  }
  tags = {
    Name = local.ingest_mapper_lambda_name
  }
}
