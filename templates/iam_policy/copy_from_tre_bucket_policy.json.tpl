{
  "Statement": [
    {
      "Action" : [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${bucket_name}/*",
        "arn:aws:s3:::${bucket_name}"
      ]
    }
  ],
  "Version": "2012-10-17"
}
