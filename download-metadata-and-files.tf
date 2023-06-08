locals {
  disaster_recovery_bucket_name = "${local.environment}-disaster-recovery"
  lambda_name                   = "${local.environment}-download-files-metadata"
  queue_name                    = "${local.environment}-download-files-metadata"
}

module "download_metadata_and_files_lambda" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//lambda?ref=add-nat-instance-and-vpc-policy"
  function_name = local.lambda_name
  handler       = "uk.gov.nationalarchives.Lambda::handleRequest"
  policies = {
    "${local.lambda_name}-policy" = templatefile("./templates/iam_policy/download_files_metadata_policy.json.tpl", {
      secrets_manager_secret_arn   = "arn:aws:secretsmanager:eu-west-2:${var.dp_account_number}:secret:sandbox-preservica-6-preservicav6login-INFTcQ",
      download_files_sqs_queue_arn = module.download_files_sqs.sqs_arn
      disaster_recovery_bucket     = module.disaster_recovery_bucket
      bucket_name                  = local.disaster_recovery_bucket_name
      account_id                   = var.dp_account_number
      lambda_name                  = local.lambda_name
    })
  }
  memory_size = 512
  runtime     = "java17"
  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.outbound_https_access_only.security_group_id]
  }
  plaintext_env_vars = {
    DR_BUCKET_NAME  = local.disaster_recovery_bucket_name
    API_SECRET_NAME = aws_secretsmanager_secret.preservica_secret.name
    PRESERVICA_URL  = data.aws_ssm_parameter.preservica_url.value
  }
  tags = {
    Name      = local.lambda_name
    CreatedBy = "dp-terraform-environments"
  }
}

module "download_files_sqs" {
  source                   = "git::https://github.com/nationalarchives/da-terraform-modules//sqs"
  queue_name               = local.queue_name
  sqs_policy               = templatefile("./templates/sqs/sqs_access_policy.json.tpl", { role_arn = module.download_metadata_and_files_lambda.lambda_role_arn, account_id = var.dp_account_number, queue_name = local.queue_name })
  redrive_maximum_receives = 3
  tags = {
    CreatedBy = "dp-terraform-environments"
  }
}

module "disaster_recovery_bucket" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//s3"
  bucket_name = local.disaster_recovery_bucket_name
  common_tags = {
    CreatedBy = "dp-terraform-environments"
  }
  logging_bucket_policy = templatefile("./templates/s3/log_bucket_policy.json.tpl", { bucket_name = "${local.disaster_recovery_bucket_name}-logs", account_id = var.dp_account_number })
  bucket_policy         = templatefile("./templates/s3/disaster_recovery_bucket_policy.json.tpl", { download_files_metadata_lambda_role_arn = module.download_metadata_and_files_lambda.lambda_role_arn, bucket_name = local.disaster_recovery_bucket_name })
}
