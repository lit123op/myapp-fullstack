# Render PostgreSQL to RDS cutover checklist

This is a runbook only. It does not connect to Render or AWS and does not move data. Test the procedure with a staging database before scheduling production downtime.

## Before the window

- Deploy the app to AWS staging with a sanitized copy of the database and validate inventory reads/writes, authentication, payments, webhooks, and integrations.
- Confirm the AWS writer and read-replica endpoints, database name, secret values, storage, backups, and alarms.
- Ensure the source and destination PostgreSQL major versions and extensions are compatible. Install `postgresql-client` tools matching the servers.
- Verify AWS can reach the source database if using direct `pg_dump`; otherwise take an encrypted Render backup and transfer it through an approved secure channel.
- Restrict access to the dump: use an encrypted disk or encrypted temporary object storage, never commit it or print connection strings, and securely remove temporary copies after verification.
- Record the source backup identifier/time and rehearse restoration and rollback.

## Production cutover

1. Announce a maintenance window and stop writes to the Render app (maintenance mode or temporarily disable write endpoints). Keep Render available for read-only checks if safe.
2. Take a final source backup. From a trusted workstation or private runner, export and restore using protected environment variables, not literal credentials:

   ```bash
   pg_dump --format=custom --no-owner --no-acl "$RENDER_DATABASE_URL" --file=render-final.dump
   pg_restore --no-owner --no-acl --exit-on-error --dbname="$AWS_RDS_WRITER_URL" render-final.dump
   ```

3. Compare key table row counts and application-level totals on source and target. Confirm migrations have run and the read replica has caught up before allowing writes.
4. Dispatch the protected AWS deployment workflow. Smoke-test the HTTPS ALB host, `/health`, inventory GET/POST/PUT/DELETE with test data, and read-after-write after replication catches up.
5. Switch the production DNS/traffic only after approval. Keep Render and its database intact during the agreed rollback window; do not allow both environments to accept writes concurrently.
6. Monitor errors, latency, database replication lag, and background integrations. If rollback is needed after AWS accepted writes, first reconcile those writes back to Render or restore from a verified AWS backup; simply pointing DNS back can lose data.

## After cutover

- Keep the source Render database and backups until the retention/rollback period is approved as complete.
- Verify scheduled backups and perform a restore drill before decommissioning anything.
- Remove temporary dump files and transfer credentials from the trusted machine/runner.