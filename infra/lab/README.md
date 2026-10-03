# Belandria one-day AWS lab

This root creates only lab-scoped resources tagged `belandria-lab` in `ap-southeast-1`. It does not reference production VPC, ALB, RDS, ECS, Route 53, or IAM resources. It intentionally creates no Route 53 entries and does not modify `app.belandria.me`.

The GitHub role trusts only `lit123op/myapp-fullstack` on `refs/heads/develop`. It grants no production permissions. A read-only account check confirmed the GitHub OIDC provider did not exist, so this root creates it and the lab role together. The provider is account-global and is destroyed with the lab after the lab role is removed.

## Remote state and bootstrap

The lab root uses an S3 backend rather than a local file state. The bootstrap root is in `infra/bootstrap/` and creates the remote state bucket before the lab configuration can be used with the S3 backend. The current lab key is:

- bucket: `belandria-lab-tfstate-725673805051`
- key: `belandria/lab/terraform.tfstate`
- region: `ap-southeast-1`

This is deliberately kept separate from the lab resources so the state bootstrap remains available after lab teardown unless it is intentionally destroyed.

## Apply gates

- `offline_plan` is only for a local graph/no-credential plan, never for apply.
- The current lab keeps the API at `min=1`, `desired=1`, and `max=1` until the ECS migration task workflow is implemented. Do not allow a second API task to run migrations independently.
- The frontend may stay at `min=1`, `desired=1`, and `max=2`.
- Build a lab-only frontend image with the browser API URL set to `/api` and the lab Nginx config before starting tasks. This Terraform root does not edit application files or production DNS.
- Current API startup behavior should not be left as-is if tasks are scaled above one. The intended flow is: build/push image -> one-off migration task -> deploy service.
- The values in Terraform state are not plaintext DB passwords or JWT secrets; the AWS-managed secret values remain in Secrets Manager.

## State and secret handling

The state bucket stores resource metadata and secret ARNs, but not the actual RDS password or JWT content. RDS generates and stores its master password in an AWS-managed secret. A one-shot Lambda reads that managed secret, composes separate writer and reader connection strings, generates a lab JWT value, and writes them to lab-scoped secrets in AWS Secrets Manager.

The Lambda is not long-lived and is invoked only during lab setup; it does not emit secret values to CloudWatch. The secret names are intentionally scoped to `belandria-lab/...` and separate from production values.

The API receives `ConnectionStrings__Defaultconnection` pointing at the primary RDS endpoint and `ConnectionStrings__ReadOnlyConnection` pointing at the replica endpoint; neither uses a single instance IP. The ALB uses only its generated hostname and HTTP; no Route 53 record or ACM certificate is created.

## Planned settings

- RDS PostgreSQL DB instance, `multi_az = true`, `db.t3.medium` candidate, 20 GiB gp3 initial / 40 GiB maximum storage, encryption, one-day automated backup retention, AWS-managed master password, deletion protection off, no final snapshot on delete.
- One separate asynchronous read replica, same class, same lab network, not the automatic Multi-AZ standby; promotion is manual.
- Frontend Fargate 256 CPU / 512 MiB; API 512 CPU / 1024 MiB. API size is a cautious tunable default for .NET 9 + EF Core, not benchmark-derived. Desired/min 1; API max stays 1 until the migration workflow is ready.
- Two public ALB subnets, two private ECS subnets, two isolated DB subnets, and one NAT Gateway only. The single NAT is intentionally not HA and is a one-day cost trade-off.
- One-day CloudWatch log retention, focused RDS/ECS/ALB alarms, dashboard, RDS event subscription, SNS email, and a daily $20 budget with $10/$20 alert thresholds. Budgets are not hard spending caps.

## Plan and teardown

Run `terraform fmt`, `terraform init -backend=false`, `terraform validate`, and then an AWS-authenticated `terraform plan` from this directory. Review every resource address and confirm all names and tags are lab-specific. There must be no Route 53 resource and no work against any production account resources.

After drills, review a separate `terraform plan -destroy`, then destroy lab resources. Delete any manual restore instance/snapshot and verify no RDS automated backups, ECR images, NAT/EIP, ALB, ECS tasks, Secrets Manager secrets, Lambda/log groups, alarms, SNS topic, or retained logs remain. The state bucket bootstrap stays in place unless explicitly destroyed later for a future lab run.
