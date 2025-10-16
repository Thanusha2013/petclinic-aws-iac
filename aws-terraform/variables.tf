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

variable "app_name" {
  type    = string
  default = "spring-petclinic"
}
