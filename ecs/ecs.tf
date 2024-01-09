terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = var.project_name
    }
  }
}

resource "aws_ecr_repository" "ecr-repo" {
  name                 = "${var.project_name}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.project_name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  configuration {
    execute_command_configuration {
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_log_group.name
      }
    }
  }
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name = "${var.project_name}-ecs"
  retention_in_days = 7
}

resource "aws_ecs_service" "ecs_service" {
  name            = var.project_name
  cluster         = aws_ecs_cluster.ecs_cluster.id
  desired_count   = 2
  task_definition = aws_ecs_task_definition.ecs_task_def.arn
  launch_type = "FARGATE"

  network_configuration {
    assign_public_ip = false
    subnets = data.aws_subnets.default_subnets.ids
    security_groups = [ aws_security_group.ecs_sg.id ]
  }
  
  deployment_controller {
    type = "ECS"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.lb_target_group.arn
    container_name   = var.project_name
    container_port   = var.container_port
  }
}

resource "aws_ecs_task_definition" "ecs_task_def" {
  family = var.project_name
  requires_compatibilities = ["FARGATE"]
  cpu = 256
  memory = 512
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  network_mode = "awsvpc"
  container_definitions = jsonencode([
    {
      name      = var.project_name
      image     = var.initial_image
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = var.container_port,
          hostPort      = var.container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group = "true",
          awslogs-group = aws_cloudwatch_log_group.ecs_log_group.name,
          awslogs-region = var.region,
          awslogs-stream-prefix = "${var.project_name}-task"
        }
      }
    }
  ])
}

resource "aws_lb" "lb" {
  name = "${var.project_name}-lb"
  load_balancer_type = "application"
  subnets = data.aws_subnets.default_subnets.ids
}

resource "aws_lb_target_group" "lb_target_group" {
  name = var.project_name
  target_type = "ip"
  port = 8080
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default_vpc.id
}

resource "aws_lb_listener" "lb_listener" {
  port = 80
  protocol = "HTTP"
  load_balancer_arn = aws_lb.lb.arn

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group.arn
  }
}

resource "aws_security_group" "ecs_sg" {
    name = "${var.project_name}-ecs-sg"
    description = "ECS SG"
    vpc_id = data.aws_vpc.default_vpc.id

    ingress {
        description = ""
        from_port = 80
        to_port = 80
        protocol = "http"
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
}

data "aws_subnets" "default_subnets" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

data "aws_vpc" "default_vpc" {
  default = true
}

resource "aws_iam_role" "ecs_execution_role" {
  name               = "${var.project_name}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role_policy_doc.json
}

data "aws_iam_policy_document" "ecs_tasks_assume_role_policy_doc" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "ecs_tasks_role_policy" {
  role   = aws_iam_role.ecs_execution_role.name
  policy = data.aws_iam_policy_document.ecs_tasks_policy_doc.json
}

data "aws_iam_policy_document" "ecs_tasks_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
}