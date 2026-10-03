resource "aws_secretsmanager_secret" "db_connection" {
  name                    = local.secret_names.default_connection
  description             = "Lab app PostgreSQL connection string, populated by a one-shot Lambda from the RDS-managed credential."
  recovery_window_in_days = 0

  tags = local.tags
}

resource "aws_secretsmanager_secret" "db_reader_connection" {
  count = var.enable_read_replica ? 1 : 0

  name                    = local.secret_names.read_only
  description             = "Lab app read-only PostgreSQL connection string targeting the asynchronous replica endpoint."
  recovery_window_in_days = 0

  tags = local.tags
}

resource "aws_secretsmanager_secret" "jwt_signing" {
  name                    = local.secret_names.jwt
  description             = "Disposable lab JWT signing key, generated at runtime by the one-shot seeder."
  recovery_window_in_days = 0

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "secret_seed" {
  name              = "/aws/lambda/${local.name}-secret-seed"
  retention_in_days = 1

  tags = local.tags
}

data "archive_file" "secret_seed" {
  type        = "zip"
  source_file = "${path.module}/lambda/seed_secrets.py"
  output_path = "${path.module}/.generated-seed-secrets.zip"
}

resource "aws_lambda_function" "secret_seed" {
  function_name    = "${local.name}-secret-seed"
  description      = "One-shot: composes the app connection string from the AWS-managed RDS secret without returning password material to Terraform."
  role             = aws_iam_role.secret_seed.arn
  handler          = "seed_secrets.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.secret_seed.output_path
  source_code_hash = data.archive_file.secret_seed.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      LAB_NAME = local.name
    }
  }

  tags = local.tags

  depends_on = [
    aws_cloudwatch_log_group.secret_seed,
    aws_iam_role_policy.secret_seed,
    aws_iam_role_policy_attachment.secret_seed_logs,
  ]
}

resource "time_sleep" "secret_seed_iam_propagation" {
  create_duration = "30s"
  triggers = {
    policy = aws_iam_role_policy.secret_seed.policy
  }

  depends_on = [aws_iam_role_policy.secret_seed]
}

resource "aws_lambda_invocation" "seed_runtime_secrets" {
  function_name = aws_lambda_function.secret_seed.function_name
  triggers = {
    rds_secret_arn = aws_db_instance.primary.master_user_secret[0].secret_arn
    db_host        = aws_db_instance.primary.address
    db_name        = var.db_name
    db_username    = "labadmin"
    db_port        = "5432"
    connection_arn = aws_secretsmanager_secret.db_connection.arn
    replica_host   = var.enable_read_replica ? aws_db_instance.read_replica[0].address : ""
    reader_arn     = var.enable_read_replica ? aws_secretsmanager_secret.db_reader_connection[0].arn : ""
    jwt_secret_arn = aws_secretsmanager_secret.jwt_signing.arn
  }

  input = jsonencode({
    source_secret_arn = aws_db_instance.primary.master_user_secret[0].secret_arn
    db_host           = aws_db_instance.primary.address
    db_name           = var.db_name
    db_username       = "labadmin"
    db_port           = 5432
    connection_arn    = aws_secretsmanager_secret.db_connection.arn
    replica_host      = var.enable_read_replica ? aws_db_instance.read_replica[0].address : ""
    reader_arn        = var.enable_read_replica ? aws_secretsmanager_secret.db_reader_connection[0].arn : ""
    jwt_secret_arn    = aws_secretsmanager_secret.jwt_signing.arn
  })

  depends_on = [
    aws_db_instance.primary,
    aws_iam_role_policy.secret_seed,
    time_sleep.secret_seed_iam_propagation,
  ]
}