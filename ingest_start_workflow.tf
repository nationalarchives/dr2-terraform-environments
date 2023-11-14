locals {
  ingest_start_workflow_lambda_name = "${local.environment}-ingest-start-workflow"
  s3_copy_lambda_name               = "${local.environment}-temp-s3-copy"
}
module "ingest_start_workflow_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_start_workflow_lambda_name
  handler         = "uk.gov.nationalarchives.Lambda::handleRequest"
  timeout_seconds = 60
  policies = {
    "${local.ingest_start_workflow_lambda_name}-policy" = templatefile("./templates/iam_policy/ingest_start_workflow_policy.json.tpl", {
      account_id                 = var.account_number
      lambda_name                = local.ingest_start_workflow_lambda_name
      secrets_manager_secret_arn = aws_secretsmanager_secret.preservica_secret.arn
    })
  }
  memory_size = 512
  runtime     = "java17"
  plaintext_env_vars = {
    PRESERVICA_SECRET_NAME = aws_secretsmanager_secret.preservica_secret.name
    PRESERVICA_API_URL     = data.aws_ssm_parameter.preservica_url.value
  }
  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.outbound_https_access_only.security_group_id]
  }
  tags = {
    Name      = local.ingest_start_workflow_lambda_name
    CreatedBy = "dp-terraform-environments"
  }
}
