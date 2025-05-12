locals {
  ingest_reporting_lambda_name = "${local.environment}-dr2-ingest-reporting"
  origin_id_s3_origin          = "s3Origin"
}

module "dr2_ingest_reporting_cloudwatch_event" {
  source                  = "git::https://github.com/nationalarchives/da-terraform-modules//cloudwatch_events"
  rule_name               = "${local.environment}-dr2-ingest-reporting-schedule"
  schedule                = "rate(10 minutes)"
  lambda_event_target_arn = "arn:aws:lambda:eu-west-2:${data.aws_caller_identity.current.account_id}:function:${local.ingest_reporting_lambda_name}"
}


module "dr2_ingest_reporting_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.ingest_reporting_lambda_name
  handler         = "lambda_function.lambda_handler"
  timeout_seconds = local.python_timeout_seconds
  policies = {
    "${local.ingest_reporting_lambda_name}-policy" = templatefile("./templates/iam_policy/ingest_reporting_policy.json.tpl", {
      account_id  = data.aws_caller_identity.current.account_id
      lambda_name = local.ingest_reporting_lambda_name
      bucket_name = local.ingest_reporting_bucket_name
    })
  }
  memory_size = local.python_lambda_memory_size
  runtime     = local.python_runtime
  plaintext_env_vars = {
    INGEST_SFN_ARN     = module.dr2_ingest_step_function.step_function_arn
    WORKFLOW_SFN_ARN   = module.dr2_ingest_run_workflow_step_function.step_function_arn
    PREINGEST_SFN_ARN  = module.dr2_preingest_tdr_step_function.step_function_arn
    OUTPUT_BUCKET_NAME = local.ingest_reporting_bucket_name
  }

  tags = {
    Name = local.ingest_reporting_lambda_name
  }
}

resource "aws_s3_object" "index_html" {
  bucket = local.ingest_reporting_bucket_name
  key    = "index.html"
  source = "${path.module}/website/reporting_dashboard/index.html"
  content_type = "text/html"
}

resource "aws_cloudfront_origin_access_control" "reporting_access_control" {
  name                              = "reporting-acccess-control"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name              = "${local.ingest_reporting_bucket_name}.s3.eu-west-2.amazonaws.com"
    origin_id                = local.origin_id_s3_origin
    origin_access_control_id = aws_cloudfront_origin_access_control.reporting_access_control.id
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = local.origin_id_s3_origin
    viewer_protocol_policy   = "redirect-to-https"
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized policy ID
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" #Managed-CORS-S3Origin policy ID
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = local.ingest_reporting_lambda_name
  }
}