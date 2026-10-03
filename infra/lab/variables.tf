variable "aws_region" {
  description = "AWS region for the disposable lab."
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_account_id" {
  description = "Expected AWS account ID; used to scope IAM ARNs and the GitHub OIDC provider."
  type        = string
  default     = "725673805051"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "availability_zones" {
  description = "Two account-visible AZ names in ap-southeast-1. Verify them after AWS SSO login."
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]

  validation {
    condition     = length(var.availability_zones) == 2 && length(toset(var.availability_zones)) == 2
    error_message = "Exactly two distinct availability zones are required."
  }
}

variable "github_repository" {
  description = "GitHub repository in owner/name form; OIDC trust is limited to its develop branch."
  type        = string
  default     = "lit123op/myapp-fullstack"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be owner/name."
  }
}

variable "alert_email" {
  description = "Email recipient for lab SNS and AWS Budget alerts."
  type        = string
  default     = "belandrialiti@gmail.com"
}

variable "offline_plan" {
  description = "Only for a local plan with no AWS credentials: skips provider credential/account validation. Never use for apply."
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "Dedicated lab VPC CIDR; must not overlap any connected network."
  type        = string
  default     = "10.42.0.0/16"
}

variable "enable_multi_az" {
  description = "Temporary lab Stage 1 flag: keep the RDS primary single-AZ for the free-tier lab; set true only for the later Multi-AZ Stage 2 design."
  type        = bool
  default     = false
}

variable "enable_read_replica" {
  description = "Temporary lab Stage 1 flag: disable the async read replica while validating the Single-AZ architecture; re-enable in Stage 2."
  type        = bool
  default     = false
}

variable "db_instance_class" {
  description = "Free-plan-compatible RDS PostgreSQL class for the temporary Single-AZ lab. db.t4g.micro is preferred where supported; switch back to the larger Multi-AZ class in Stage 2."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Disposable lab database name, matching the current application's connection configuration."
  type        = string
  default     = "App"
}

variable "frontend_image_tag" {
  description = "Existing lab-built frontend image tag in the lab ECR repository. Build it with API URL /api before enabling services."
  type        = string
  default     = "lab"
}

variable "api_image_tag" {
  description = "Existing API image tag in the lab ECR repository."
  type        = string
  default     = "lab"
}

variable "frontend_cpu" {
  description = "Fargate frontend task CPU units; tunable lab value."
  type        = number
  default     = 256
}

variable "frontend_memory" {
  description = "Fargate frontend task memory in MiB; tunable lab value."
  type        = number
  default     = 512
}

variable "api_cpu" {
  description = "Fargate API task CPU units; 512 is a cautious tunable default for the .NET 9 + EF Core app."
  type        = number
  default     = 512
}

variable "api_memory" {
  description = "Fargate API task memory in MiB; 1024 is a cautious tunable default, not a measured minimum."
  type        = number
  default     = 1024
}

variable "ecs_min_tasks" {
  description = "Minimum tasks per ECS service."
  type        = number
  default     = 1
}

variable "ecs_desired_tasks" {
  description = "Initial desired tasks per ECS service."
  type        = number
  default     = 1
}

variable "frontend_max_tasks" {
  description = "Maximum frontend tasks during the lab."
  type        = number
  default     = 2
}

variable "api_max_tasks" {
  description = "Maximum API tasks. Keep at 1 until the one-off ECS migration workflow is running safely."
  type        = number
  default     = 1
}

variable "ecs_cpu_target" {
  description = "ECS target-tracking average CPU utilization percentage."
  type        = number
  default     = 60
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GiB."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "RDS storage autoscaling ceiling in GiB; growth is not reversible in place."
  type        = number
  default     = 40
}