terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.2"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  required_version = ">= 1.2.0"
}

# Configure the AWS provider with credentials and region
provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["${var.HOME}/.aws/credentials"]
}
