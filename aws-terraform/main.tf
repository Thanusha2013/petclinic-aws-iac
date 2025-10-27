terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.8.0"
}

provider "aws" {
  region = var.region
}

# ------------------------------
# VPC and Networking
# ------------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "spring-petclinic-vpc"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "spring-petclinic-subnet-1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "spring-petclinic-subnet-2"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "spring-petclinic-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "spring-petclinic-rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------
# Security Group
# ------------------------------
resource "aws_security_group" "app_sg" {
  name        = "spring-petclinic-sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
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

  tags = {
    Name = "spring-petclinic-sg"
  }
}

# ------------------------------
# ECR Repository
# ------------------------------
resource "aws_ecr_repository" "repo" {
  name = "spring-petclinic"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "spring-petclinic"
  }
}

# ------------------------------
# ECS Cluster
# ------------------------------
resource "aws_ecs_cluster" "cluster" {
  name = "spring-petclinic-cluster"
}

# ------------------------------
# ECS Task Definition
# ------------------------------
resource "aws_ecs_task_definition" "task" {
  family                   = "spring-petclinic-task"
  network_mode              = "awsvpc"
  requires_compatibilities  = ["FARGATE"]
  cpu                       = "512"
  memory                    = "1024"

  container_definitions = jsonencode([
    {
      name  = "spring-petclinic"
      image = "${aws_ecr_repository.repo.repository_url}:latest"
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# ------------------------------
# ECS Service
# ------------------------------
resource "aws_ecs_service" "service" {
  name            = "spring-petclinic-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
    security_groups  = [aws_security_group.app_sg.id]
    assign_public_ip = true
  }

  depends_on = [aws_ecs_task_definition.task]
}
