{
  "Statement": [
    {
      "Sid": "VisualEditor0",
      "Effect": "Allow",
      "Action": "lambda:InvokeFunction",
      "Resource": [
        "arn:aws:lambda:eu-west-2:${account_id}:function:${local.ingest_mapper_lambda_name}:*",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${local.ingest_upsert_archives_folder_lambda_name}:*",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${local.ingest_asset_opex_creator_lambda_name}:*",
        "arn:aws:lambda:eu-west-2:${account_id}:function:${local.ingest_folder_opex_creator_lambda_name}:*"
      ]
    }
  ],
  "Version": "2012-10-17"
}
