{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RevokeEgress",
      "Effect": "Allow",
      "Action": "ec2:RevokeSecurityGroupEgress",
      "Resource": "${security_group_arn}"
    },
    {
      "Sid": "DescribeSecurityGroups",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSecurityGroupRules",
        "ec2:DescribeSecurityGroups"
      ],
      "Resource": "*"
    }
  ]
}