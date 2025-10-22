resource "aws_vpc" "spring_petclinic_vpc" {
  cidr_block = var.vpc_cidr
  tags = { Name = "spring-petclinic-vpc" }
}

resource "aws_subnet" "spring_petclinic_subnets" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.spring_petclinic_vpc.id
  cidr_block              = var.public_subnets[count.index]
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  tags = { Name = "spring-petclinic-subnet-${count.index}" }
}

data "aws_availability_zones" "available" {}

resource "aws_internet_gateway" "spring_petclinic_igw" {
  vpc_id = aws_vpc.spring_petclinic_vpc.id
}

resource "aws_route_table" "spring_petclinic_rt" {
  vpc_id = aws_vpc.spring_petclinic_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.spring_petclinic_igw.id
  }
}

resource "aws_route_table_association" "spring_petclinic_assoc" {
  count          = length(aws_subnet.spring_petclinic_subnets)
  subnet_id      = aws_subnet.spring_petclinic_subnets[count.index].id
  route_table_id = aws_route_table.spring_petclinic_rt.id
}

resource "aws_security_group" "spring_petclinic_sg" {
  vpc_id = aws_vpc.spring_petclinic_vpc.id

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

  tags = { Name = "spring-petclinic-sg" }
}

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.spring_petclinic_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.spring_petclinic_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "spring-petclinic-rds-sg" }
}

resource "aws_ecr_repository" "spring_petclinic" {
  name = "spring-petclinic"
}

resource "aws_ecs_cluster" "spring_petclinic_cluster" {
  name = "spring-petclinic-cluster"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_db_subnet_group" "spring_petclinic_db_subnet_group" {
  name       = "spring-petclinic-db-subnet-group"
  subnet_ids = [for subnet in aws_subnet.spring_petclinic_subnets : subnet.id]
}

resource "aws_db_instance" "spring_petclinic_rds" {
  identifier              = "spring-petclinic-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "petclinic"
  username                = var.db_username
  password                = var.db_password
  publicly_accessible     = false
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.spring_petclinic_db_subnet_group.name
  deletion_protection     = false

  tags = { Name = "spring-petclinic-db" }
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
      portMappings = [{ containerPort = 8080, hostPort = 8080 }]
      environment = [
        { name = "SPRING_DATASOURCE_URL", value = "jdbc:mysql://${aws_db_instance.spring_petclinic_rds.address}:3306/petclinic" },
        { name = "SPRING_DATASOURCE_USERNAME", value = var.db_username },
        { name = "SPRING_DATASOURCE_PASSWORD", value = var.db_password }
      ]
    }
  ])
}

resource "aws_lb" "spring_petclinic_lb" {
  name               = "spring-petclinic-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [for subnet in aws_subnet.spring_petclinic_subnets : subnet.id]
  security_groups    = [aws_security_group.spring_petclinic_sg.id]
}

resource "aws_lb_target_group" "spring_petclinic_tg" {
  name        = "spring-petclinic-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.spring_petclinic_vpc.id
  target_type = "ip"
}

resource "aws_lb_listener" "spring_petclinic_listener" {
  load_balancer_arn = aws_lb.spring_petclinic_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.spring_petclinic_tg.arn
  }
}

resource "aws_ecs_service" "spring_petclinic_service" {
  name            = "spring-petclinic-service"
  cluster         = aws_ecs_cluster.spring_petclinic_cluster.id
  task_definition = aws_ecs_task_definition.spring_petclinic_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [for subnet in aws_subnet.spring_petclinic_subnets : subnet.id]
    security_groups  = [aws_security_group.spring_petclinic_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.spring_petclinic_tg.arn
    container_name   = "spring-petclinic"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.spring_petclinic_listener]
}
