terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Bucket com misconfiguration intencional (sem encryption, sem versioning)
# O checkov vai detectar e o pipeline vai falhar — isso é o objetivo
resource "aws_s3_bucket" "example" {
  bucket = var.bucket_name

  tags = {
    Environment = "dev"
    Project     = "pipeline-security-gates"
  }
}
