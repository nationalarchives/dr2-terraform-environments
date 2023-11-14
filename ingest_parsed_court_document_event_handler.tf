locals {
  ingest_parsed_court_document_event_handler_queue_name       = "${local.environment}-ingest-parsed-court-document-event-handler"
  ingest_parsed_court_document_event_handler_test_bucket_name = "${local.environment}-ingest-parsed-court-document-test-input"
  ingest_parsed_court_document_event_handler_lambda_name      = "${local.environment}-ingest-parsed-court-document-event-handler"
  tre_v1_judgment_output_bucket                               = "prod-tre-editorial-judgment-out"
}

module "ingest_parsed_court_document_event_handler_test_input_bucket" {
  count       = local.environment != "prod" ? 1 : 0
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//s3"
  bucket_name = local.ingest_parsed_court_document_event_handler_test_bucket_name
  logging_bucket_policy = templatefile("./templates/s3/log_bucket_policy.json.tpl", {
    bucket_name = "${local.ingest_parsed_court_document_event_handler_test_bucket_name}-logs", account_id = var.account_number
  })
  bucket_policy = templatefile("./templates/s3/lambda_access_bucket_policy.json.tpl", {
    lambda_role_arns = jsonencode([module.ingest_parsed_court_document_event_handler_lambda.lambda_role_arn]),
    bucket_name      = local.ingest_parsed_court_document_event_handler_test_bucket_name
  })
  kms_key_arn = module.dr2_kms_key.kms_key_arn
}

module "copy_from_tre_bucket_role" {
  count              = local.environment != "prod" ? 1 : 0
  source             = "git::https://github.com/nationalarchives/da-terraform-modules//iam_role"
  assume_role_policy = templatefile("${path.module}/templates/iam_role/account_assume_role.json.tpl", { account_id = data.aws_caller_identity.current.account_id })
  name               = split("/", module.config.terraform_config[local.environment]["copy_from_tre_bucket_role"])[1]
  policy_attachments = {
    copy_from_tre_bucket_policy = module.copy_from_tre_bucket_policy[count.index].policy_arn
  }
  tags = {}
}

module "copy_from_tre_bucket_policy" {
  count         = local.environment != "prod" ? 1 : 0
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name          = "${local.environment}-copy-from-tre-bucket-policy"
  policy_string = templatefile("${path.module}/templates/iam_policy/copy_from_tre_bucket_policy.json.tpl", { bucket_name = local.tre_v1_judgment_output_bucket })
}

module "ingest_parsed_court_document_event_handler_sqs" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//sqs"
  queue_name = local.ingest_parsed_court_document_event_handler_queue_name
  sqs_policy = templatefile("./templates/sqs/sqs_access_policy.json.tpl", {
    account_id = var.account_number, //TODO Restrict this to the SNS topic ARN when it's created
    queue_name = local.ingest_parsed_court_document_event_handler_queue_name
  })
  redrive_maximum_receives = 5
  visibility_timeout       = 180
  kms_key_id               = module.dr2_kms_key.kms_key_arn
}

module "ingest_parsed_court_document_event_handler_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_parsed_court_document_event_handler_lambda_name
  handler         = "uk.gov.nationalarchives.Lambda::handleRequest"
  timeout_seconds = 30
  lambda_sqs_queue_mappings = {
    ingest_parsed_court_document_event_handler_queue = module.ingest_parsed_court_document_event_handler_sqs.sqs_arn
  }
  policies = {
    "${local.ingest_parsed_court_document_event_handler_lambda_name}-policy" = templatefile("./templates/iam_policy/ingest_parsed_court_document_event_handler_lambda_policy.json.tpl", {
      ingest_parsed_court_document_event_handler_queue_arn = module.ingest_parsed_court_document_event_handler_sqs.sqs_arn
      bucket_name                                          = local.ingest_raw_cache_bucket_name
      account_id                                           = var.account_number
      lambda_name                                          = local.ingest_parsed_court_document_event_handler_lambda_name
      step_function_arn                                    = module.ingest_step_function.step_function_arn
    })
  }
  memory_size = 512
  runtime     = "java17"
  plaintext_env_vars = {
    OUTPUT_BUCKET = local.ingest_raw_cache_bucket_name
    SFN_ARN       = module.ingest_step_function.step_function_arn
  }
  tags = {
    Name      = local.ingest_parsed_court_document_event_handler_lambda_name
    CreatedBy = "dr2-terraform-environments"
  }
}
