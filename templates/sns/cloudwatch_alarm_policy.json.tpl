{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "cloudwatch.amazonaws.com"
    },
    "Action": "sns:Publish",
    "Resource": "arn:aws:sns:eu-west-2:${account_id}:${topic_name}",
    "Condition": {
      "ArnLike": {
        "aws:SourceArn": "${cloudwatch_alarm_arn}"
      }
    }
  }]
}
