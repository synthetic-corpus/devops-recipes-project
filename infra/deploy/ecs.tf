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
  path               = "/"
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
  memory                   = 1024
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.app_task.arn

  container_definitions = jsonencode(
    [
      {
        name              = "api"
        image             = var.ecr_app_image
        essential         = true
        memoryReservation = 256
        user              = "django-user"
        environment = [
          {
            name  = "DJANGO_SECRET_KEY"
            value = var.django_secret_key
          },
          {
            name  = "DB_HOST"
            value = aws_db_instance.main.address
          },
          {
            name  = "DB_NAME"
            value = aws_db_instance.main.db_name
          },
          {
            name  = "DB_USER"
            value = aws_db_instance.main.username
          },
          {
            name  = "DB_PASS"
            value = aws_db_instance.main.password
          },
          {
            name  = "ALLOWED_HOSTS"
            value = "*" # to be changed when Domain names declared
          }
        ]
        mountPoints = [
          {
            readOnly      = false
            containerPath = "/vol/web/static"
            sourceVolume  = "static"
          },
          {
            readOnly      = false
            containerPath = "/vol/web/media"
            sourceVolume  = "efs-media"
          }
        ],
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.ecs_task_logs.name
            awslogs-region        = data.aws_region.current.name
            awslogs-stream-prefix = "api"
          }
        }
      },
      {
        name              = "terra-proxy"
        image             = var.ecr_proxy_image
        essential         = true
        memoryReservation = 256
        user              = "nginx"
        portMappings = [
          {
            containerPort = 8000
            hostPort      = 8000
          }
        ]
        environment = [
          {
            name  = "APP_HOST"
            value = "127.0.0.1"
          }
        ]
        mountPoints = [
          {
            readOnly      = true
            containerPath = "/vol/static"
            sourceVolume  = "static"
          },
          {
            readOnly      = true
            containerPath = "/vol/web/media"
            sourceVolume  = "efs-media"
          }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.ecs_task_logs.name
            awslogs-region        = data.aws_region.current.name
            awslogs-stream-prefix = "terra-proxy"
          }
        }
      }
    ]
  )

  volume {
    name = "static"
  }

  volume {
    name = "efs-media"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.media.id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.media.id
        iam             = "DISABLED"
      }
    }
  }

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64" # must match what the docker is built for!
  }
}

resource "aws_security_group" "ecs_service" {
  description = "outgoing rules for ECS"
  name        = "${local.prefix}-ecs-service"
  vpc_id      = aws_vpc.main.id

  # Access to end points
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Access to RDS
  egress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    cidr_blocks = [
      aws_subnet.private_a.cidr_block,
      aws_subnet.private_b.cidr_block
    ]
  }

  # NFS port to the EFS
  egress {
    from_port = 2049
    to_port   = 2049
    protocol  = "tcp"
    cidr_blocks = [
      aws_subnet.private_a.cidr_block,
      aws_subnet.private_b.cidr_block
    ]
  }

  # Inbound access from internet via Load balancer
  ingress {
    from_port = 8000
    to_port   = 8000
    protocol  = "tcp"
    security_groups = [
      aws_security_group.loadbalancer.id
    ]
  }
}

resource "aws_ecs_service" "api" {
  name                   = "${local.prefix}-api"
  cluster                = aws_ecs_cluster.main.name
  task_definition        = aws_ecs_task_definition.api.family
  desired_count          = 1
  launch_type            = "FARGATE"
  platform_version       = "1.4.0"
  enable_execute_command = true

  network_configuration {

    subnets = [ # also atypical. Will eventually be behind a load balancer.
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_groups = [aws_security_group.ecs_service.id]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.api.arn
    container_name   = "terra-proxy"
    container_port   = 8000
  }
}