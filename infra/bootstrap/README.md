# Terraform state bootstrap for the disposable lab

This directory is intentionally separate from the lab infrastructure root so the remote state bucket can be created safely before the lab uses it.

## Required two-stage workflow

### Stage 1: bootstrap the remote backend

Run from this directory:

```bash
terraform init
terraform validate
terraform plan
```

Then, when you are ready to create the lab state bucket, run the real apply command only after reviewing the plan:

```bash
terraform apply
```

This bootstraps the S3 bucket that stores lab state in ap-southeast-1, with:

- versioning enabled
- SSE enabled
- public access blocked
- ACL set to private
- purpose tags indicating Terraform lab state

This bucket is intentionally not destroyed during the normal lab teardown, because it is part of the lab state bootstrap and should remain available for a future lab run.

### Stage 2: configure the lab backend and migrate the state

After the bootstrap apply succeeds, switch to the lab root:

```bash
cd ../lab
terraform init -reconfigure
```

Terraform will detect the S3 backend from the configuration in `versions.tf` and will ask whether to migrate local state to the new remote backend. Review the prompt and accept the migration only after checking that the local state is still the intended one.

Important safety checks before accepting the migration:

1. Verify the local state file exists and contains the expected lab resources.
2. Verify the remote bucket name matches the bootstrap output.
3. Confirm the key is `belandria/lab/terraform.tfstate`.
4. Do not delete the local state file immediately after migration; confirm the remote backend contains the expected resources first.
5. Run `terraform state list` against the remote state before deleting local files.

Example verification commands:

```bash
terraform state list
terraform show
```

Once verified, the lab can continue using the remote S3 state backend.

## Why no DynamoDB locking here

This lab intentionally keeps the backend simple and uses the S3 backend without a DynamoDB lock table. That is appropriate because this is a disposable, single-user learning environment and the state bucket is isolated to the lab. If the lab later evolves into a multi-user or collaborative workflow, a DynamoDB lock table can be added deliberately and documented.

## Important guardrails

- Do not store Terraform secrets in GitHub repository files.
- Do not commit `*.tfstate`, `*.tfstate.*`, or any `*.tfvars` containing credentials.
- Never print secret values into logs or plan output if avoidable.
- Keep the remote state bucket and lab resources separate from production.
