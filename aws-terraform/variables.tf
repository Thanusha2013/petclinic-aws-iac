variable "aws_region" {
  default = "us-east-1"
}

variable "aws_vpc_name" {
  default = "spring-petclinic-vpc"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "ecs_cpu" {
  default = "512"
}

variable "ecs_memory" {
  default = "1024"
}

variable "desired_count" {
  default = 2
}
