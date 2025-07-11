locals {
  ingest_start_workflow_lambda_name = "${local.environment}-dr2-ingest-start-workflow"
}

module "dr2_ingest_start_workflow_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_start_workflow_lambda_name
  handler         = "uk.gov.nationalarchives.ingeststartworkflow.Lambda::handleRequest"
  timeout_seconds = local.java_timeout_seconds
  policies = {
    "${local.ingest_start_workflow_lambda_name}-policy" = templatefile("./templates/iam_policy/ingest_start_workflow_policy.json.tpl", {
      account_id                 = data.aws_caller_identity.current.account_id
      lambda_name                = local.ingest_start_workflow_lambda_name
      secrets_manager_secret_arn = aws_secretsmanager_secret.preservica_secret.arn
    })
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
  plaintext_env_vars = {
    PRESERVICA_SECRET_NAME = aws_secretsmanager_secret.preservica_secret.name
  }
  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.outbound_https_access_only.security_group_id]
  }
  tags = {
    Name = local.ingest_start_workflow_lambda_name
  }
}
