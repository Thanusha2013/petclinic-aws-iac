resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow MySQL inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
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

resource "aws_db_subnet_group" "spring_petclinic_db_subnet_group" {
  name       = "spring-petclinic-db-subnet-group"
  subnet_ids = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

resource "aws_db_instance" "spring_petclinic_rds" {
  identifier              = "spring-petclinic-db"
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  db_name                 = "petclinic"
  username                = "admin"
  password                = "password123"
  parameter_group_name    = "default.mysql8.0"
  skip_final_snapshot     = true
  db_subnet_group_name    = aws_db_subnet_group.spring_petclinic_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  publicly_accessible     = true
}

resource "aws_ecr_repository" "spring_petclinic_repo" {
  name = "spring-petclinic"
}

resource "aws_ecs_cluster" "spring_petclinic_cluster" {
  name = "spring-petclinic-cluster"
}

resource "aws_ecs_task_definition" "spring_petclinic_task" {
  family                   = "spring-petclinic-task"
  requires_compatibilities  = ["FARGATE"]
  network_mode              = "awsvpc"
  cpu                       = "512"
  memory                    = "1024"

  container_definitions = jsonencode([{
    name      = "spring-petclinic"
    image     = "${aws_ecr_repository.spring_petclinic_repo.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
  }])
}

resource "aws_ecs_service" "spring_petclinic_service" {
  name            = "spring-petclinic-service"
  cluster         = aws_ecs_cluster.spring_petclinic_cluster.id
  task_definition = aws_ecs_task_definition.spring_petclinic_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.rds_sg.id]
  }
}
