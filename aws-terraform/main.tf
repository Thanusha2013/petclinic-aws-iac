resource "aws_vpc" "spring_petclinic_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "spring-petclinic-vpc"
  }
}

resource "aws_internet_gateway" "spring_petclinic_igw" {
  vpc_id = aws_vpc.spring_petclinic_vpc.id
}

resource "aws_subnet" "spring_petclinic_subnets" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.spring_petclinic_vpc.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "spring-petclinic-subnet-${count.index}"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_route_table" "spring_petclinic_rt" {
  vpc_id = aws_vpc.spring_petclinic_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.spring_petclinic_igw.id
  }
}

resource "aws_route_table_association" "spring_petclinic_rta" {
  count          = length(aws_subnet.spring_petclinic_subnets)
  subnet_id      = aws_subnet.spring_petclinic_subnets[count.index].id
  route_table_id = aws_route_table.spring_petclinic_rt.id
}

resource "aws_security_group" "spring_petclinic_sg" {
  vpc_id = aws_vpc.spring_petclinic_vpc.id

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

  tags = {
    Name = "spring-petclinic-sg"
  }
}

resource "aws_ecr_repository" "spring_petclinic" {
  name                 = "spring-petclinic"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecs_cluster" "spring_petclinic_cluster" {
  name = "spring-petclinic-cluster"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "spring-petclinic-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_lb" "spring_petclinic_lb" {
  name               = "spring-petclinic-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.spring_petclinic_sg.id]
  subnets            = [for subnet in aws_subnet.spring_petclinic_subnets : subnet.id]
}

resource "aws_lb_target_group" "spring_petclinic_tg" {
  name     = "spring-petclinic-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.spring_petclinic_vpc.id
  health_check {
    path = "/"
  }
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

resource "aws_ecs_task_definition" "spring_petclinic_task" {
  family                   = "spring-petclinic-task"
  network_mode              = "awsvpc"
  requires_compatibilities  = ["FARGATE"]
  cpu                       = "512"
  memory                    = "1024"
  execution_role_arn        = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([
    {
      name      = "spring-petclinic"
      image     = "${aws_ecr_repository.spring_petclinic.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "spring_petclinic_service" {
  name            = "spring-petclinic-service"
  cluster         = aws_ecs_cluster.spring_petclinic_cluster.id
  task_definition = aws_ecs_task_definition.spring_petclinic_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    assign_public_ip = true
    subnets          = [for subnet in aws_subnet.spring_petclinic_subnets : subnet.id]
    security_groups  = [aws_security_group.spring_petclinic_sg.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.spring_petclinic_tg.arn
    container_name   = "spring-petclinic"
    container_port   = 8080
  }
  depends_on = [aws_lb_listener.spring_petclinic_listener]
}
