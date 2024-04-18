module "run_e2e_tests_role" {
  source             = "git::https://github.com/nationalarchives/da-terraform-modules//iam_role"
  assume_role_policy = templatefile("${path.module}/templates/iam_role/github_assume_role.json.tpl", { account_id = data.aws_caller_identity.current.account_id, repo_filter = "dr2-*" })
  name               = "${local.environment}-dr2-run-e2e-tests-role"
  policy_attachments = {
    run_e2e_tests_policy = module.run_e2e_tests_policy.policy_arn
  }
  tags = {}
}

module "e2e_tests_ecs_task_role" {
  source             = "git::https://github.com/nationalarchives/da-terraform-modules//iam_role"
  assume_role_policy = templatefile("${path.module}/templates/iam_role/service_assume_role.json.tpl", { service = "ecs-tasks" })
  name               = "${local.environment}-dr2-e2e-tests-task-role"
  policy_attachments = {
    e2e_tests_task_policy = module.e2e_tests_task_policy.policy_arn
  }
  tags = {}
}

module "e2e_tests_task_policy" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name   = "${local.environment}-dr2-e2e-tests-task-policy"
  policy_string = templatefile("${path.module}/templates/iam_policy/e2e_tests_task_policy.json.tpl", {
    court_document_test_input_bucket = local.ingest_parsed_court_document_event_handler_test_bucket_name_old,
    secret_arn                       = aws_secretsmanager_secret.preservica_secret.arn,
    sqs_arn                          = module.ingest_parsed_court_document_event_handler_sqs.sqs_arn
  })
}

module "e2e_tests_ecs_execution_role" {
  source             = "git::https://github.com/nationalarchives/da-terraform-modules//iam_role"
  assume_role_policy = templatefile("${path.module}/templates/iam_role/service_assume_role.json.tpl", { service = "ecs-tasks" })
  name               = "${local.environment}-dr2-e2e-tests-execution-role"
  policy_attachments = {
    e2e_tests_execution_policy = module.e2e_tests_execution_policy.policy_arn
  }
  tags = {}
}

module "e2e_tests_execution_policy" {
  source        = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name          = "${local.environment}-dr2-e2e-tests-execution-policy"
  policy_string = templatefile("${path.module}/templates/iam_policy/e2e_tests_execution_policy.json.tpl", { account_id = data.aws_caller_identity.current.account_id, management_account_id = module.config.account_numbers["mgmt"] })
}


module "run_e2e_tests_policy" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name   = "${local.environment}-dr2-run-e2e-tests-role"
  policy_string = templatefile("${path.module}/templates/iam_policy/run_e2e_tests_task.json.tpl", {
    account_id     = data.aws_caller_identity.current.account_id,
    execution_role = module.e2e_tests_ecs_execution_role.role_arn,
    task_role      = module.e2e_tests_ecs_task_role.role_arn,
  })
}

resource "aws_ecs_task_definition" "e2e_tests" {
  container_definitions = templatefile("${path.module}/templates/task_definitions/e2e_tests.json.tpl", {
    task_role_arn         = module.e2e_tests_ecs_task_role.role_arn
    execution_role_arn    = module.e2e_tests_ecs_execution_role.role_arn
    secret_name           = aws_secretsmanager_secret.preservica_secret.name
    environment           = local.environment
    account_id            = data.aws_caller_identity.current.account_id
    management_account_id = module.config.account_numbers["mgmt"]
  })
  execution_role_arn       = module.e2e_tests_ecs_execution_role.role_arn
  task_role_arn            = module.e2e_tests_ecs_task_role.role_arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  family                   = "e2e-tests"
  volume {
    name = "test"
  }
  volume {
    name = "tmp"
  }
}
