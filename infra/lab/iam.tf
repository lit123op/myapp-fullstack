data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${local.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name               = "${local.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = local.tags
}

data "aws_iam_policy_document" "execution_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = concat(
      [
        aws_secretsmanager_secret.db_connection.arn,
        aws_secretsmanager_secret.jwt_signing.arn,
      ],
      var.enable_read_replica ? [aws_secretsmanager_secret.db_reader_connection[0].arn] : []
    )
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "${local.name}-read-runtime-secrets"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "secret_seed" {
  name               = "${local.name}-secret-seed"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "secret_seed_logs" {
  role       = aws_iam_role.secret_seed.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "secret_seed" {
  depends_on = [aws_db_instance.primary]

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.primary.master_user_secret[0].secret_arn]
  }

  statement {
    actions = ["secretsmanager:PutSecretValue"]
    resources = concat(
      [
        aws_secretsmanager_secret.db_connection.arn,
        aws_secretsmanager_secret.jwt_signing.arn,
      ],
      var.enable_read_replica ? [aws_secretsmanager_secret.db_reader_connection[0].arn] : []
    )
  }
}

resource "aws_iam_role_policy" "secret_seed" {
  name   = "${local.name}-seed-runtime-secrets"
  role   = aws_iam_role.secret_seed.id
  policy = data.aws_iam_policy_document.secret_seed.json
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/develop"]
    }
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = merge(local.tags, {
    Name = "${local.name}-github-oidc"
  })
}

resource "aws_iam_role" "github_develop" {
  name               = "${local.name}-github-develop-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json

  tags = local.tags
}

data "aws_iam_policy_document" "github_deploy" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      aws_ecr_repository.frontend.arn,
      aws_ecr_repository.api.arn,
    ]
  }

  statement {
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService",
    ]
    resources = [
      "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:service/${aws_ecs_cluster.lab.name}/${aws_ecs_service.frontend.name}",
      "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:service/${aws_ecs_cluster.lab.name}/${aws_ecs_service.api.name}",
    ]
  }

  statement {
    actions = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
    resources = [
      "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:task-definition/${local.name}-*",
    ]
  }

  statement {
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_execution.arn,
      aws_iam_role.ecs_task.arn,
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "${local.name}-github-develop-deploy"
  role   = aws_iam_role.github_develop.id
  policy = data.aws_iam_policy_document.github_deploy.json
}