variable "aws_region" {
  description = "AWS region hosting the EKS cluster."
  type        = string
  default     = "ap-southeast-1"
}

variable "state_bucket" {
  description = "S3 bucket containing the Terraform infrastructure state."
  type        = string
}

variable "infrastructure_state_key" {
  description = "S3 key for the existing AWS infrastructure state."
  type        = string
  default     = "myapp/production/terraform.tfstate"
}

variable "aws_load_balancer_controller_chart_version" {
  description = "Helm chart version for the AWS Load Balancer Controller."
  type        = string
  default     = "3.5.0"
}

variable "metrics_server_chart_version" {
  description = "Helm chart version for Metrics Server."
  type        = string
  default     = "3.14.0"
}

variable "external_secrets_chart_version" {
  description = "Helm chart version for External Secrets Operator."
  type        = string
  default     = "2.11.0"
}