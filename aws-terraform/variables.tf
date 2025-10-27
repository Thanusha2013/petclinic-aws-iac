variable "app_name" {
  default = "spring-petclinic"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_a" {
  default = "10.0.1.0/24"
}

variable "public_subnet_b" {
  default = "10.0.2.0/24"
}
