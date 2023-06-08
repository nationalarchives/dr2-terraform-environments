{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${role_arn}"
      },
      "Action": "SQS:SendMessage",
      "Resource": "arn:aws:sqs:eu-west-2:${account_id}:${queue_name}"
    }
  ]
}
