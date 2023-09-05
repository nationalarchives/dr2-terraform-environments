locals {
  ingest_upsert_archives_folder_lambda_name = "${local.environment}-ingest-upsert-archives-folder"
}
module "ingest_upsert_archives_folder_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_upsert_archives_folder_lambda_name
  handler         = "uk.gov.nationalarchives.Lambda::handleRequest"
  timeout_seconds = 60
  policies = {
    "${local.ingest_upsert_archives_folder_lambda_name}-policy" = templatefile("./templates/iam_policy/ingest_upsert_archives_folder_policy.json.tpl", {
      account_id              = var.account_number
      lambda_name             = local.ingest_upsert_archives_folder_lambda_name
      dynamo_db_arn           = module.files_table.table_arn
    })
  }
  memory_size = 512
  runtime     = "java17"
  plaintext_env_vars = {
    ARCHIVE_FOLDER_TABLE_NAME  = local.files_dynamo_table_name
    PRESERVICA_SECRET_NAME    = aws_secretsmanager_secret.preservica_secret.name
    PRESERVICA_API_URL = data.aws_ssm_parameter.preservica_url.value
  }
  tags = {
    Name      = local.ingest_upsert_archives_folder_lambda_name
    CreatedBy = "dr2-terraform-environments"
  }
}
