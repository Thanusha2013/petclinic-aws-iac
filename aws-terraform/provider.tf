provider "aws" {
  region = "us-east-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "spring-pet-clinic-01"
    key    = "petclinic/terraform.tfstate"
    region = "us-east-1"
  }
}
