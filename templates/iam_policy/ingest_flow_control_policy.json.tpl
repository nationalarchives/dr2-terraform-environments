{
  "Statement": [
    {
      "Action": [
        "dynamodb:BatchGetItem",
        "dynamodb:DeleteItem",
        "dynamoDB:Query",
        "dynamoDB:PutItem"
      ],
      "Effect": "Allow",
      "Resource": "${dynamo_db_queue_table_arn}",
      "Sid": "readWriteDynamoDB"
    },
    {
      "Action": "ssm:GetParameter",
      "Effect": "Allow",
      "Resource": "${ssm_parameter_arn}",
      "Sid": "readSSM"
    },
    {
      "Action": [
        "states:sendTaskSuccess",
        "states:listExecutions"
      ],
      "Effect": "Allow",
      "Resource": "${step_functions_arn}",
      "Sid": "sendTaskSuccess"
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
  ],
  "Version": "2012-10-17"
}