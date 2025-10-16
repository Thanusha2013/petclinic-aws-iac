# -------------------- NETWORKING --------------------

resource "aws_vpc" "spring_petclinic_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "spring-petclinic-vpc"
  }
}

resource "aws_internet_gateway" "spring_petclinic_igw" {
  vpc_id = aws_vpc.spring_petclinic_vpc.id
  tags   = { Name = "spring-petclinic-igw" }
}

# Two public subnets in different AZs
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.spring_petclinic_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-a" }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.spring_petclinic_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-b" }
}

# Route table and associations
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.spring_petclinic_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.spring_petclinic_igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

# -------------------- SECURITY GROUPS --------------------

# For ALB
resource "aws_security_group" "lb_sg" {
  name   = "lb-sg"
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

  tags = { Name = "lb-sg" }
}

# For ECS tasks
resource "aws_security_group" "ecs_sg" {
  name   = "ecs-sg"
  vpc_id = aws_vpc.spring_petclinic_vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ecs-sg" }
}

# -------------------- IAM ROLE --------------------

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskExecutionRole-petclinic"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -------------------- ECR --------------------

resource "aws_ecr_repository" "spring_petclinic" {
  name                 = "spring-petclinic"
  image_tag_mutability = "MUTABLE"
}

# -------------------- ECS CLUSTER --------------------

resource "aws_ecs_cluster" "spring_petclinic_cluster" {
  name = "spring-petclinic-cluster"
}

# -------------------- TASK DEFINITION --------------------

resource "aws_ecs_task_definition" "spring_petclinic_task" {
  family                   = "spring-petclinic-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "spring-petclinic"
      image = "${aws_ecr_repository.spring_petclinic.repository_url}:latest"
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# -------------------- LOAD BALANCER --------------------

resource "aws_lb" "spring_petclinic" {
  name               = "spring-petclinic-lb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  security_groups    = [aws_security_group.lb_sg.id]
}

resource "aws_lb_target_group" "spring_petclinic_tg" {
  name        = "spring-petclinic-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.spring_petclinic_vpc.id
  target_type = "ip"
}

resource "aws_lb_listener" "spring_petclinic_listener" {
  load_balancer_arn = aws_lb.spring_petclinic.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.spring_petclinic_tg.arn
  }
}

# -------------------- ECS SERVICE --------------------

resource "aws_ecs_service" "spring_petclinic" {
  name            = "spring-petclinic-service"
  cluster         = aws_ecs_cluster.spring_petclinic_cluster.id
  task_definition = aws_ecs_task_definition.spring_petclinic_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.spring_petclinic_tg.arn
    container_name   = "spring-petclinic"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.spring_petclinic_listener]
}

