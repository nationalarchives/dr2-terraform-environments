{
  "Statement": [
    {
      "Sid": "sfnPolicy",
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction",
        "states:StartExecution",
        "s3:ListBucket"
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
        "arn:aws:s3:::${ingest_staging_cache_bucket_name}"
      ]
    }
  ],
  "Version": "2012-10-17"
}
