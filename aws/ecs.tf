# Logging
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = var.project_name
  retention_in_days = 7
}

# SGs
resource "aws_security_group" "alb_sg" {
  depends_on  = [aws_vpc.vpc]
  name        = "${var.project_name}-alb-sg"
  description = "ALB SG"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow all HTTP to ALB"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_sg" {
  depends_on  = [aws_security_group.alb_sg]
  name        = "${var.project_name}-ecs-sg"
  description = "ECS SG"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Only allow ALB to ECS"
    from_port       = 0
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS

# Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.project_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_logs.name
      }
    }
  }
}

# Task
resource "aws_ecs_task_definition" "ecs_task_def" {
  depends_on               = [aws_iam_role.ecs_execution_role]
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  network_mode             = "awsvpc"
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
          awslogs-create-group  = "true",
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "${var.project_name}-task"
        }
      }
    }
  ])
}

# Service
resource "aws_ecs_service" "ecs_service" {
  depends_on      = [aws_ecs_cluster.ecs_cluster, aws_subnet.private_subnet, aws_lb_target_group.lb_target_group]
  name            = var.project_name
  cluster         = aws_ecs_cluster.ecs_cluster.id
  desired_count   = 2
  task_definition = aws_ecs_task_definition.ecs_task_def.arn
  launch_type     = "FARGATE"

  # capacity_provider_strategy {
  #   capacity_provider = 
  # }

  network_configuration {
    assign_public_ip = false
    subnets          = aws_subnet.private_subnet.*.id
    security_groups  = [aws_security_group.ecs_sg.id]
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

# LB
resource "aws_lb" "lb" {
  depends_on         = [aws_subnet.public_subnet]
  name               = "${var.project_name}-lb"
  load_balancer_type = "application"
  subnets            = aws_subnet.public_subnet.*.id
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_target_group" "lb_target_group" {
  depends_on  = [aws_vpc.vpc]
  name        = var.project_name
  target_type = "ip"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 30
    matcher             = 200
    path                = "/docs"
    port                = var.container_port
    protocol            = "HTTP"
    timeout             = 6
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "lb_listener" {
  depends_on        = [aws_lb_target_group.lb_target_group]
  port              = var.container_port
  protocol          = "HTTP"
  load_balancer_arn = aws_lb.lb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group.arn
  }
}

# IAM
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