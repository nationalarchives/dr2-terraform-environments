{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "APIAccessForDynamoDBStreams",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:DescribeStream",
        "dynamodb:ListStreams"
      ],
      "Resource": "${dynamo_db_file_table_stream_arn}"
    },
    {
      "Action": [
        "dynamodb:BatchGetItem",
        "dynamodb:Query",
        "dynamodb:BatchWriteItem"
      ],
      "Effect": "Allow",
      "Resource": [
        "${dynamo_db_file_table_arn}",
        "${dynamo_db_file_table_arn}/index/${gsi_name}"
      ],
      "Sid": "getAndQueryDynamoDB"
    },
    {
      "Action": "sns:Publish",
      "Effect": "Allow",
      "Resource": "${sns_arn}",
      "Sid": "publishSNS"
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
      "Sid": "writeLogs"
    }
  ]
}