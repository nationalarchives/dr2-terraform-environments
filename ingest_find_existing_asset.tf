locals {
  ingest_find_existing_asset_name = "${local.environment}-dr2-ingest-find-existing-asset"
}

module "ingest_find_existing_asset" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_find_existing_asset_name
  handler         = "uk.gov.nationalarchives.ingestfindexistingasset.Lambda::handleRequest"
  timeout_seconds = 60
  policies = {
    "${local.ingest_find_existing_asset_name}-policy" = templatefile(
      "${path.module}/templates/iam_policy/ingest_find_existing_asset_policy.json.tpl", {
        account_id                 = var.account_number
        lambda_name                = local.ingest_find_existing_asset_name
        dynamo_db_file_table_arn   = module.files_table.table_arn
        secrets_manager_secret_arn = aws_secretsmanager_secret.preservica_secret.arn
      }
    )
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
  plaintext_env_vars = {
    PRESERVICA_SECRET_NAME = aws_secretsmanager_secret.preservica_secret.name
    PRESERVICA_API_URL     = data.aws_ssm_parameter.preservica_url.value
    DYNAMO_TABLE_NAME      = local.files_dynamo_table_name
  }
  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.outbound_https_access_only.security_group_id]
  }
  tags = {
    Name = local.ingest_find_existing_asset_name
  }
}
