# RB-02 — Database Corruption Recovery Runbook

**Document ID:** RB-02
**Scenario:** Aurora PostgreSQL Database Corruption
**Severity:** SEV-1
**Primary Region:** AWS Mumbai (`ap-south-1`)
**DR Region:** AWS Hyderabad (`ap-south-2`)
**RPO Target:** < 1 minute
**RTO Target:** < 5 minutes
**System:** PaySecure Payment Gateway

---

## 1. Purpose

This runbook defines the operational procedure for detecting, containing, investigating, and recovering from corruption of the production Aurora PostgreSQL database.

The scenario includes corrupted tables, incorrect records, failed transactions, settlement inconsistencies, or application-level data corruption affecting payment processing.

The primary objective is to:

1. Stop further corruption.
2. Preserve evidence.
3. Prevent corrupted data from being replicated further.
4. Determine the corruption scope.
5. Recover the database using the safest available recovery point.
6. Validate payment and settlement data.
7. Restore normal payment processing.
8. Assess regulatory and merchant notification requirements.

---

## 2. Trigger Conditions

This runbook is triggered when one or more of the following conditions are detected:

* Aurora PostgreSQL reports database errors.
* Application queries return inconsistent data.
* Payment records are unexpectedly modified or deleted.
* Settlement totals do not reconcile.
* Database integrity checks fail.
* Multiple services report database constraint violations.
* CloudWatch database alarms trigger.
* Replicated data appears corrupted.
* Engineering identifies unauthorized or unexpected database changes.

---

## 3. Roles and Responsibilities

| Role                    | Responsibility                                   |
| ----------------------- | ------------------------------------------------ |
| Incident Commander      | Owns incident and authorizes recovery            |
| Database Engineer       | Investigates Aurora and performs recovery        |
| DevOps/Cloud Engineer   | Infrastructure, DNS and regional failover        |
| Application Engineer    | Application validation and rollback              |
| Security Engineer       | Security investigation and evidence preservation |
| SRE/Monitoring Engineer | Monitoring, alarms and metrics                   |
| Compliance/BCP Lead     | Regulatory and compliance assessment             |
| Merchant Operations     | Merchant communication                           |
| Business Owner          | Final business recovery approval                 |

---

# 4. Immediate Response

### Step 1 — Declare SEV-1

Declare a SEV-1 incident when production payment or settlement data integrity is affected.

Record:

* Incident ID
* Detection timestamp
* Detection source
* Affected database
* Affected tables/services
* Current transaction impact

**Target time:** 2 minutes

---

### Step 2 — Assign Incident Commander

Incident Commander confirms ownership and opens the incident bridge.

Record:

```text
Incident ID:
Start Time:
Incident Commander:
Database Engineer:
DevOps Engineer:
Security Engineer:
Compliance Lead:
```

**Target time:** 1 minute

---

### Step 3 — Freeze Non-Essential Changes

Stop:

* Production deployments
* Database migrations
* Schema changes
* Batch jobs
* Data-cleanup scripts
* Manual settlement modifications

Example:

```bash
kubectl -n paysecure scale deployment payment-api --replicas=0
```

Only use application scaling when required to prevent additional corruption.

---

### Step 4 — Capture Current Database State

Record Aurora status before making recovery changes.

```bash
aws rds describe-db-clusters \
  --region ap-south-1 \
  --query 'DBClusters[*].[DBClusterIdentifier,Status,Engine,EngineVersion]'
```

Also capture:

```bash
aws rds describe-db-instances \
  --region ap-south-1 \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,DBClusterIdentifier]'
```

Save command output as incident evidence.

---

### Step 5 — Check CloudWatch Alarms

Review:

* CPUUtilization
* DatabaseConnections
* FreeableMemory
* FreeStorageSpace
* ReadLatency
* WriteLatency
* CommitLatency
* Deadlocks
* DatabaseConnections
* ReplicaLag

Example:

```bash
aws cloudwatch describe-alarms \
  --region ap-south-1 \
  --state-value ALARM
```

**Target time:** 2 minutes

---

# 5. Containment

### Step 6 — Stop Corrupted Write Traffic

If the corruption is actively continuing, stop write traffic to the affected application.

Example:

```bash
kubectl -n paysecure scale deployment payment-api --replicas=0
```

Keep read-only services available only when they cannot worsen the incident.

**Decision Point:**

* If corruption is still occurring → stop writes immediately.
* If corruption has stopped → preserve database state and continue investigation.
* If the database is unavailable → proceed toward regional recovery.

---

### Step 7 — Preserve Evidence

Do not immediately delete or modify the suspected corrupted database.

Capture:

* CloudWatch logs
* PostgreSQL logs
* Application logs
* Audit logs
* Database metrics
* Recent deployment information
* Migration history
* Database snapshots

Record exact timestamps.

---

### Step 8 — Identify Corruption Window

Determine:

```text
Last known good timestamp:
First suspected corruption timestamp:
Current timestamp:
Estimated corruption window:
```

Example:

```text
Last known good: 14:02 UTC
First corruption detected: 14:07 UTC
Recovery target: <= 14:02 UTC
```

The recovery point must be selected based on verified data integrity, not simply the newest available copy.

---

# 6. Database Investigation

### Step 9 — Identify Affected Tables

Check application/database logs for affected objects.

Typical payment tables may include:

```text
transactions
payments
merchants
settlements
refunds
webhooks
audit_events
```

These names are illustrative; use the actual production schema.

---

### Step 10 — Check Database Connectivity

Test the application database connection.

```bash
kubectl -n paysecure exec deploy/payment-api -- \
  sh -c 'nc -zv $DB_HOST 5432'
```

If the application container does not contain `nc`, use the approved database diagnostic method.

---

### Step 11 — Check Replication Status

Inspect Aurora Global Database status.

```bash
aws rds describe-global-clusters \
  --region ap-south-1
```

Check:

* Global cluster status
* Primary region
* Secondary region
* Replication health
* Lag
* Member status

---

### Step 12 — Determine Whether Corruption Replicated

This is a critical decision.

If corrupted data has already reached the DR database, **do not immediately promote the DR database**.

Determine:

```text
Primary corrupted? YES/NO
DR corrupted? YES/NO
Replication lag:
Last known good point:
```

---

# 7. Recovery Decision

## Decision Point A — Is the DR Database Clean?

### Branch 1 — DR is clean

Proceed with controlled promotion/failover.

### Branch 2 — DR contains the same corruption

Do not promote it.

Recover from:

* Point-in-time recovery
* Verified database snapshot
* Other approved clean recovery source

### Branch 3 — Database integrity is uncertain

Treat the database as potentially compromised and involve:

* Database Engineer
* Security Engineer
* Incident Commander
* Compliance/BCP Lead

---

# 8. Point-in-Time Recovery

### Step 13 — Identify Recovery Timestamp

Select the latest verified clean timestamp before corruption.

Example:

```text
Recovery timestamp = 14:02:00 UTC
```

The selected timestamp must be documented in the incident record.

---

### Step 14 — Restore Aurora Cluster

Use the approved AWS recovery procedure.

Example command structure:

```bash
aws rds restore-db-cluster-to-point-in-time \
  --region ap-south-2 \
  --source-db-cluster-identifier paysecure-global-cluster \
  --db-cluster-identifier paysecure-recovery-cluster \
  --restore-type full-copy \
  --restore-to-time "2026-09-18T14:02:00Z"
```

**Important:** Validate the exact command and supported parameters against the deployed Aurora configuration before execution.

---

### Step 15 — Validate Recovered Database

Before production traffic is redirected, validate:

* Database availability
* Schema
* Tables
* Indexes
* Constraints
* Transaction records
* Merchant records
* Settlement records
* Refund records
* Audit records

---

### Step 16 — Perform Transaction Integrity Checks

Compare:

```text
Transaction count
Successful payments
Failed payments
Refunds
Pending payments
Settlement totals
Merchant balances
```

against the last verified-good period.

---

# 9. Settlement Validation

### Step 17 — Freeze Settlement Processing

Temporarily pause settlement generation while reconciliation is underway.

This prevents recovered and unrecovered transaction states from being mixed.

---

### Step 18 — Reconcile Transactions

Compare:

```text
Payment Gateway
        ↓
Aurora transactions
        ↓
Kafka payment events
        ↓
Settlement records
        ↓
Merchant balances
```

Identify:

* Missing transactions
* Duplicate transactions
* Amount mismatches
* Status mismatches
* Missing settlement records

---

### Step 19 — Validate Idempotency

For each affected transaction, verify its idempotency key.

The same payment request must not result in duplicate charging during recovery.

Example query pattern:

```sql
SELECT idempotency_key, COUNT(*)
FROM transactions
GROUP BY idempotency_key
HAVING COUNT(*) > 1;
```

Investigate every duplicate.

---

### Step 20 — Validate High-Value Transactions

Perform additional reconciliation for:

* Large-value transactions
* Failed transactions
* Pending transactions
* Refunds
* Chargebacks
* Settlement-critical transactions

---

# 10. Application Recovery

### Step 21 — Point Application to Recovered Database

Update the approved database connection configuration.

Example:

```bash
kubectl -n paysecure rollout restart deployment/payment-api
```

Confirm that the application resolves the intended database endpoint.

---

### Step 22 — Check Application Logs

```bash
kubectl -n paysecure logs \
  deployment/payment-api \
  --tail=200
```

Look for:

```text
connection errors
constraint violations
duplicate transactions
timeout errors
authentication errors
transaction failures
```

---

### Step 23 — Restore Consumer Processing

Restart affected Kafka consumers only after database integrity is confirmed.

```bash
kubectl -n paysecure rollout restart deployment/payment-consumer
```

Monitor consumer lag.

---

### Step 24 — Process Recovery Queue

Process transactions/events that were safely queued during the incident.

Before processing:

* Verify idempotency
* Verify transaction status
* Verify database consistency
* Confirm Kafka offsets

---

# 11. Controlled Traffic Restoration

### Step 25 — Start With Limited Traffic

Restore a small portion of payment traffic first.

Example:

```text
5% → 15% → 25% → 50% → 100%
```

At each stage monitor:

* Payment success rate
* API latency
* DB errors
* Duplicate transactions
* Kafka lag
* Settlement mismatch

---

### Step 26 — Check Payment Success Rate

Compare current success rate with the normal baseline.

Investigate unexpected degradation before increasing traffic.

---

### Step 27 — Validate End-to-End Payment

Execute approved test transactions through:

```text
Merchant
   ↓
Route 53
   ↓
ALB
   ↓
EKS
   ↓
Payment Service
   ↓
Aurora
   ↓
Kafka
   ↓
Settlement
```

Confirm the transaction appears exactly once.

---

# 12. Regulatory Assessment

### Step 28 — Assess Data Loss

Determine:

```text
Was data lost?
Was incorrect data exposed?
Were payment transactions affected?
Were settlement records affected?
Was customer/card data affected?
Was unauthorized access suspected?
```

---

### Step 29 — Compliance Review

The Compliance/BCP Lead determines applicable notification requirements based on:

* Actual incident impact
* Data involved
* Contractual obligations
* Applicable RBI requirements
* PCI-DSS obligations
* CERT-In requirements
* NPCI requirements where applicable

Do not send a regulatory notification until the authorized compliance process confirms the required recipient, content, and timing.

---

# 13. Communication

### Internal Engineering Notification

> **SEV-1 Database Integrity Incident**
>
> PaySecure has detected a database integrity issue affecting the production payment platform.
>
> Write traffic has been controlled while the database team determines the corruption window and recovery point.
>
> Engineering teams must pause non-essential production changes until the Incident Commander confirms stabilization.
>
> Incident ID: `<INCIDENT-ID>`
>
> Incident Commander: `<NAME>`
>
> Next update: `<TIME>`

---

### Merchant Communication

> **Service Incident Update**
>
> We are investigating a database integrity issue affecting payment processing.
>
> Our engineering and operations teams have activated the incident recovery process and are validating transaction and settlement records.
>
> Merchants should avoid repeatedly submitting the same payment request while transaction status is being confirmed.
>
> Further updates will be provided through the established merchant communication channel.

---

### Regulatory Notification Assessment

> **Subject: Preliminary Database Integrity Incident Assessment**
>
> PaySecure has identified a database integrity incident affecting the payment processing environment.
>
> The incident response team has initiated containment, evidence preservation, database recovery, and transaction reconciliation procedures.
>
> The compliance team is assessing the incident against applicable regulatory, contractual, payment-network, and security notification requirements.
>
> Incident ID: `<INCIDENT-ID>`
>
> Detection Time: `<TIME>`
>
> Current Impact: `<IMPACT>`

---

# 14. Monitoring During Recovery

Create/verify alarms for:

```text
DatabaseConnections
FreeStorageSpace
FreeableMemory
WriteLatency
ReadLatency
ReplicaLag
Deadlocks
TransactionErrors
API5xx
PaymentFailureRate
KafkaConsumerLag
SettlementMismatch
```

Example:

```bash
aws cloudwatch describe-alarms \
  --region ap-south-2 \
  --state-value ALARM
```

---

# 15. Recovery Timeline

| Activity                        |                             Target |
| ------------------------------- | ---------------------------------: |
| Incident declaration            |                            0–2 min |
| Containment                     |                            2–5 min |
| Corruption scope identification |                           5–10 min |
| Recovery decision               |                          10–15 min |
| Database recovery               | As quickly as technically possible |
| Integrity validation            |          Before production traffic |
| Controlled traffic restoration  |                   After validation |
| Settlement reconciliation       |    Immediately after stabilization |
| Post-incident review            |         Within defined BCP process |

**Note:** The 5-minute RTO is the project target. Actual database restoration time must be validated through DR drills and measured during testing.

---

# 16. Decision Tree

```text
                 Database Corruption Detected
                           |
                           v
                  Stop/limit write traffic
                           |
                           v
                 Identify corruption window
                           |
                           v
                Is DR database clean?
                  /          |          \
                YES        UNKNOWN       NO
                 |            |           |
                 v            v           v
          Controlled       Treat as      Do NOT
          DR recovery      unsafe        promote DR
                 |            |           |
                 |            v           v
                 |      Investigate    PITR / clean
                 |      integrity      snapshot
                 |            |           |
                 +------------+-----------+
                              |
                              v
                    Validate transactions
                              |
                              v
                    Validate settlements
                              |
                              v
                    Validate idempotency
                              |
                              v
                     Restore limited traffic
                              |
                              v
                     Monitor key metrics
                              |
                              v
                         Full traffic
                              |
                              v
                       Incident closed
```

---

# 17. Evidence Checklist

Collect:

* [ ] Incident ID
* [ ] Detection timestamp
* [ ] CloudWatch alarm history
* [ ] Aurora metrics
* [ ] Aurora logs
* [ ] Application logs
* [ ] Database snapshots
* [ ] Recovery timestamp
* [ ] Replication status
* [ ] Transaction reconciliation
* [ ] Settlement reconciliation
* [ ] Kafka offsets
* [ ] Idempotency validation
* [ ] Deployment history
* [ ] Security investigation results
* [ ] Communication records
* [ ] Regulatory assessment
* [ ] Recovery timeline

---

# 18. Exit Criteria

The incident may be closed only after:

* Database integrity is verified.
* Payment transactions are processing normally.
* No unexplained duplicate transactions remain.
* Settlement records reconcile.
* Kafka consumers are healthy.
* Database replication is healthy.
* Monitoring is green.
* Merchant impact is understood.
* Compliance assessment is complete.
* Evidence has been preserved.
* Incident Commander approves closure.

---

# 19. Post-Incident Actions

Within the post-incident review:

1. Identify root cause.
2. Identify first corrupted record.
3. Determine why corruption was not detected earlier.
4. Review database permissions.
5. Review migration controls.
6. Review application validation.
7. Review backup/PITR strategy.
8. Review replication behavior.
9. Review monitoring gaps.
10. Review settlement reconciliation controls.
11. Add automated integrity checks.
12. Update this runbook.
13. Conduct a recovery drill.
14. Record measured RPO/RTO.
15. Track corrective actions to completion.

---

## Recovery Principle

**Never promote a replica simply because it is available.**

The recovery database must first be evaluated for data integrity, replication state, and transaction consistency. The safest recovery point is the latest **verified clean state** that satisfies the project's RPO objective as closely as operationally possible.
