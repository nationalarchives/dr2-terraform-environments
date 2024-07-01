{
  "Version": "2008-10-17",
  "Id": "disaster_recovery_topic",
  "Statement": [
    {
      "Sid": "SNSAllowLambdaToPublish",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${dr_user_arn}"
      },
      "Action": "SNS:Publish",
      "Resource": "${sns_topic}"
    }
  ]
}