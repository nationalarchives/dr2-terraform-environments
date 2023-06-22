locals {
  notifications_lambda_name                   = "${local.environment}-slack-notifications"
}

module "slack_notifications_lambda" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name = local.notifications_lambda_name
  handler       = "lambda_function.lambda_handler"

  policies = {
    "${local.notifications_lambda_name}-policy" = templatefile("./templates/iam_policy/slack_notifications_policy.json.tpl", {
      secrets_manager_secret_arn   = "arn:aws:secretsmanager:eu-west-2:${var.dp_account_number}:secret:slack_webhook_url-xrHr13",
      account_id                   = var.dp_account_number
      lambda_name                  = local.notifications_lambda_name
    })
  }
  runtime     = "python3.10"
  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.outbound_https_access_only.security_group_id]
  }
  plaintext_env_vars = {
    WEBHOOK_SECRET_NAME = aws_secretsmanager_secret.slack_webhook_url.name
  }
  tags = {
    Name      = local.notifications_lambda_name
    CreatedBy = "dp-terraform-environments"
  }
}
