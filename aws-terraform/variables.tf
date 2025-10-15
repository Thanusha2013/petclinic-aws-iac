variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_vpc_name" {
  type    = string
  default = "spring-petclinic-vpc"
}

variable "ecs_security_group_id" {
  type    = string
}

variable "lb_security_group_id" {
  type    = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}
