locals {
  az_count = local.environment == "prod" ? 2 : 1
}
resource "random_password" "preservica_password" {
  length = 20
}

resource "random_string" "preservica_user" {
  length  = 10
  special = false
}

resource "aws_secretsmanager_secret" "preservica_secret" {
  name = "${local.environment}-preservica-api-login-details-${random_string.preservica_user.result}"
}

data "aws_ssm_parameter" "slack_webhook_url" {
  name = "/${local.environment}/slack/cloudwatch-alarm-webhook"
}

resource "aws_secretsmanager_secret_version" "preservica_secret_version" {
  secret_id     = aws_secretsmanager_secret.preservica_secret.id
  secret_string = jsonencode({ (random_string.preservica_user.result) = random_password.preservica_password.result })
  lifecycle {
    ignore_changes = [secret_string]
  }
}

module "vpc" {
  source                       = "git::https://github.com/nationalarchives/da-terraform-modules//vpc"
  vpc_name                     = "${local.environment}-vpc"
  az_count                     = local.az_count
  elastic_ip_allocation_ids    = aws_eip.eip.*.allocation_id
  nat_instance_security_groups = [module.nat_instance_security_group.security_group_id]
  environment                  = local.environment
}

resource "aws_eip" "eip" {
  count  = local.az_count
  domain = "vpc"
}

module "nat_instance_security_group" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//security_group"
  common_tags = { CreatedBy = "dp-terraform-environments" }
  description = "A security group to allow access to the NAT instance"
  name        = "${local.environment}-nat-instance-security-group"
  vpc_id      = module.vpc.vpc_id
  ingress_security_group_rules = [{
    port              = 443,
    description       = "Inbound HTTPS",
    security_group_id = module.outbound_https_access_only.security_group_id
  }]
  egress_cidr_rules = [{
    port        = 443
    description = "Outbound https access",
    cidr_blocks = ["0.0.0.0/0"],
    protocol    = "tcp"
  }]
}

module "outbound_https_access_only" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//security_group"
  common_tags = { CreatedBy = "dp-terraform-environments" }
  description = "A security group to allow outbound access only"
  name        = "${local.environment}-outbound-https"
  vpc_id      = module.vpc.vpc_id
  egress_cidr_rules = [{
    port        = 443
    description = "Outbound https access",
    cidr_blocks = ["0.0.0.0/0"],
    protocol    = "tcp"
  }]
}
