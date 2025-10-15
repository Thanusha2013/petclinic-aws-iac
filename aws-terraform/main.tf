resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_kms_key" "spring_petclinic_init" {
  description             = "Spring Petclinic KMS Key"
  deletion_window_in_days = 30
  key_usage               = "ENCRYPT_DECRYPT"
}

resource "aws_kms_alias" "spring_petclinic_init_alias" {
  name          = "alias/spring-petclinic-init-${random_id.suffix.hex}"
  target_key_id = aws_kms_key.spring_petclinic_init.id
}

resource "aws_iam_role" "spring_petclinic_role" {
  name = "spring-petclinic-role-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "kms_decrypt_policy" {
  name        = "spring-petclinic-kms-policy-${random_id.suffix.hex}"
  description = "Allow decrypt using KMS key"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:Encrypt"]
      Resource = aws_kms_key.spring_petclinic_init.arn
    }]
  })
}

resource "aws_iam_policy" "spring_petclinic_storage_policy" {
  name        = "spring-petclinic-storage-policy-${random_id.suffix.hex}"
  description = "Policy to allow access to S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:DeleteObject"]
      Resource = ["arn:aws:s3:::springpetclinicstorage-${random_id.suffix.hex}/*"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_kms_policy" {
  role       = aws_iam_role.spring_petclinic_role.name
  policy_arn = aws_iam_policy.kms_decrypt_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.spring_petclinic_role.name
  policy_arn = aws_iam_policy.spring_petclinic_storage_policy.arn
}

resource "aws_s3_bucket" "spring_petclinic" {
  bucket = "springpetclinicstorage-${random_id.suffix.hex}"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.spring_petclinic_init.id
      }
    }
  }
}

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
        { containerPort = 8080, hostPort = 8080 }
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
  name        = "spring-petclinic-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
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

resource "aws_lb_target_group_attachment" "spring_petclinic_attachment" {
  target_group_arn = aws_lb_target_group.spring_petclinic_tg.arn
  target_id        = aws_ecs_service.spring_petclinic_service.id
  port             = 8080
}

variable "public_subnets" { type = list(string) }
variable "ecs_security_group_id" { type = string }
variable "lb_security_group_id" { type = string }
variable "vpc_id" { type = string }
variable "aws_region" { type = string, default = "us-east-1" }

output "kms_key_id" { value = aws_kms_key.spring_petclinic_init.id }
output "kms_key_arn" { value = aws_kms_key.spring_petclinic_init.arn }
output "iam_role_name" { value = aws_iam_role.spring_petclinic_role.name }
output "iam_role_arn" { value = aws_iam_role.spring_petclinic_role.arn }
output "s3_bucket_name" { value = aws_s3_bucket.spring_petclinic.bucket }
output "s3_bucket_arn" { value = aws_s3_bucket.spring_petclinic.arn }
output "ecr_repo_url" { value = aws_ecr_repository.spring_petclinic.repository_url }
output "ecs_cluster_name" { value = aws_ecs_cluster.spring_petclinic_cluster.name }
output "ecs_service_name" { value = aws_ecs_service.spring_petclinic_service.name }
output "alb_dns_name" { value = aws_lb.spring_petclinic_lb.dns_name }
