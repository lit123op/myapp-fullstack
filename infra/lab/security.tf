resource "aws_security_group" "alb" {
  name                   = "${local.name}-alb-sg"
  description            = "HTTP ingress for the disposable lab ALB only."
  vpc_id                 = aws_vpc.lab.id
  revoke_rules_on_delete = true
  egress                 = []

  tags = merge(local.tags, { Name = "${local.name}-alb-sg" })
}

resource "aws_security_group" "frontend" {
  name                   = "${local.name}-frontend-sg"
  description            = "Frontend tasks accept HTTP only from the lab ALB."
  vpc_id                 = aws_vpc.lab.id
  revoke_rules_on_delete = true
  egress                 = []

  tags = merge(local.tags, { Name = "${local.name}-frontend-sg" })
}

resource "aws_security_group" "api" {
  name                   = "${local.name}-api-sg"
  description            = "API tasks accept traffic only from the lab ALB."
  vpc_id                 = aws_vpc.lab.id
  revoke_rules_on_delete = true
  egress                 = []

  tags = merge(local.tags, { Name = "${local.name}-api-sg" })
}

resource "aws_security_group" "db" {
  name                   = "${local.name}-db-sg"
  description            = "PostgreSQL is private and accepts connections only from lab API tasks."
  vpc_id                 = aws_vpc.lab.id
  revoke_rules_on_delete = true
  egress                 = []

  tags = merge(local.tags, { Name = "${local.name}-db-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Temporary public HTTP for the lab ALB."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_frontend" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.frontend.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_api" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = 8080
  ip_protocol                  = "tcp"
  to_port                      = 8080
}

resource "aws_vpc_security_group_ingress_rule" "frontend_from_alb" {
  security_group_id            = aws_security_group.frontend.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
}

resource "aws_vpc_security_group_ingress_rule" "api_from_alb" {
  security_group_id            = aws_security_group.api.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8080
  ip_protocol                  = "tcp"
  to_port                      = 8080
}

resource "aws_vpc_security_group_egress_rule" "frontend_https" {
  security_group_id = aws_security_group.frontend.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  description       = "ECR and CloudWatch egress through the single lab NAT."
}

resource "aws_vpc_security_group_egress_rule" "api_https" {
  security_group_id = aws_security_group.api.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  description       = "Secrets, logs, ECR, and configured third-party API egress through the single lab NAT."
}

resource "aws_vpc_security_group_egress_rule" "api_postgres" {
  security_group_id            = aws_security_group.api.id
  referenced_security_group_id = aws_security_group.db.id
  from_port                    = 5432
  ip_protocol                  = "tcp"
  to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "db_from_api" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = 5432
  ip_protocol                  = "tcp"
  to_port                      = 5432
  description                  = "Private PostgreSQL access from lab API tasks only."
}