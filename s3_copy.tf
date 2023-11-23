locals {
  s3_copy_lambda_name = "${local.environment}-s3-copy"
}
module "s3_copy_lambda" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name = local.s3_copy_lambda_name
  handler       = "uk.gov.nationalarchives.Lambda::handleRequest"
  policies = {
    s3_copy_policy = templatefile("${path.module}/templates/iam_policy/s3_copy_policy.json.tpl", {
      account_id  = data.aws_caller_identity.current.account_id
      lambda_name = local.s3_copy_lambda_name
      environment = local.environment
      bucket_name = local.ingest_staging_cache_bucket_name
    })
  }
  timeout_seconds = 180
  runtime         = "java17"
  memory_size     = 512
  tags            = {}
  plaintext_env_vars = {
    ENVIRONMENT = local.environment
  }
}
