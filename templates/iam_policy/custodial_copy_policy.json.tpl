{
  "Statement": [
    {
      "Action": "secretsmanager:GetSecretValue",
      "Effect": "Allow",
      "Resource": "${secrets_manager_secret_arn}",
      "Sid": "readSecretsManager"
    },
    {
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:GetQueueAttributes",
        "sqs:DeleteMessage"
      ],
      "Effect": "Allow",
      "Resource": [
        "${entity_event_queue}",
        "${database_builder_queue}"
      ],
      "Sid": "readSqs"
    },
    {
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "putMetrics"
    },
    {
      "Action": [
        "logs:PutLogEvents",
        "logs:PutRetentionPolicy",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups",
        "logs:CreateLogStream",
        "logs:CreateLogGroup"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/custodial-copy-backend:*:*",
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/custodial-copy-backend:*",
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/custodial-copy-backend",
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/custodial-copy-webapp:*:*",
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/custodial-copy-webapp:*",
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/custodial-copy-webapp",
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/custodial-copy-db-builder:*:*",
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/custodial-copy-db-builder:*",
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/custodial-copy-builder"
      ],
      "Sid": "writeLogs"
    },
    {
      "Action" : "ecr:GetAuthorizationToken",
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action" : [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:ecr:eu-west-2:${management_account_id}:repository/dr2-custodial-copy",
        "arn:aws:ecr:eu-west-2:${management_account_id}:repository/dr2-custodial-copy-db-builder",
        "arn:aws:ecr:eu-west-2:${management_account_id}:repository/dr2-custodial-copy-webapp"
      ]
    }
  ],
  "Version": "2012-10-17"
}
