module "deploy_lambda_role" {
  source             = "git::https://github.com/nationalarchives/da-terraform-modules//iam_role"
  assume_role_policy = templatefile("${path.module}/templates/iam_role/github_assume_role.json.tpl", { account_id = data.aws_caller_identity.current.account_id, repo_filter = "dr2-*" })
  name               = "${local.environment_title}DPGithubActionsDeployLambdaRole"
  policy_attachments = {
    deploy_policy = module.deploy_lambda_policy.policy_arn
  }
  tags = {}
}

module "deploy_lambda_policy" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name   = "${local.environment_title}DPGithubActionsDeployLambdaPolicy"
  policy_string = templatefile("${path.module}/templates/iam_policy/deploy_lambda_policy.json.tpl", {
    lambda_arns = jsonencode(flatten(
      [
        module.download_metadata_and_files_lambda.lambda_arn,
        module.ip_lock_checker_lambda.lambda_arn,
        module.ingest_parsed_court_document_event_handler_lambda.lambda_arn,
        module.entity_event_generator_lambda.lambda_arn,
        module.ingest_mapper_lambda.lambda_arn,
        module.ingest_asset_opex_creator_lambda.lambda_arn,
        module.ingest_folder_opex_creator_lambda.lambda_arn,
        module.ingest_upsert_archive_folders_lambda.lambda_arn,
        module.ingest_parent_folder_opex_creator_lambda.lambda_arn,
        module.ingest_start_workflow_lambda.lambda_arn,
        module.ingest_asset_reconciler_lambda.lambda_arn,
        module.s3_copy_lambda.lambda_arn,
        module.ingest_workflow_monitor_lambda.lambda_arn,
        local.anonymiser_lambda_arns
      ]
    ))
    bucket_name = "mgmt-dp-code-deploy"
  })
}
