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
        "dynamodb:DeleteItem",
        "sns:Publish"
      ],
      "Resource": [
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_validate_generic_ingest_inputs_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_mapper_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_upsert_archive_folders_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_find_existing_asset_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_asset_opex_creator_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_folder_opex_creator_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_parent_folder_opex_creator_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_start_workflow_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_workflow_monitor_lambda_name}",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_asset_reconciler_lambda_name}",
        "arn:aws:dynamodb:eu-west-2:${account_id}:table/${ingest_lock_table_name}",
        "arn:aws:dynamodb:eu-west-2:${account_id}:table/${ingest_lock_table_name}/index/${ingest_lock_table_group_id_gsi_name}",
        "arn:aws:states:eu-west-2:${account_id}:stateMachine:${ingest_sfn_name}",
        "arn:aws:states:eu-west-2:${account_id}:execution:intg-dr2-ingest/MapOverEachFolderId:*",
        "arn:aws:states:eu-west-2:${account_id}:execution:intg-dr2-ingest/MapOverEachAssetId:*",
        "arn:aws:events:eu-west-2:${account_id}:event-bus/default",
        "${tna_to_preservica_role_arn}"
      ]
    },
    {
      "Sid": "updateFilesTable",
      "Effect": "Allow",
      "Action": [
        "dynamodb:UpdateItem"
      ],
      "Resource": [
        "arn:aws:dynamodb:eu-west-2:${account_id}:table/${ingest_files_table_name}"
      ]
    },
    {
      "Sid": "callPreingestStepFunction",
      "Effect": "Allow",
      "Action": [
        "states:StartExecution"
      ],
      "Resource": [
        "${preingest_tdr_step_function_arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${ingest_state_bucket_name}",
        "arn:aws:s3:::${ingest_state_bucket_name}/*"
      ],
      "Sid": "readWriteIngestState"
    }
  ],
  "Version": "2012-10-17"
}
