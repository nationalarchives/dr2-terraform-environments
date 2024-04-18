locals {
  ip_lock_checker_lambda_name_old = "${local.environment}-ip-lock-checker"
  ip_lock_checker_lambda_name     = "${local.environment}-dr2-ip-lock-checker"
}

module "dr2_ip_lock_checker_cloudwatch_event" {
  source                  = "git::https://github.com/nationalarchives/da-terraform-modules//cloudwatch_events"
  rule_name               = "${local.environment}-dr2-ip-lock-checker-schedule"
  schedule                = "rate(1 hour)"
  lambda_event_target_arn = "arn:aws:lambda:eu-west-2:${data.aws_caller_identity.current.account_id}:function:${local.ip_lock_checker_lambda_name}"
}

module "ip_lock_checker_cloudwatch_event" {
  source                  = "git::https://github.com/nationalarchives/da-terraform-modules//cloudwatch_events"
  rule_name               = "${local.environment}-ip-lock-checker-schedule"
  schedule                = "rate(1 hour)"
  lambda_event_target_arn = "arn:aws:lambda:eu-west-2:${data.aws_caller_identity.current.account_id}:function:${local.ip_lock_checker_lambda_name_old}"
}

module "ip_lock_checker_lambda" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name = local.ip_lock_checker_lambda_name_old

  handler         = "lambda_function.lambda_handler"
  timeout_seconds = 30
  policies = {
    "${local.ip_lock_checker_lambda_name_old}-policy" = templatefile("./templates/iam_policy/ip_lock_checker_policy.json.tpl", {
      account_id  = var.account_number
      lambda_name = local.ip_lock_checker_lambda_name_old
    })
  }
  lambda_invoke_permissions = {
    "events.amazonaws.com" = module.ip_lock_checker_cloudwatch_event.event_arn
  }
  memory_size = local.python_lambda_memory_size
  runtime     = local.python_runtime
  plaintext_env_vars = {
    PRESERVICA_URL = data.aws_ssm_parameter.preservica_url.value
  }
  tags = {}
}

module "dr2_ip_lock_checker_lambda" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name = local.ip_lock_checker_lambda_name

  handler         = "lambda_function.lambda_handler"
  timeout_seconds = 30
  policies = {
    "${local.ip_lock_checker_lambda_name}-policy" = templatefile("./templates/iam_policy/ip_lock_checker_policy.json.tpl", {
      account_id  = var.account_number
      lambda_name = local.ip_lock_checker_lambda_name
    })
  }
  lambda_invoke_permissions = {
    "events.amazonaws.com" = module.ip_lock_checker_cloudwatch_event.event_arn
  }
  memory_size = local.python_lambda_memory_size
  runtime     = local.python_runtime
  plaintext_env_vars = {
    PRESERVICA_URL = data.aws_ssm_parameter.preservica_url.value
  }
  tags = {}
}
