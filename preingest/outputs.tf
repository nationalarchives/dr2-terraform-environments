output "aggregator_lambda" {
  value = module.dr2_preingest_aggregator_lambda.lambda_function
}

output "package_builder_lambda" {
  value = module.dr2_preingest_package_builder_lambda.lambda_function
}

output "copy_files_lambda" {
  value = module.dr2_copy_files_lambda.lambda_function
}

output "copy_files_sqs" {
  value = module.dr2_copy_files_sqs
}

output "preingest_sfn_arn" {
  value = module.dr2_preingest_step_function.step_function_arn
}