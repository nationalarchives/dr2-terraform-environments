terraform {
  backend "s3" {
    bucket         = "mgmt-dp-terraform-state"
    key            = "terraform.state"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "mgmt-dp-terraform-state-lock"
  }
}
provider "aws" {
  region = "eu-west-2"
  assume_role {
    role_arn     = "arn:aws:iam::${var.dp_account_number}:role/${local.environment_title}TerraformRole"
    session_name = "terraform"
  }
  default_tags {
    tags = {
      Environment = local.environment
      CreatedBy = "dp-terraform-environments"
    }
  }
}

