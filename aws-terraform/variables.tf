variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_vpc_name" {
  type    = string
  default = "spring-petclinic-vpc"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "ecs_cpu" {
  type    = string
  default = "512"
}

variable "ecs_memory" {
  type    = string
  default = "1024"
}

variable "desired_count" {
  type    = number
  default = 1
}
