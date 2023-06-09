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
        "${download_lambda_arn}"
      ]
    }
  ],
  "Version": "2012-10-17"
}
