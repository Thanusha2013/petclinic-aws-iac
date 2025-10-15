variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  description = "Database password for the application"
  type        = string
  default     = "MyS3cureP@ssw0rd!"
}
