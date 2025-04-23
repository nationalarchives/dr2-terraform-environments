locals {
  reporting_helper_lambda_name = "${local.environment}-dr2-reporting-helper"
}

module "dr2_reporting_helper_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.reporting_helper_lambda_name
  handler         = "lambda_function.lambda_handler"
  timeout_seconds = local.python_timeout_seconds
  policies = {
    "${local.reporting_helper_lambda_name}-policy" = templatefile("./templates/iam_policy/reporting_helper_policy.json.tpl", {
      account_id  = data.aws_caller_identity.current.account_id
      lambda_name = local.reporting_helper_lambda_name
      bucket_name = local.reporting_bucket_name
    })
  }
  memory_size = local.python_lambda_memory_size
  runtime     = local.python_runtime

  tags = {
    Name = local.reporting_helper_lambda_name
  }
}


# module "dr2_copy_files_from_tdr_lambda" {
#   source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
#   function_name   = local.copy_files_from_tdr_name
#   handler         = "lambda_function.lambda_handler"
#   timeout_seconds = local.python_timeout_seconds
#   lambda_sqs_queue_mappings = [
#     { sqs_queue_arn = local.copy_files_from_tdr_queue_arn, ignore_enabled_status = true }
#   ]
#   policies = {
#     "${local.copy_files_from_tdr_name}-policy" = templatefile("./templates/iam_policy/copy_files_from_tdr_policy.json.tpl", {
#       copy_files_from_tdr_queue_arn = local.copy_files_from_tdr_queue_arn
#       raw_cache_bucket_name         = local.ingest_raw_cache_bucket_name
#       tdr_bucket_name               = local.tdr_bucket_name
#       aggregator_queue_arn          = local.tdr_aggregator_queue_arn
#       account_id                    = data.aws_caller_identity.current.account_id
#       lambda_name                   = local.copy_files_from_tdr_name
#       tdr_export_kms_arn            = module.tdr_config.terraform_config["${local.environment}_s3_export_bucket_kms_key_arn"]
#     })
#   }
#   memory_size = local.python_lambda_memory_size
#   runtime     = local.python_runtime
#   plaintext_env_vars = {
#     OUTPUT_BUCKET_NAME = local.ingest_raw_cache_bucket_name
#     OUTPUT_QUEUE_URL   = local.tdr_aggregator_queue_url
#   }
#   tags = {
#     Name = local.copy_files_from_tdr_name
#   }
# }