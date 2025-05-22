{
  "Statement": [
    {
      "Action": [
        "sqs:SendMessage",
        "sqs:GetQueueAttributes"
      ],
      "Effect": "Allow",
      "Resource": "${custodial_copy_checker_queue_arn}",
      "Sid": "readWriteSqs"
    },
    {
      "Action": [
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:BatchGetItem",
        "dynamodb:Query"
      ],
      "Effect": "Allow",
      "Resource": [
        "${post_ingest_state_arn}"
      ],
      "Sid": "readUpdateDynamoPostIngestTable"
    },
    {
      "Action": [
        "logs:PutLogEvents",
        "logs:CreateLogStream",
        "logs:CreateLogGroup"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/aws/lambda/${lambda_name}:*:*",
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/aws/lambda/${lambda_name}:*"
      ],
      "Sid": "readWriteLogs"
    }
  ],
  "Version": "2012-10-17"
}
