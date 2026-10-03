resource "aws_cloudwatch_log_group" "rds_primary_postgresql" {
  name              = "/aws/rds/instance/${local.name}-postgres-primary/postgresql"
  retention_in_days = 1

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "rds_primary_upgrade" {
  name              = "/aws/rds/instance/${local.name}-postgres-primary/upgrade"
  retention_in_days = 1

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "rds_replica_postgresql" {
  count = var.enable_read_replica ? 1 : 0

  name              = "/aws/rds/instance/${local.name}-postgres-read-replica/postgresql"
  retention_in_days = 1

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "rds_replica_upgrade" {
  count = var.enable_read_replica ? 1 : 0

  name              = "/aws/rds/instance/${local.name}-postgres-read-replica/upgrade"
  retention_in_days = 1

  tags = local.tags
}

resource "aws_db_instance" "primary" {
  identifier                   = "${local.name}-postgres-primary"
  engine                       = "postgres"
  instance_class               = var.db_instance_class
  db_name                      = var.db_name
  username                     = "labadmin"
  manage_master_user_password  = true
  port                         = 5432
  allocated_storage            = var.db_allocated_storage
  max_allocated_storage        = var.db_max_allocated_storage
  storage_type                 = "gp3"
  storage_encrypted            = true
  multi_az                     = var.enable_multi_az
  publicly_accessible          = false
  db_subnet_group_name         = aws_db_subnet_group.lab.name
  vpc_security_group_ids       = [aws_security_group.db.id]
  backup_retention_period      = 1
  deletion_protection          = false
  skip_final_snapshot          = true
  delete_automated_backups     = true
  copy_tags_to_snapshot        = true
  auto_minor_version_upgrade   = true
  apply_immediately            = true
  performance_insights_enabled = false
  monitoring_interval          = 0
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade",
  ]

  tags = merge(local.tags, {
    Name = "${local.name}-postgres-primary"
    Role = var.enable_multi_az ? "writer-multi-az-db-instance" : "writer-single-az-db-instance"
  })

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    aws_cloudwatch_log_group.rds_primary_postgresql,
    aws_cloudwatch_log_group.rds_primary_upgrade,
  ]
}

# Stage 1 is intentionally Single-AZ and does not create the asynchronous read replica.
# Stage 2 re-enables the async read replica and the Multi-AZ failover design separately.
resource "aws_db_instance" "read_replica" {
  count = var.enable_read_replica ? 1 : 0

  identifier                   = "${local.name}-postgres-read-replica"
  replicate_source_db          = aws_db_instance.primary.identifier
  instance_class               = var.db_instance_class
  max_allocated_storage        = var.db_max_allocated_storage
  storage_encrypted            = true
  publicly_accessible          = false
  vpc_security_group_ids       = [aws_security_group.db.id]
  backup_retention_period      = 0
  deletion_protection          = false
  skip_final_snapshot          = true
  delete_automated_backups     = true
  auto_minor_version_upgrade   = true
  apply_immediately            = true
  performance_insights_enabled = false
  monitoring_interval          = 0
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade",
  ]

  tags = merge(local.tags, {
    Name = "${local.name}-postgres-read-replica"
    Role = "async-read-only-replica-manual-promotion"
  })

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    aws_cloudwatch_log_group.rds_replica_postgresql[0],
    aws_cloudwatch_log_group.rds_replica_upgrade[0],
  ]
}