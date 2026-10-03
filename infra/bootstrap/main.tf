terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

locals {
  bucket_name = "belandria-lab-tfstate-725673805051"
  tags = {
    Name        = local.bucket_name
    Project     = "belandria"
    Environment = "lab"
    ManagedBy   = "terraform"
    Purpose     = "terraform-state-bootstrap"
    Role        = "state-bucket"
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.bucket_name

  tags = local.tags
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "terraform_state" {
  depends_on = [aws_s3_bucket_ownership_controls.terraform_state]

  bucket = aws_s3_bucket.terraform_state.id
  acl    = "private"
}

output "terraform_state_bucket_name" {
  description = "Terraform state bucket created by the bootstrap stage. This bucket remains after lab teardown."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_bucket_arn" {
  description = "ARN of the bootstrap S3 state bucket."
  value       = aws_s3_bucket.terraform_state.arn
}
