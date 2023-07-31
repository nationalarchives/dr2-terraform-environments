{
  "Statement": [
    {
      "Action": [
        "lambda:GetFunctionConfiguration",
        "lambda:PublishVersion",
        "lambda:UpdateFunctionCode",
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "${download_metadata_lambda_arn}",
        "${slack_notification_lambda_arn}",
        "${entity_event_generation_lambda_arn}",
        "arn:aws:s3:::${bucket_name}/*"
      ]
    }
  ],
  "Version": "2012-10-17"
}
