{
  "Statement": [
    {
      "Action": "sns:Subscribe",
      "Effect": "Allow",
      "Resource": "${tdr_sns_arn}",
      "Sid": "subscribeSNS"
    }
  ],
  "Version": "2012-10-17"
}
