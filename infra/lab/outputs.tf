output "alb_url" {
  description = "Temporary HTTP lab URL. No Route 53 record is created."
  value       = "http://${aws_lb.lab.dns_name}"
}

output "frontend_ecr_repository_url" {
  description = "Push the lab-built Angular image here after creating ECR and before starting the service."
  value       = aws_ecr_repository.frontend.repository_url
}

output "api_ecr_repository_url" {
  description = "Push the API image here after creating ECR and before starting the service."
  value       = aws_ecr_repository.api.repository_url
}

output "rds_writer_endpoint" {
  description = "Stable RDS writer endpoint; Multi-AZ failover changes the underlying primary, not this DNS name."
  value       = aws_db_instance.primary.endpoint
}

output "rds_read_replica_endpoint" {
  description = "Separate asynchronous replica endpoint; disabled in the temporary Stage 1 Single-AZ lab."
  value       = var.enable_read_replica ? aws_db_instance.read_replica[0].endpoint : null
}

output "github_develop_role_arn" {
  description = "Lab-only GitHub OIDC role restricted to the repository develop branch."
  value       = aws_iam_role.github_develop.arn
}

output "lab_state_path" {
  description = "Dedicated local Terraform state path. Keep it until lab teardown has completed."
  value       = "${path.module}/terraform.tfstate"
}