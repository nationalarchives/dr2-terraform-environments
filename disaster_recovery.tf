module "disaster_recovery_bucket" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//s3"
  bucket_name = local.disaster_recovery_bucket_name
  common_tags = {
    CreatedBy = "dp-terraform-environments"
  }
  logging_bucket_policy = templatefile("./templates/s3/log_bucket_policy.json.tpl", {
    bucket_name = "${local.disaster_recovery_bucket_name}-logs", account_id = var.dp_account_number
  })
  bucket_policy = templatefile("./templates/s3/disaster_recovery_bucket_policy.json.tpl", {
    download_files_metadata_lambda_role_arn = module.download_metadata_and_files_lambda.lambda_role_arn,
    bucket_name                             = local.disaster_recovery_bucket_name
  })
}
