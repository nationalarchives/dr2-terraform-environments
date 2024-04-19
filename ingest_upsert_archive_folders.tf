locals {
  ingest_upsert_archive_folders_lambda_name = "${local.environment}-ingest-upsert-archive-folders"
}
module "ingest_upsert_archive_folders_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_upsert_archive_folders_lambda_name
  handler         = "uk.gov.nationalarchives.Lambda::handleRequest"
  timeout_seconds = local.java_timeout_seconds
  policies = {
    "${local.ingest_upsert_archive_folders_lambda_name}-policy" = templatefile("./templates/iam_policy/ingest_upsert_archive_folders_policy.json.tpl", {
      account_id                 = var.account_number
      lambda_name                = local.ingest_upsert_archive_folders_lambda_name
      dynamo_db_arn              = module.files_table.table_arn
      secrets_manager_secret_arn = aws_secretsmanager_secret.preservica_secret.arn
    })
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
  plaintext_env_vars = {
    ARCHIVE_FOLDER_TABLE_NAME = local.files_dynamo_table_name
    PRESERVICA_SECRET_NAME    = aws_secretsmanager_secret.preservica_secret.name
    PRESERVICA_API_URL        = data.aws_ssm_parameter.preservica_url.value
  }
  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.outbound_https_access_only.security_group_id]
  }
  reserved_concurrency = 1
  tags = {
    Name      = local.ingest_upsert_archive_folders_lambda_name
    CreatedBy = "dr2-terraform-environments"
  }
}
