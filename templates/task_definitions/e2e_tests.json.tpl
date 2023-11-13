[
  {
    "name": "e2e-tests",
    "image": "${management_account_id}.dkr.ecr.eu-west-2.amazonaws.com/e2e-tests",
    "portMappings": [],
    "essential": true,
    "environment": [
      {
        "name": "PRESERVICA_URL",
        "value": "https://tna.preservica.com"
      },
      {
        "name": "ACCOUNT_ID",
        "value": "${account_id}"
      },
      {
        "name": "SECRET_NAME",
        "value": "${secret_name}"
      },
      {
        "name": "ENVIRONMENT",
        "value": "${environment}"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-create-group": "true",
        "awslogs-group": "/ecs/e2e-tests",
        "awslogs-region": "eu-west-2",
        "awslogs-stream-prefix": "ecs"
      },
      "secretOptions": []
    },
    "family": "e2e-tests",
    "taskRoleArn": "${task_role_arn}",
    "executionRoleArn": "${execution_role_arn}",
    "networkMode": "awsvpc",
    "compatibilities": [
      "FARGATE"
    ],
    "requiresCompatibilities": [
      "FARGATE"
    ],
    "cpu": 1024,
    "memory": 3072,
    "runtimePlatform": {
      "cpuArchitecture": "X86_64",
      "operatingSystemFamily": "LINUX"
    },
    "tags": []
  }
]
