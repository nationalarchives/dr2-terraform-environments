module "post_ingest" {
  source                  = "./post_ingest"
  environment             = local.environment
  notifications_topic_arn = module.dr2_notifications_sns.sns_arn
}