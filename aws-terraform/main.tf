# generate a short random suffix to avoid naming collisions with existing resources
resource "random_id" "suffix" {
  byte_length = 3
}

# ----------------------------
# VPC
# ----------------------------
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = var.aws_vpc_name }
}

# Internet Gateway for public subnets
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.aws_vpc_name}-igw" }
}

# ----------------------------
# Subnets
# ----------------------------
data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  tags = { Name = "${var.aws_vpc_name}-public-${count.index}" }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = { Name = "${var.aws_vpc_name}-private-${count.index}" }
}

# ----------------------------
# Route Table for public subnets
# ----------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ----------------------------
# Security Groups
# ----------------------------
resource "aws_security_group" "ecs_sg" {
  name        = "ecs_sg-${random_id.suffix.hex}"
  description = "Allow HTTP traffic to ECS tasks"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

  tags = { Name = "ecs-sg-${random_id.suffix.hex}" }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds_sg-${random_id.suffix.hex}"
  description = "Allow DB traffic from ECS tasks only"
  vpc_id      = aws_vpc.this.id

  # allow inbound from ECS security group
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rds-sg-${random_id.suffix.hex}" }
}

# ----------------------------
# RDS DB Subnet Group (unique name to avoid collision)
# ----------------------------
resource "aws_db_subnet_group" "spring_petclinic_db_subnet_group" {
  name       = "spring-petclinic-db-subnet-${random_id.suffix.hex}"
  subnet_ids = aws_subnet.private[*].id
  tags = { Name = "spring-petclinic-db-subnet-${random_id.suffix.hex}" }
}

# ----------------------------
# RDS DB Instance (identifier with suffix)
# ----------------------------
resource "aws_db_instance" "spring_petclinic_rds" {
  identifier              = "spring-petclinic-db-${random_id.suffix.hex}"
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.spring_petclinic_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  publicly_accessible     = false
  skip_final_snapshot     = true
  tags = { Name = "spring-petclinic-db-${random_id.suffix.hex}" }
}

# ----------------------------
# IAM Role for ECS task execution (unique name)
# ----------------------------
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ----------------------------
# ECS Cluster (unique)
# ----------------------------
resource "aws_ecs_cluster" "spring_petclinic" {
  name = "spring-petclinic-cluster-${random_id.suffix.hex}"
}

# ----------------------------
# ECR Repository (unique)
# ----------------------------
resource "aws_ecr_repository" "spring_petclinic" {
  name = "spring-petclinic-${random_id.suffix.hex}"
}
