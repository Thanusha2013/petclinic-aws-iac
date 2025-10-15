variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "db_password" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "lb_security_group_id" {
  type = string
}

variable "ecs_security_group_id" {
  type = string
}
