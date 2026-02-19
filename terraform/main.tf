# Terraform and provider version constraints
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# AWS provider configuration
provider "aws" {
  region = var.region
}

# Random suffix to avoid bucket name collisions
resource "random_id" "suffix" {
  byte_length = 4
}

# Common local values used across the stack
locals {
  name_suffix = random_id.suffix.hex
  project     = var.project_name

  common_tags = {
    Project = var.project_name
    Managed = "terraform"
  }

  lambda_artifacts_dir = "${path.module}/${var.lambda_artifacts_dir}"
}
