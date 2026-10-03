# Database and scaling failure lab

All tests are manual and use disposable lab data. Terraform never executes failover, promotion, storage-fill, load, or restore tests. Record UTC time, CloudWatch dashboard, RDS event, and API/ALB symptoms for each drill. Do not run against production.

## A. Primary write/read

- **Action:** Write a uniquely identified inventory row through the API, then read it from the primary.
- **Expected:** The write commits on the primary and is immediately visible there.
- **Observe:** API result/logs; RDS `DatabaseConnections`, CPU, and RDS events.
- **Recovery/cleanup:** Delete the test row after verifying; confirm it is gone from primary.

## B. Read Replica replication

- **Action:** After A, connect read-only to the separate replica endpoint and query for the row.
- **Expected:** The row appears after asynchronous replication; this endpoint is not the Multi-AZ standby.
- **Observe:** RDS `ReplicaLag` and query visibility time.
- **Recovery/cleanup:** Poll read-only until visible; delete the row on primary and verify eventual deletion on replica.

## C. Read-after-write consistency

- **Action:** Write a new row, then immediately read through the primary route.
- **Expected:** Visible if the read uses primary. Current `GetAllInventoryAsync` uses the replica, so test a primary-routed read until application code is corrected.
- **Observe:** Query route, API logs, primary DB connections.
- **Recovery/cleanup:** Verify again, then delete the row.

## D. Replica lag/eventual consistency

- **Action:** Write on primary and query replica repeatedly at a short interval.
- **Expected:** Row may initially be stale/missing, then converges. Replication is asynchronous, not zero-lag.
- **Observe:** `ReplicaLag`, row visibility time, API errors and RDS events.
- **Recovery/cleanup:** Do not repeat the write because replica is behind. Wait for convergence, then clean up on primary.

## E. RDS Multi-AZ automatic failover

- **Action:** In a scheduled lab window only, invoke AWS-supported RDS reboot-with-forced-failover, for example `aws rds reboot-db-instance --db-instance-identifier belandria-lab-postgres-primary --force-failover --region ap-southeast-1`.
- **Expected:** RDS automatically promotes the synchronous Multi-AZ standby. The writer endpoint hostname remains the same and resolves to the new primary. The async read replica is not promoted by this operation.
- **Observe:** RDS failover/failure events and status; API connection errors/reconnects; ALB healthy/unhealthy targets, 5xx and latency; ECS health/logs; SNS alert.
- **Recovery/cleanup:** Wait for RDS `available`; run a primary write/read; verify ALB targets recover. Existing TCP sessions may fail and clients can briefly see errors. No endpoint/secret change is normally needed. Do not repeat unnecessarily.

## F. Manual Read Replica promotion (separate DR exercise)

- **Action:** Separately from E, record a recovery point, put the app in maintenance/read-only, fence old-primary writes, and pause Terraform applies. Then use the supported RDS `promote-read-replica` operation on `belandria-lab-postgres-read-replica`.
- **Expected:** Promotion stops replication and makes the replica a standalone writer. It keeps its existing replica endpoint; the old primary endpoint is not redirected. Writes not yet replicated may be missing. The old primary stays separate and may diverge; RDS does not automatically rejoin it or fail back.
- **Observe:** Replica DB status/role, replication state and `ReplicaLag` metric changes/availability; RDS events; API failures until config changes; ALB health and SNS.
- **Recovery/cleanup:** Change only the lab writer connection secret to the promoted endpoint, refresh ECS tasks/connections, then verify health and controlled writes. Preserve old primary only if needed; reconcile divergent data; create a new replica from the promoted writer; review Terraform drift/state before applying anything. Do not switch back automatically. On teardown, promoted DBs may be standalone and need individual destruction.

## G. Storage autoscaling

- **Action:** First observe allocated storage, `FreeStorageSpace`, 40 GiB cap, alarms and RDS events. A forced growth test is optional and only for this disposable DB with explicit cost/time approval; generate bounded test data/load and stop before the cap.
- **Expected:** RDS expands storage when its thresholds are met, up to `max_allocated_storage`. Allocated storage does not shrink afterward. This does not scale CPU/RAM.
- **Observe:** `FreeStorageSpace`, RDS storage modification event, CloudWatch alarm/SNS and updated allocated size.
- **Recovery/cleanup:** Keep enlarged storage only until drills end, then destroy with no final snapshot. If preserving data, snapshot explicitly and account for ongoing snapshot storage cost until deletion.

## ECS autoscaling observation

- **Action:** After image/app prerequisites, send controlled lab traffic and observe frontend/API independently. Do not scale the API above one task until per-task migrations are removed from its startup path.
- **Expected:** Target tracking aims for 60% average CPU, scales from one to at most two tasks, then scales in after cooldown. This scales task compute, not database compute.
- **Observe:** ECS CPU/memory, desired/running counts, ALB health/latency/5xx, and alarms.
- **Recovery/cleanup:** Stop traffic, wait for scale-in to one, verify health, then tear down.

## Backup/restore observation

Automated backups/PITR retention is one day. Terraform does not create a restored DB. For the drill, manually create a clearly named lab-only snapshot, restore into a separate temporary DB, verify the recovery point/data, then delete restored instance and snapshot before teardown.