locals {
  ingest_asset_reconciler_lambda_name = "${local.environment}-ingest-asset-reconciler"
}
module "ingest_asset_reconciler_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_asset_reconciler_lambda_name
  handler         = "uk.gov.nationalarchives.Lambda::handleRequest"
  timeout_seconds = local.java_timeout_seconds
  policies = {
    "${local.ingest_asset_reconciler_lambda_name}-policy" = templatefile("./templates/iam_policy/ingest_asset_reconciler_policy.json.tpl", {
      account_id                 = var.account_number
      lambda_name                = local.ingest_asset_reconciler_lambda_name
      dynamo_db_arn              = module.files_table.table_arn
      gsi_name                   = local.files_table_global_secondary_index_name
      secrets_manager_secret_arn = aws_secretsmanager_secret.preservica_secret.arn
    })
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
  plaintext_env_vars = {
    PRESERVICA_SECRET_NAME = aws_secretsmanager_secret.preservica_secret.name
    PRESERVICA_API_URL     = data.aws_ssm_parameter.preservica_url.value
    DYNAMO_TABLE_NAME      = local.files_dynamo_table_name
    DYNAMO_GSI_NAME        = local.files_table_global_secondary_index_name
  }
  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.outbound_https_access_only.security_group_id]
  }
  tags = {
    Name = local.ingest_asset_reconciler_lambda_name
  }
}
