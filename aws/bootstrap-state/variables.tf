variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name dedicated to Terraform state."
  type        = string

  validation {
    condition     = length(var.state_bucket_name) >= 3 && length(var.state_bucket_name) <= 63
    error_message = "state_bucket_name must be a globally unique S3-compatible bucket name."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}