# ------------------ RDS Security Group ------------------
resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.spring_petclinic_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.spring_petclinic_sg.id] # allow ECS tasks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "spring-petclinic-rds-sg"
  }
}

# ------------------ RDS MySQL Instance ------------------
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

  tags = {
    Name = "spring-petclinic-db"
  }
}

# ------------------ Update ECS Task Definition ------------------
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
      environment = [
        {
          name  = "SPRING_DATASOURCE_URL"
          value = "jdbc:mysql://${aws_db_instance.spring_petclinic_rds.address}:3306/petclinic"
        },
        {
          name  = "SPRING_DATASOURCE_USERNAME"
          value = var.db_username
        },
        {
          name  = "SPRING_DATASOURCE_PASSWORD"
          value = var.db_password
        }
      ]
    }
  ])
}
