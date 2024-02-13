{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowDataSync",
      "Effect": "Allow",
      "Principal": {
        "Service": "datasync.amazonaws.com"
      },
      "Action": [
        "logs:PutLogEvents",
        "logs:CreateLogStream"
      ],
      "Resource": "arn:aws:logs:eu-west-2:${account_id}:log-group:*:*",
      "Condition": {
        "ArnLike": {
          "aws:SourceArn": "arn:aws:datasync:eu-west-2:${account_id}:task/*"
        }
      }
    },
    {
      "Sid": "TrustEventsToStoreLogEvent",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "delivery.logs.amazonaws.com",
          "events.amazonaws.com"
        ]
      },
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:eu-west-2:${account_id}:log-group:/aws/events/*:*"
    }
  ]
}
