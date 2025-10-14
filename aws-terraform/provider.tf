terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # latest stable AWS provider
    }
  }
}


provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = var.aws_vpc_name
  }
}

variable "aws_vpc_name" {
  default = "spring-petclinic-vpc"
}

