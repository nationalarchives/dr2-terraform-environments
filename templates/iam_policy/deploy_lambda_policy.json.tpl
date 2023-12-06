{
  "Statement": [
    {
      "Action" : [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${bucket_name}/*"
    },
    {
      "Action": [
        "lambda:GetFunctionConfiguration",
        "lambda:GetFunction",
        "lambda:PublishVersion",
        "lambda:UpdateFunctionCode"
      ],
      "Effect": "Allow",
      "Resource": ${lambda_arns}
    }
  ],
  "Version": "2012-10-17"
}
