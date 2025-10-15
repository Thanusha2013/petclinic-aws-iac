variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "db_password" {
  type = string
}

variable "ecs_cpu" {
  type    = string
  default = "512"
}

variable "ecs_memory" {
  type    = string
  default = "1024"
}
