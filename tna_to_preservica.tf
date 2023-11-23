locals {
  preservica_tenant = local.environment == "prod" ? "tna" : "tnatest"
}
module "copy_tna_to_preservica_role" {
  source             = "git::https://github.com/nationalarchives/da-terraform-modules//iam_role"
  assume_role_policy = templatefile("${path.module}/templates/iam_role/aws_principal_assume_role.json.tpl", { aws_arn = data.aws_ssm_parameter.dev_admin_role.value })
  name               = "${local.environment}-tna-to-preservica-ingest-s3-${local.preservica_tenant}"
  policy_attachments = {
    copy_tna_to_preservica_policy = module.copy_tna_to_preservica_policy.policy_arn
  }
  tags = {}
}

module "copy_tna_to_preservica_policy" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name   = "${local.environment}-tna-to-preservica-ingest-s3-${local.preservica_tenant}-policy"
  policy_string = templatefile("${path.module}/templates/iam_policy/tna_to_preservica_copy.json.tpl", {
    preservica_tenant                = local.preservica_tenant
    ingest_staging_cache_bucket_name = local.ingest_staging_cache_bucket_name
  })
}
