variable "project_name" {
description = "Project name for tagging"
type        = string
default     = "spring-petclinic"
}

variable "app_port" {
description = "Port that the container listens on"
type        = number
default     = 8080
}
