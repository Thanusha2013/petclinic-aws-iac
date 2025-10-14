variable "create_vpc" {
  type        = bool
  description = "Specify if you want to create a VPC. Accepted values are true or false."
  default     = true
}

variable "aws_region" {
  type        = string
  description = "The AWS region where resources should be created, e.g., us-east-1, us-west-2."
  default     = "us-east-1"
}

variable "aws_vpc_name" {
  type        = string
  description = "The name tag for the AWS VPC."
  default     = "spring-petclinic-vpc"
}
