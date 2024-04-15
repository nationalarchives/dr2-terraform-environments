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
      "Resource": "${entity_event_queue}",
      "Sid": "readSqs"
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
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/disaster-recovery:*:*",
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/disaster-recovery:*",
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/disaster-recovery"
      ],
      "Sid": "writeLogs"
    }
  ],
  "Version": "2012-10-17"
}
