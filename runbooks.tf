module "remove_security_groups_role" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_role"
  assume_role_policy = templatefile("${path.module}/templates/iam_role/github_assume_role.json.tpl", {
    account_id = data.aws_caller_identity.current.account_id,
  repo_filters = jsonencode(["repo:nationalarchives/dr2-runbooks:environment:intg", "repo:nationalarchives/dr2-runbooks:environment:staging", "repo:nationalarchives/dr2-runbooks:environment:prod"]) })
  name = "${local.environment}-dr2-runbook-remove-security-group-rule"
  policy_attachments = {
    remove_security_group_policy = module.remove_security_groups_policy.policy_arn
  }
  tags = {}
}

module "remove_security_groups_policy" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name   = "${local.environment}-dr2-runbooks-policy"
  policy_string = templatefile("${path.module}/templates/iam_policy/remove_security_groups.json.tpl", {
    security_group_arn = "arn:aws:ec2:eu-west-2:${data.aws_caller_identity.current.account_id}:security-group/${module.outbound_https_access_only.security_group_id}"
  })
}