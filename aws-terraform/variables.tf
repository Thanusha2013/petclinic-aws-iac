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

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
  default = ["subnet-abc123", "subnet-def456"]
}

variable "ecs_security_group_id" {
  description = "Security Group ID for ECS tasks"
  type        = string
}

variable "lb_security_group_id" {
  description = "Security Group ID for Load Balancer"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for Load Balancer Target Group"
  type        = string
}
