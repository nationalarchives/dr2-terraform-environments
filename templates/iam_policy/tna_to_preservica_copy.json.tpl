{
  "Statement": [
    {
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::com.preservica.${preservica_tenant}.bulk1/*",
        "arn:aws:s3:::com.preservica.${preservica_tenant}.bulk2/*",
        "arn:aws:s3:::com.preservica.${preservica_tenant}.bulk3/*",
        "arn:aws:s3:::com.preservica.${preservica_tenant}.bulk4/*",
        "arn:aws:s3:::com.preservica.${preservica_tenant}.put.holding/*",
        "arn:aws:s3:::${ingest_staging_cache_bucket_name}/*"
      ],
      "Sid": "readWriteTnaAndPreservica"
    },
    {
      "Action": [
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::com.preservica.${preservica_tenant}.bulk1",
        "arn:aws:s3:::com.preservica.${preservica_tenant}.bulk2",
        "arn:aws:s3:::com.preservica.${preservica_tenant}.bulk3",
        "arn:aws:s3:::com.preservica.${preservica_tenant}.bulk4",
        "arn:aws:s3:::com.preservica.${preservica_tenant}.put.holding"
      ],
      "Sid": "listBucketPreservica"
    }
  ],
  "Version": "2012-10-17"
}
