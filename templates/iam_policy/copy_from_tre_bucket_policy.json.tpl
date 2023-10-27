{
  "Statement": [
    {
      "Action" : [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${bucket_name}/*"
    }
  ],
  "Version": "2012-10-17"
}
