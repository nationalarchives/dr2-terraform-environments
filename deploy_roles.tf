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
    download_metadata_lambda_arn  = module.download_metadata_and_files_lambda.lambda_arn,
    slack_notification_lambda_arn = module.slack_notifications_lambda.lambda_arn
    bucket_name                   = "mgmt-dp-code-deploy"
  })
}