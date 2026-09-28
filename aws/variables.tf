variable "aws_region" {
  description = "AWS region for the production environment."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Short, lowercase prefix used to name AWS resources."
  type        = string
  default     = "myapp"
}

variable "github_repository" {
  description = "GitHub repository in owner/name form, used to scope the OIDC trust policy."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Set github_repository to the exact owner/repository name."
  }
}

variable "github_owner_id" {
  description = "Immutable numeric GitHub owner ID used in the OIDC subject claim."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_owner_id))
    error_message = "Set github_owner_id to the numeric GitHub owner ID."
  }
}

variable "github_repository_id" {
  description = "Immutable numeric GitHub repository ID used in the OIDC subject claim."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "Set github_repository_id to the numeric GitHub repository ID."
  }
}

variable "github_environments" {
  description = "GitHub Environments allowed to assume the deployment role."
  type        = set(string)
  default     = ["production"]
}

variable "cluster_version" {
  description = "EKS Kubernetes version; verify it is supported in the chosen AWS region before applying."
  type        = string
  default     = "1.35"
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group."
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 5
}

variable "db_instance_class" {
  description = "Instance class for both the Multi-AZ writer and the read replica. Review AWS costs before applying."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage_gb" {
  type    = number
  default = 50
}

variable "db_name" {
  type    = string
  default = "App"
}

variable "db_username" {
  description = "Initial RDS master username; its generated password is managed by RDS Secrets Manager integration."
  type        = string
  default     = "app_admin"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "existing_github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN, if the AWS account already has one."
  type        = string
  default     = null
}