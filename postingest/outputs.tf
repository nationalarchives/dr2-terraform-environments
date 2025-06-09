output "postingest_table_name" {
  value = local.postingest_state_table_name
}

output "postingest_table_arn" {
  value = module.postingest_state_table.table_arn
}

output "postingest_confirmer_queue_arn" {
  value = module.dr2_custodial_copy_confirmer_queue.sqs_arn
}