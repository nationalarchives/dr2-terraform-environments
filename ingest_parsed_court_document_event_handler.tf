locals {
  ingest_parsed_court_document_event_handler_queue_name  = "${local.environment}-ingest-parsed-court-document-event-handler"
  ingest_parsed_court_document_event_handler_lambda_name = "${local.environment}-ingest-parsed-court-document-event-handler"
}
module "ingest_parsed_court_document_event_handler_sqs" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//sqs"
  queue_name = local.ingest_parsed_court_document_event_handler_queue_name
  sqs_policy = templatefile("./templates/sqs/sqs_access_policy.json.tpl", {
    account_id = var.dp_account_number, //TODO Restrict this to the SNS topic ARN when it's created
    queue_name = local.ingest_parsed_court_document_event_handler_queue_name
  })
  redrive_maximum_receives = 3
  kms_key_id               = module.dr2_kms_key.kms_key_arn
  dlq_notification_topic   = "arn:aws:sns:eu-west-2:${data.aws_caller_identity.current.account_id}:${local.environment}-dlq-notifications"
}

module "ingest_parsed_court_document_event_handler_lambda" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name = local.ingest_parsed_court_document_event_handler_lambda_name
  handler       = "uk.gov.nationalarchives.Lambda::handleRequest"
  lambda_sqs_queue_mappings = {
    ingest_parsed_court_document_event_handler_queue = module.ingest_parsed_court_document_event_handler_sqs.sqs_arn
  }
  policies = {
    "${local.ingest_parsed_court_document_event_handler_lambda_name}-policy" = templatefile("./templates/iam_policy/ingest_parsed_court_document_event_handler_lambda_policy.json.tpl", {
      ingest_parsed_court_document_event_handler_queue_arn = module.ingest_parsed_court_document_event_handler_sqs.sqs_arn
      bucket_name                                          = local.ingest_raw_cache_bucket_name
      account_id                                           = var.dp_account_number
      lambda_name                                          = local.ingest_parsed_court_document_event_handler_lambda_name
      step_function_arn                                    = module.pre_ingest_step_function.step_function_arn
    })
  }
  memory_size = 512
  runtime     = "java17"
  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.outbound_https_access_only.security_group_id]
  }
  plaintext_env_vars = {
    OUTPUT_BUCKET = local.ingest_raw_cache_bucket_name
    SFN_ARN       = module.pre_ingest_step_function.step_function_arn
  }
  tags = {
    Name      = local.ingest_parsed_court_document_event_handler_lambda_name
    CreatedBy = "dp-terraform-environments"
  }
}