# ---------------- VPC & Subnets ----------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = var.aws_vpc_name }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "${var.app_name}-public-${count.index}" }
}

data "aws_availability_zones" "available" {}

# ---------------- Security Groups ----------------
resource "aws_security_group" "ecs_sg" {
  name        = "${var.app_name}-ecs-sg"
  description = "ECS tasks security group"
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

resource "aws_security_group" "lb_sg" {
  name        = "${var.app_name}-lb-sg"
  description = "Load Balancer security group"
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

# ---------------- KMS & S3 ----------------
resource "aws_kms_key" "spring_petclinic_init" {
  description             = "KMS key for ECR encryption"
  deletion_window_in_days = 7
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "spring_petclinic" {
  bucket = "${var.app_name}-${random_id.bucket_suffix.hex}"
  acl    = "private"
}

# ---------------- IAM Role ----------------
resource "aws_iam_role" "spring_petclinic_role" {
  name = "${var.app_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_policy" {
  role       = aws_iam_role.spring_petclinic_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------- ECS Cluster ----------------
resource "aws_ecs_cluster" "spring_petclinic_cluster" {
  name = "${var.app_name}-cluster"
}

# ---------------- ECR Repository ----------------
resource "aws_ecr_repository" "spring_petclinic" {
  name = var.app_name
  image_tag_mutability = "MUTABLE"
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.spring_petclinic_init.arn
  }
}

# ---------------- ECS Task Definition ----------------
resource "aws_ecs_task_definition" "spring_petclinic_task" {
  family                   = "${var.app_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.spring_petclinic_role.arn
  task_role_arn            = aws_iam_role.spring_petclinic_role.arn

  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = "${aws_ecr_repository.spring_petclinic.repository_url}:latest"
      essential = true
      portMappings = [{ containerPort = 8080, hostPort = 8080 }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.app_name}"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# ---------------- Load Balancer ----------------
resource "aws_lb" "spring_petclinic_lb" {
  name               = "${var.app_name}-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.lb_sg.id]
}

resource "aws_lb_target_group" "spring_petclinic_tg" {
  name        = "${var.app_name}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
}

resource "aws_lb_listener" "spring_petclinic_listener" {
  load_balancer_arn = aws_lb.spring_petclinic_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.spring_petclinic_tg.arn
  }
}

# ---------------- ECS Service ----------------
resource "aws_ecs_service" "spring_petclinic_service" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.spring_petclinic_cluster.id
  task_definition = aws_ecs_task_definition.spring_petclinic_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.spring_petclinic_tg.arn
    container_name   = var.app_name
    container_port   = 8080
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_policy]
}
