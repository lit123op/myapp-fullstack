output "aws_region" {
  value = var.aws_region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}

output "load_balancer_controller_role_arn" {
  value = module.aws_load_balancer_controller_role.iam_role_arn
}

output "backend_ecr_repository_url" {
  value = aws_ecr_repository.app["backend"].repository_url
}

output "frontend_ecr_repository_url" {
  value = aws_ecr_repository.app["frontend"].repository_url
}

output "db_writer_address" {
  value = aws_db_instance.primary.address
}

output "db_reader_address" {
  value = aws_db_instance.read_replica.address
}

output "db_name" {
  value = var.db_name
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "app_secret_arn" {
  value = aws_secretsmanager_secret.app.arn
}