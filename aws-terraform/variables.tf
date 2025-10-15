variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "aws_vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "my-app-vpc"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "lb_security_group_id" {
  description = "Security Group ID for Load Balancer"
  type        = string
  default     = "sg-0123456789abcdef"
}

variable "vpc_id" {
  description = "VPC ID for Load Balancer Target Group"
  type        = string
  default     = "vpc-0507b6e5de315e7e2"
}
