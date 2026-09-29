# EKS Platform Terraform

This Terraform root manages Kubernetes and Helm resources after the AWS infrastructure root in `../` has created EKS. Keeping these roots separate lets the first infrastructure apply complete before Kubernetes and Helm providers connect to the cluster.

## One-Time Setup

1. Copy `backend.hcl.example` to `backend.hcl` and set the existing state bucket. Keep the platform key as `myapp/production/platform.tfstate` so this root does not share state with `../`.
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and set `state_bucket` to the same bucket. Keep `infrastructure_state_key` pointed at the state key configured by `../backend.hcl`.
3. From this directory, run `terraform init -backend-config=backend.hcl`.
4. Run `terraform plan` and review the import actions for the existing AWS Load Balancer Controller, Metrics Server, `myapp` namespace, and controller service account before applying.
5. Run `terraform apply` to adopt those resources and install External Secrets plus the runtime ConfigMap and ExternalSecret resources.

Terraform retrieves application credentials directly from AWS Secrets Manager through IRSA-backed External Secrets. Secret values are not read into Terraform state or GitHub Actions.

After the platform apply succeeds, GitHub Actions only builds and pushes the frontend/backend images, waits for the ExternalSecrets to become Ready, and deploys the application Helm chart.