data "aws_ssm_parameter" "preservica_url" {
  name = "/${local.environment}/preservica/url"
}
