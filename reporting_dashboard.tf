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

resource "aws_cloudfront_origin_access_control" "reporting_access_control" {
  name                              = "reporting-acccess-control"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = "${local.reporting_bucket_name}.s3.amazonaws.com"
    origin_id   = "s3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.reporting_access_control.id
  }

  enabled = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id       = "s3Origin"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
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
    Name = local.reporting_helper_lambda_name
  }
}