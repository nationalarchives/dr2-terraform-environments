locals {
  disaster_recovery_bucket_name           = "${local.environment}-dr2-disaster-recovery"
  download_files_and_metadata_lambda_name = "${local.environment}-download-files-and-metadata"
  download_metadata_and_files_queue_name  = "${local.environment}-download-files-and-metadata"
}

module "download_metadata_and_files_lambda" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name = local.download_files_and_metadata_lambda_name
  handler       = "uk.gov.nationalarchives.Lambda::handleRequest"
  lambda_sqs_queue_mappings = [{
    sqs_queue_arn = module.download_files_sqs.sqs_arn
  }]
  policies = {
    "${local.download_files_and_metadata_lambda_name}-policy" = templatefile("./templates/iam_policy/download_files_metadata_policy.json.tpl", {
      secrets_manager_secret_arn   = "arn:aws:secretsmanager:eu-west-2:${var.account_number}:secret:sandbox-preservica-6-preservicav6login-INFTcQ",
      download_files_sqs_queue_arn = module.download_files_sqs.sqs_arn
      disaster_recovery_bucket     = module.disaster_recovery_bucket
      bucket_name                  = local.disaster_recovery_bucket_name
      account_id                   = var.account_number
      lambda_name                  = local.download_files_and_metadata_lambda_name
    })
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
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
    Name      = local.download_files_and_metadata_lambda_name
    CreatedBy = "dr2-terraform-environments"
  }
}

module "download_files_sqs" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//sqs"
  queue_name = local.download_metadata_and_files_queue_name
  sqs_policy = templatefile("./templates/sqs/sqs_access_policy.json.tpl", {
    account_id = var.account_number, //TODO Restrict this to the SNS topic ARN when it's created
    queue_name = local.download_metadata_and_files_queue_name
  })
  redrive_maximum_receives = 3
  tags = {
    CreatedBy = "dr2-terraform-environments"
  }
  kms_key_id = module.dr2_kms_key.kms_key_arn
}

