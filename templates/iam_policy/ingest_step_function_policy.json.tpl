{
  "Statement": [
    {
      "Sid": "sfnPolicy",
      "Effect": "Allow",
      "Action": [
        "states:RedriveExecution",
        "lambda:InvokeFunction",
        "states:StartExecution",
        "sts:AssumeRole",
        "events:PutEvents",
        "dynamodb:Query",
        "dynamodb:BatchWriteItem"
      ],
      "Resource": [
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_mapper_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_upsert_archive_folders_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_check_preservica_for_existing_io}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_asset_opex_creator_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_folder_opex_creator_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_parent_folder_opex_creator_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_start_workflow_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_workflow_monitor_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_asset_reconciler_lambda_name}",
        "arn:aws:dynamodb:eu-west-2:${account_id}:table/${ingest_lock_table_name}",
        "arn:aws:dynamodb:eu-west-2:${account_id}:table/${ingest_lock_table_name}/index/${ingest_lock_table_batch_id_gsi_name}",
        "arn:aws:states:eu-west-2:${account_id}:stateMachine:${ingest_sfn_name}",
        "arn:aws:states:eu-west-2:${account_id}:execution:${ingest_sfn_name}/StagingCacheS3ObjectKeys:*",
        "arn:aws:states:eu-west-2:${account_id}:execution:${ingest_sfn_name}:*",
        "arn:aws:events:eu-west-2:${account_id}:event-bus/default",
        "${tna_to_preservica_role_arn}"
      ]
    }
  ],
  "Version": "2012-10-17"
}
