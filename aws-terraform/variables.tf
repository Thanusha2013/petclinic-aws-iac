variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_vpc_name" {
  description = "VPC Name"
  type        = string
  default     = "spring-petclinic-vpc"
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
  default     = ["subnet-08d374972b20eb81a", "subnet-0625e97ec5ba9dddb"]
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
  default     = ["vpc-0507b6e5de315e7e2"]
}
