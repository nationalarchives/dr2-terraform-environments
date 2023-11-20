{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups"
      ],
      "Resource": "*"
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "ecs:RunTask",
        "logs:GetLogEvents",
        "ecs:DescribeTasks",
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/aws/ecs/e2e-tests:log-stream:*",
        "arn:aws:ecs:eu-west-2:${account_id}:task/default/*",
        "arn:aws:ecs:eu-west-2:${account_id}:task-definition/e2e-tests",
        "${execution_role}",
        "${task_role}"
      ]
    }
  ]
}
