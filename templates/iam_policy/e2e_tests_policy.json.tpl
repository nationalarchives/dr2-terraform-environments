{
  "Statement": [
    {
      "Action": [
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem"
      ],
      "Effect": "Allow",
      "Resource": [
        "${dynamo_db_lock_table_arn}"
      ],
      "Sid": "updateDynamoLockTable"
    },
    {
      "Action": [
        "states:StartExecution"
      ],
      "Effect": "Allow",
      "Resource": [
        "${preingest_sfn_arn}"
      ],
      "Sid": "startPreingestSfn"
    },
    {
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:GetQueueAttributes",
        "sqs:DeleteMessage"
      ],
      "Effect": "Allow",
      "Resource": ["${copy_files_dlq}", "${e2e_tests_queue}"],
      "Sid": "readSqs"
    },
    {
      "Action": [
        "sqs:SendMessage"
      ],
      "Effect": "Allow",
      "Resource": "${copy_files_from_tdr_queue}",
      "Sid": "sendSqsMessage"
    },
    {
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${input_bucket_name}",
        "arn:aws:s3:::${input_bucket_name}/*"
      ],
      "Sid": "writeToRawCache"
    }
  ],
  "Version": "2012-10-17"
}
