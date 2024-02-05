{
  "Statement": [
    {
      "Sid": "sfnPolicy",
      "Effect": "Allow",
      "Action": [
        "states:RedriveExecution",
        "lambda:InvokeFunction",
        "states:StartExecution",
        "sts:AssumeRole"
      ],
      "Resource": [
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_mapper_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_upsert_archive_folders_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_asset_opex_creator_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_folder_opex_creator_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_parent_folder_opex_creator_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_start_workflow_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_s3_copy_lambda_name}",
        "arn:aws:states:eu-west-2:${account_id}:stateMachine:${ingest_sfn_name}",
        "arn:aws:states:eu-west-2:${account_id}:execution:${ingest_sfn_name}/StagingCacheS3ObjectKeys:*",
        "arn:aws:states:eu-west-2:${account_id}:execution:${ingest_sfn_name}:*",
        "${tna_to_preservica_role_arn}"
      ]
    }
  ],
  "Version": "2012-10-17"
}
