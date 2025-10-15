resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "spring-petclinic-vpc"
  }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "spring-petclinic-igw" }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "spring-petclinic-public-${count.index + 1}" }
}

data "aws_availability_zones" "available" {}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "spring-petclinic-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}

# -------------------
# Security Groups
# -------------------
resource "aws_security_group" "ecs_sg" {
  name        = "spring-petclinic-ecs-sg"
  description = "ECS tasks SG"
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
  name        = "spring-petclinic-lb-sg"
  description = "Load Balancer SG"
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

# -------------------
# IAM Roles, KMS, S3
# -------------------
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_kms_key" "spring_petclinic" {
  description             = "Spring Petclinic KMS Key"
  deletion_window_in_days = 30
  key_usage               = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "spring-petclinic-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "s3_policy" {
  name        = "spring-petclinic-s3-policy-${random_id.suffix.hex}"
  description = "Allow ECS to access S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
      Resource = ["arn:aws:s3:::springpetclinicstorage-${random_id.suffix.hex}/*"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_s3_bucket" "spring_petclinic" {
  bucket = "springpetclinicstorage-${random_id.suffix.hex}"
  acl    = "private"

  versioning { enabled = true }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.spring_petclinic.id
      }
    }
  }
}

# -------------------
# ECR & ECS
# -------------------
resource "aws_ecr_repository" "spring_petclinic" {
  name = "spring-petclinic"
  image_tag_mutability = "MUTABLE"
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.spring_petclinic.arn
  }
}

resource "aws_ecs_cluster" "spring_petclinic" {
  name = "spring-petclinic-cluster"
}

resource "aws_ecs_task_definition" "spring_petclinic" {
  family                   = "spring-petclinic-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "spring-petclinic"
    image     = "${aws_ecr_repository.spring_petclinic.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
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

resource "aws_ecs_service" "spring_petclinic" {
  name            = "spring-petclinic-service"
  cluster         = aws_ecs_cluster.spring_petclinic.id
  task_definition = aws_ecs_task_definition.spring_petclinic.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  depends_on = [aws_iam_role_policy_attachment.s3_attach]
}

# -------------------
# Load Balancer
# -------------------
resource "aws_lb" "spring_petclinic" {
  name               = "spring-petclinic-lb"
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.lb_sg.id]
}

resource "aws_lb_target_group" "spring_petclinic" {
  name        = "spring-petclinic-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
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

resource "aws_lb_target_group_attachment" "spring_petclinic" {
  target_group_arn = aws_lb_target_group.spring_petclinic.arn
  target_id        = aws_ecs_service.spring_petclinic.id
  port             = 8080
}
