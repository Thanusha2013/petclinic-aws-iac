variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_vpc_name" {
  type    = string
  default = "spring-petclinic-vpc"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "ecs_security_group_name" {
  type    = string
  default = "ecs-sg"
}

variable "lb_security_group_name" {
  type    = string
  default = "lb-sg"
}

variable "db_password" {
  type    = string
  description = "Database password for the application"
}
