locals {
  ingest_metric_collector_lambda_name = "${local.environment}-dr2-ingest-metric-collector"
}

module "dr2_ingest_metric_collector_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  description     = "A lambda function to collect ingest metrics "
  function_name   = local.ingest_metric_collector_lambda_name
  handler         = "lambda_function.lambda_handler"
  timeout_seconds = local.python_timeout_seconds
  runtime = local.python_runtime
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