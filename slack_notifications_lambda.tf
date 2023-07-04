locals {
  notifications_lambda_name = "${local.environment}-slack-notifications"
}

module "slack_notifications_lambda" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name = local.notifications_lambda_name
  handler       = "lambda_function.lambda_handler"
  lambda_sqs_queue_mappings = {
    dlq_notification_queue = module.dlq_notifications_queue.sqs_arn
  }
  policies = {
    "${local.notifications_lambda_name}-policy" = templatefile("./templates/iam_policy/slack_notifications_policy.json.tpl", {
      ssm_parameter_arn = data.aws_ssm_parameter.slack_webhook_url.arn,
      account_id        = var.dp_account_number
      lambda_name       = local.notifications_lambda_name
    })
  }
  runtime = "python3.10"
  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.outbound_https_access_only.security_group_id]
  }
  plaintext_env_vars = {
    WEBHOOK_PARAMETER_NAME = data.aws_ssm_parameter.slack_webhook_url.name
  }
  tags = {
    Name      = local.notifications_lambda_name
    CreatedBy = "dp-terraform-environments"
  }
}
