module "config" {
  source  = "./da-terraform-configurations"
  project = "dr2"
}

module "tre_config" {
  source  = "./da-terraform-configurations"
  project = "tre"
}

module "tdr_config" {
  source  = "./da-terraform-configurations"
  project = "tdr"
}

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
    role_arn     = "arn:aws:iam::${var.account_number}:role/${local.environment_title}TerraformRole"
    session_name = "terraform"
    external_id  = module.config.terraform_config[local.environment]["terraform_external_id"]
  }
  default_tags {
    tags = {
      Environment = local.environment
      CreatedBy   = local.creator
    }
  }
}

provider "aws" {
  alias  = "datasync_tna_to_preservica"
  region = "eu-west-2"
  assume_role {
    role_arn     = "arn:aws:iam::${var.account_number}:role/${local.environment}-tna-to-preservica-ingest-s3-${local.preservica_tenant}"
    session_name = "tna_to_preservica"
  }
  default_tags {
    tags = {
      Environment = local.environment
      CreatedBy   = local.creator
    }
  }
}
