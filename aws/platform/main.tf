data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket       = var.state_bucket
    key          = var.infrastructure_state_key
    region       = var.aws_region
    encrypt      = true
    use_lockfile = true
  }
}

data "http" "rds_ca" {
  url = "https://truststore.pki.rds.amazonaws.com/${var.aws_region}/${var.aws_region}-bundle.pem"
}

resource "kubernetes_config_map_v1" "rds_ca" {
  metadata {
    name      = "aws-rds-ca"
    namespace = "myapp"
  }

  data = {
    "rds-ca.pem" = data.http.rds_ca.response_body
  }
}

resource "kubernetes_namespace_v1" "myapp" {
  metadata {
    name = "myapp"
  }
}

resource "kubernetes_service_account_v1" "aws_load_balancer_controller" {
  automount_service_account_token = false

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = data.terraform_remote_state.infrastructure.outputs.load_balancer_controller_role_arn
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_load_balancer_controller_chart_version
  namespace  = "kube-system"
  timeout    = 600
  wait       = true
  atomic     = true

  values = [yamlencode({
    clusterName = data.terraform_remote_state.infrastructure.outputs.cluster_name
    region      = var.aws_region
    vpcId       = data.terraform_remote_state.infrastructure.outputs.vpc_id
    serviceAccount = {
      create = false
      name   = "aws-load-balancer-controller"
    }
  })]

  depends_on = [kubernetes_service_account_v1.aws_load_balancer_controller]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version
  namespace  = "kube-system"
  timeout    = 300
  wait       = true
  atomic     = true
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.external_secrets_chart_version
  namespace        = "external-secrets"
  create_namespace = true
  timeout          = 600
  wait             = true
  atomic           = true

  values = [yamlencode({
    installCRDs = true
    serviceAccount = {
      create = true
      name   = "external-secrets"
      annotations = {
        "eks.amazonaws.com/role-arn" = data.terraform_remote_state.infrastructure.outputs.external_secrets_role_arn
      }
    }
    rbac = {
      serviceAccountTokenCreate = true
    }
  })]

  depends_on = [helm_release.aws_load_balancer_controller, helm_release.metrics_server]
}

resource "helm_release" "cluster_runtime" {
  name      = "cluster-runtime"
  chart     = "${path.module}/../charts/cluster-runtime"
  namespace = kubernetes_namespace_v1.myapp.metadata[0].name
  timeout   = 300
  wait      = true
  atomic    = true

  values = [yamlencode({
    awsRegion    = var.aws_region
    dbSecretArn  = data.terraform_remote_state.infrastructure.outputs.db_secret_arn
    appSecretArn = data.terraform_remote_state.infrastructure.outputs.app_secret_arn
  })]

  depends_on = [helm_release.external_secrets, kubernetes_config_map_v1.rds_ca, kubernetes_namespace_v1.myapp]
}

import {
  to = helm_release.aws_load_balancer_controller
  id = "kube-system/aws-load-balancer-controller"
}

import {
  to = helm_release.metrics_server
  id = "kube-system/metrics-server"
}

import {
  to = kubernetes_namespace_v1.myapp
  id = "myapp"
}

import {
  to = kubernetes_service_account_v1.aws_load_balancer_controller
  id = "kube-system/aws-load-balancer-controller"
}

import {
  to = kubernetes_config_map_v1.rds_ca
  id = "myapp/aws-rds-ca"
}