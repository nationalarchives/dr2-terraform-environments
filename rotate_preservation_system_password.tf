locals {
  rotate_preservation_system_password_name = "${local.environment}-dr2-rotate-preservation-system-password"
}

module "dr2_rotate_preservation_system_password_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.rotate_preservation_system_password_name
  handler         = "uk.gov.nationalarchives.rotatepreservationsystempassword.Lambda::handleRequest"
  timeout_seconds = local.java_timeout_seconds
  policies = {
    "${local.rotate_preservation_system_password_name}-policy" = templatefile("./templates/iam_policy/rotate_preservation_system_password_policy.json.tpl", {
      secrets_manager_secret_arn = aws_secretsmanager_secret.preservica_secret.arn,
      account_id                 = data.aws_caller_identity.current.account_id
      lambda_name                = local.rotate_preservation_system_password_name
    })
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
  plaintext_env_vars = {
    PRESERVICA_API_URL = data.aws_ssm_parameter.preservica_url.value
  }
  lambda_invoke_permissions = {
    "secretsmanager.amazonaws.com" = aws_secretsmanager_secret.preservica_secret.arn
  }
  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.outbound_https_access_only.security_group_id]
  }
  tags = {
    Name = local.rotate_preservation_system_password_name
  }
}
