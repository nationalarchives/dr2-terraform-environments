output "post_ingest_table_name" {
  value = local.post_ingest_state_table_name
}

output "post_ingest_table_arn" {
  value = module.post_ingest_state_table.table_arn
}

output "post_ingest_confirmer_queue_arn" {
  value = module.dr2_custodial_copy_confirmer_queue.sqs_arn
}