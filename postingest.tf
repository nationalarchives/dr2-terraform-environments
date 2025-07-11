module "postingest" {
  source                  = "./postingest"
  environment             = local.environment
  notifications_topic_arn = module.dr2_notifications_sns.sns_arn
}