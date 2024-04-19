locals {
  preservica_config_bucket_name = "${local.environment}-dr2-preservica-config"
  preservica_config_lambda_name = "${local.environment}-preservica-config"
}
module "preservica_config_bucket" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//s3"
  bucket_name = local.preservica_config_bucket_name
  sns_topic_config = {
    "s3:ObjectCreated:*" = module.preservica_config_sns.sns_arn
  }
  bucket_policy = templatefile("${path.module}/templates/s3/preservica_config_bucket_policy.json.tpl", {
    preservica_config_lambda_role_arn = module.preservica_config_lambda.lambda_role_arn
    bucket_name                       = local.preservica_config_bucket_name
  })
}

module "preservica_config_sns" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//sns"
  sns_policy = templatefile("${path.module}/templates/sns/s3_notifications_policy.json.tpl", {
    topic_name  = "${local.environment}-preservica-config"
    bucket_name = "${local.environment}-dr2-preservica-config"
    account_id  = data.aws_caller_identity.current.account_id
  })
  tags = {
    Name = "Preservica Config SNS"
  }
  topic_name  = "${local.environment}-preservica-config"
  kms_key_arn = module.dr2_developer_key.kms_key_arn
  sqs_subscriptions = {
    preservica_config_queue = module.preservica_config_queue.sqs_arn
  }
}

module "preservica_config_queue" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//sqs"
  queue_name = "${local.environment}-preservica-config"
  sqs_policy = templatefile("${path.module}/templates/sqs/sns_send_message_policy.json.tpl", {
    account_id = data.aws_caller_identity.current.account_id, queue_name = "${local.environment}-preservica-config"
    queue_name = "${local.environment}-preservica-config"
    topic_arn  = module.preservica_config_sns.sns_arn
  })
  kms_key_id         = module.dr2_developer_key.kms_key_arn
  visibility_timeout = 360
}

module "preservica_config_lambda" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name = local.preservica_config_lambda_name
  handler       = "uk.gov.nationalarchives.dp.Lambda::handleRequest"
  lambda_sqs_queue_mappings = [{
    sqs_queue_arn = module.preservica_config_queue.sqs_arn
  }]
  timeout_seconds       = 60
  log_group_kms_key_arn = module.dr2_developer_key.kms_key_arn
  policies = {
    "${local.preservica_config_lambda_name}-policy" = templatefile("./templates/iam_policy/preservica_config_policy.json.tpl", {
      secrets_manager_secret_arn = aws_secretsmanager_secret.preservica_secret.arn
      preservica_config_queue    = module.preservica_config_queue.sqs_arn
      bucket_name                = local.preservica_config_bucket_name
      account_id                 = var.account_number
      lambda_name                = local.preservica_config_lambda_name
    })
  }
  memory_size = local.java_lambda_memory_size
  runtime     = local.java_runtime
  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.outbound_https_access_only.security_group_id]
  }
  plaintext_env_vars = {
    PRESERVICA_SECRET_NAME = aws_secretsmanager_secret.preservica_secret.name
    PRESERVICA_API_URL     = data.aws_ssm_parameter.preservica_url.value
  }
  tags = {
    Name      = local.preservica_config_lambda_name
    CreatedBy = local.creator
  }
}
