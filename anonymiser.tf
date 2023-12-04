locals {
  court_document_anonymiser_lambda_name = "${local.environment}-court-document-package-anonymiser"
  court_document_anonymiser_queue_name  = "${local.environment}-court-document-package-anonymiser"
}
module "court_document_package_anonymiser_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.court_document_anonymiser_lambda_name
  handler         = "bootstrap"
  timeout_seconds = 30
  lambda_sqs_queue_mappings = {
    court_document_package_anonymiser_queue = module.court_document_package_anonymiser_sqs.sqs_arn
  }
  policies = {
    "${local.court_document_anonymiser_lambda_name}-policy" = templatefile("./templates/iam_policy/anonymiser_lambda_policy.json.tpl", {
      anonymiser_test_input_queue         = module.court_document_package_anonymiser_sqs.sqs_arn
      ingest_court_document_handler_queue = module.ingest_parsed_court_document_event_handler_sqs.sqs_arn
      output_bucket_name                  = local.ingest_parsed_court_document_event_handler_test_bucket_name
      account_id                          = var.account_number
      lambda_name                         = local.court_document_anonymiser_lambda_name
      tre_bucket_arn                      = module.tre_config.terraform_config["prod"]["s3_court_document_pack_out_arn"]
      tre_kms_arn                         = module.tre_config.terraform_config["prod_s3_court_document_pack_out_kms_arn"]
    })
  }
  memory_size = 128
  runtime     = "provided.al2023"
  plaintext_env_vars = {
    OUTPUT_BUCKET = local.ingest_parsed_court_document_event_handler_test_bucket_name
    OUTPUT_QUEUE  = module.ingest_parsed_court_document_event_handler_sqs.sqs_queue_url
  }
  tags = {}
}

module "court_document_package_anonymiser_sqs" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//sqs"
  queue_name = local.court_document_anonymiser_queue_name
  sqs_policy = templatefile("./templates/sqs/sns_send_message_policy.json.tpl", {
    account_id = var.account_number,
    queue_name = local.court_document_anonymiser_queue_name
    topic_arn  = module.tre_config.terraform_config["prod"]["da_eventbus"]
  })
  redrive_maximum_receives = 5
  visibility_timeout       = 180
  kms_key_id               = module.dr2_kms_key.kms_key_arn
}

resource "aws_sns_topic_subscription" "tre_topic_subscription" {
  endpoint  = module.court_document_package_anonymiser_sqs.sqs_arn
  protocol  = "sqs"
  topic_arn = module.tre_config.terraform_config["prod"]["da_eventbus"]
}
