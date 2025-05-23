##############################
# ECS Cluster for Fargate :) #
##############################

resource "aws_iam_policy" "task_execution_role_policy" {
  name        = "${local.prefix}-task-exec-role-policy"
  path        = "/"
  description = "Allow ECS to retrieve docker images and write to cloud watch"
  policy      = file("./templates/ecs/task-execution-role-policy.json")
}

resource "aws_iam_role" "task_execution_role" {
  name               = "${local.prefix}-task-assume-role"
  path               = "/"
  description        = "Allow ECS to take on any policy whatsoever"
  assume_role_policy = file("./templates/ecs/task-assume-role-policy.json")
}

resource "aws_iam_role_policy_attachment" "task_execution_role" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.task_execution_role_policy.arn
}


resource "aws_iam_role" "app_task" {
  name               = "${local.prefix}-app-task"
  assume_role_policy = file("./templates/ecs/task-assume-role-policy.json")
}

resource "aws_iam_policy" "task_ssm_policy" {
  name        = "${local.prefix}-task-ssm-role-policy"
  path        = "/"
  description = "Policy to allow System Manager to execute in container"
  policy      = file("./templates/ecs/task-ssm-policy.json")
}

resource "aws_iam_role_policy_attachment" "task_ssm_policy" {
  role       = aws_iam_role.app_task.name
  policy_arn = aws_iam_policy.task_ssm_policy.arn
}

#############################################
# If we wished to add more policys to roles #
# do so starting below this block.          #
#############################################

resource "aws_cloudwatch_log_group" "ecs_task_logs" {
  name = "${local.prefix}-terra-api"
}

resource "aws_ecs_cluster" "main" {
  name = "${local.prefix}-cluster"
}

###############################
# Actual Tasks related to ECS #
###############################

resource "aws_ecs_task_definition" "api" {
  family                   = "${local.prefix}-api"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  network_mode             = "awsvpc"
  memory                   = 1048
  execution_role_arn       = aws_iam_policy.task_execution_role_policy.arn
  task_role_arn            = aws_iam_role.app_task.arn

  container_definitions = jsondecode([])

  volume {
    name = "static"
  }

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64" # must match what the docker is built for!
  }
}