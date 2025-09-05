terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.81.0"
    }
  }
}
locals {
  ingest_metric_collector_lambda_name = "${local.environment}-dr2-ingest-metric-collector"
  invocation_event_rule_name          = "${local.environment}-dr2-metric-collector-invocation-rule"
}

module "dr2_ingest_metric_collector_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  description     = "A lambda function to collect ingest metrics "
  function_name   = local.ingest_metric_collector_lambda_name
  handler         = "lambda_function.lambda_handler"
  timeout_seconds = local.python_timeout_seconds
  runtime         = local.python_runtime
  policies = {
    "${local.ingest_metric_collector_lambda_name}-policy" = templatefile("./templates/iam_policy/ingest_metric_collection_lambda_policy.json.tpl", {
      account_id                 = data.aws_caller_identity.current.account_id
      lambda_name                = local.ingest_metric_collector_lambda_name
      workflow_step_function_arn = module.dr2_ingest_run_workflow_step_function.step_function_arn
    })
  }
  tags = {
    Name = local.ingest_metric_collector_lambda_name
  }
}

resource "aws_cloudwatch_event_rule" "every_minute" {
  name                = local.invocation_event_rule_name
  description         = "triggers the lambda every minute"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "lambda_trigger" {
  rule      = aws_cloudwatch_event_rule.every_minute.name
  target_id = "dr2_ingest_metric_collector_lambda"
  arn       = module.dr2_ingest_metric_collector_lambda.lambda_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = local.ingest_metric_collector_lambda_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_minute.arn
}