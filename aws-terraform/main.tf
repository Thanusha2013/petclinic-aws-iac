resource "aws_ecr_repository" "spring_petclinic" {
  name                 = "spring-petclinic"
  image_tag_mutability = "MUTABLE"
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.spring_petclinic_init.arn
  }
}

resource "aws_ecs_cluster" "spring_petclinic_cluster" {
  name = "spring-petclinic-cluster"
}

resource "aws_ecs_task_definition" "spring_petclinic_task" {
  family                   = "spring-petclinic-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.spring_petclinic_role.arn
  task_role_arn            = aws_iam_role.spring_petclinic_role.arn

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
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/spring-petclinic"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
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
    subnets         = var.public_subnets
    security_groups = [var.ecs_security_group_id]
    assign_public_ip = true
  }
  depends_on = [
    aws_iam_role_policy_attachment.attach_policy,
    aws_iam_role_policy_attachment.attach_kms_policy
  ]
}

resource "aws_lb" "spring_petclinic_lb" {
  name               = "spring-petclinic-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [var.lb_security_group_id]
}

resource "aws_lb_target_group" "spring_petclinic_tg" {
  name     = "spring-petclinic-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
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

resource "aws_lb_target_group_attachment" "spring_petclinic_attachment" {
  target_group_arn = aws_lb_target_group.spring_petclinic_tg.arn
  target_id        = aws_ecs_service.spring_petclinic_service.id
  port             = 8080
}
