# Security Groups
resource "aws_security_group" "ecs" {
  name        = "ecs-sg"
  description = "Allow HTTP for ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
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

resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Allow HTTP for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
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

# KMS Key
resource "aws_kms_key" "spring_petclinic" {
  description             = "Spring Petclinic KMS Key"
  deletion_window_in_days = 30
  key_usage               = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
}

# S3 Bucket
resource "aws_s3_bucket" "spring_petclinic" {
  bucket = "springpetclinicstorage-${random_id.suffix.hex}"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.spring_petclinic.id
      }
    }
  }
}

# IAM Role for ECS
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_policy_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "random_id" "suffix" { byte_length = 4 }

# ECR Repository
resource "aws_ecr_repository" "spring_petclinic" {
  name = "spring-petclinic"
  image_tag_mutability = "MUTABLE"
}

# ECS Cluster
resource "aws_ecs_cluster" "spring_petclinic" {
  name = "spring-petclinic-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "spring_petclinic" {
  family                   = "spring-petclinic-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  execution_role_arn       = aws_iam_role.ecs_task_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "spring-petclinic"
    image     = "${aws_ecr_repository.spring_petclinic.repository_url}:latest"
    essential = true
    portMappings = [{ containerPort = 8080, hostPort = 8080 }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/spring-petclinic"
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# ALB
resource "aws_lb" "spring_petclinic" {
  name               = "spring-petclinic-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "spring_petclinic" {
  name     = "spring-petclinic-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"
}

resource "aws_lb_listener" "spring_petclinic" {
  load_balancer_arn = aws_lb.spring_petclinic.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.spring_petclinic.arn
  }
}

# ECS Service
resource "aws_ecs_service" "spring_petclinic" {
  name            = "spring-petclinic-service"
  cluster         = aws_ecs_cluster.spring_petclinic.id
  task_definition = aws_ecs_task_definition.spring_petclinic.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.spring_petclinic.arn
    container_name   = "spring-petclinic"
    container_port   = 8080
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_policy_attach
  ]
}
