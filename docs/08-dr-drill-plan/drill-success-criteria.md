# PaySecure Gateway — DR Drill Success Criteria

## 1. Purpose

This document defines measurable PASS/FAIL criteria for PaySecure Gateway disaster recovery exercises.

The criteria are designed around the project objectives:

* **Target Availability:** 99.99%
* **RTO:** < 5 minutes
* **RPO:** < 1 minute
* **Primary Region:** Mumbai (`ap-south-1`)
* **DR Region:** Hyderabad (`ap-south-2`)

Every drill must produce measurable evidence rather than relying only on verbal confirmation.

---

# 2. Overall Drill Result

A drill is considered successful when all mandatory critical criteria are satisfied.

```text id="1l4u8f"
PASS
 │
 ├── RTO target achieved
 ├── RPO target achieved
 ├── Payment service recovered
 ├── No unacceptable data loss
 ├── No duplicate financial transactions
 ├── Security controls preserved
 ├── Monitoring/alerting worked
 └── Evidence collected
```

Any critical safety, security, or data-integrity failure requires the drill to be classified as **FAIL**, even if application recovery was successful.

---

# 3. RTO Success Criteria

## Target

```text id="5wq8am"
RTO < 5 minutes
```

Measurement starts when the defined failure condition is declared and ends when the payment service is operational in the DR region.

### PASS

```text
Measured RTO < 5 minutes
```

### FAIL

```text
Measured RTO >= 5 minutes
```

The measured value must be recorded in the post-drill report.

---

# 4. RPO Success Criteria

## Target

```text id="5e8m7y"
RPO < 1 minute
```

The team must compare the failure timestamp with the latest successfully replicated transaction state.

### PASS

Less than one minute of recoverable transaction-state gap.

### FAIL

One minute or greater data gap, or inability to determine the recoverable transaction point.

---

# 5. Payment API Recovery

The payment API must become operational in the DR region after failover.

### PASS Conditions

* Health endpoint returns healthy.
* Required EKS pods are running.
* Database connectivity works.
* Kafka connectivity works.
* Payment transaction test succeeds.
* Monitoring reports healthy service state.

### FAIL Conditions

* Payment API remains unavailable.
* Required dependencies are unavailable.
* Test payment cannot complete.
* Application enters an uncontrolled error loop.

---

# 6. Transaction Integrity

Transaction integrity is a mandatory success criterion.

The drill must verify:

* No unexpected duplicate transactions
* No unexplained missing transactions
* No corrupted transaction records
* Correct transaction status
* Correct transaction identifiers
* Correct amount and merchant references
* Successful reconciliation

### PASS

All test transactions are correctly accounted for.

### FAIL

Any unexplained financial transaction discrepancy remains unresolved.

---

# 7. Database Replication

Aurora replication must be monitored during the exercise.

The project monitoring threshold is:

```text id="aq8i6d"
Aurora Global DB Replication Lag
> 500 ms
for 2 consecutive checks
= P1 Critical
```

### PASS

Replication is healthy or any alert is handled according to the relevant runbook.

### FAIL

Replication failure causes unacceptable transaction-state loss or prevents safe recovery.

---

# 8. DynamoDB Replication

The project monitoring threshold is:

```text id="1r8n7q"
DynamoDB Global Table Replication Lag
> 1000 ms
for 3 consecutive checks
= P1 Critical
```

### PASS

Replication state is known and recoverable.

### FAIL

Replication failure causes unacceptable data inconsistency or prevents safe failover.

---

# 9. Redis Replication

The project monitoring threshold is:

```text id="p4f7p8"
ElastiCache Global Datastore Lag
> 2000 ms
for 3 consecutive checks
= P2 High
```

Redis should not be treated as the authoritative source for financial transaction state.

### PASS

Required cache-dependent application functionality operates correctly.

### FAIL

Cache failure causes uncontrolled payment-processing failure or data integrity problems.

---

# 10. Kafka Replication

The project monitoring threshold is:

```text id="6a0d3v"
MSK Replicator Lag
> 10,000 messages
for 5 minutes
= P2 High
```

### PASS

* Required topics exist.
* Consumers can connect.
* Consumer offsets are validated.
* Critical events are available.
* Settlement processing works.

### FAIL

Critical events are missing, duplicated without reconciliation, or consumer recovery cannot be completed safely.

---

# 11. DNS Failover

Route 53 must redirect traffic to the DR environment when the primary region is unhealthy.

### PASS

* Mumbai health check becomes unhealthy.
* DR routing becomes active.
* Hyderabad receives test traffic.
* No uncontrolled DNS configuration change occurs.
* Failover timing is recorded.

### FAIL

* Traffic continues to the failed environment.
* Hyderabad cannot receive traffic.
* DNS state cannot be verified.
* Manual intervention exceeds the approved recovery procedure.

---

# 12. Monitoring and Alerting

The drill must verify that monitoring detects the simulated failure.

Important project thresholds include:

| Metric                   | Threshold                  | Severity |
| ------------------------ | -------------------------- | -------- |
| Aurora replication lag   | >500 ms for 2 checks       | P1       |
| DynamoDB replication lag | >1000 ms for 3 checks      | P1       |
| Redis replication lag    | >2000 ms for 3 checks      | P2       |
| MSK Replicator lag       | >10,000 messages for 5 min | P2       |
| Route 53 health check    | Any failure                | P1       |
| Payment API success rate | <99.5% for 2 min           | P1       |
| Transaction P99 latency  | >300 ms for 5 min          | P2       |
| EKS unready nodes        | >2 for 3 min               | P2       |
| KMS usage anomaly        | >3× normal hourly volume   | P1       |
| DR composite health      | Any component unhealthy    | P1       |

---

# 13. Payment Success Rate

The project monitoring target is:

```text id="3h7f6k"
Payment API success rate < 99.5%
for 2 minutes
= P1 Critical
```

During a DR drill, the team should record:

```text
Baseline success rate: ______
Lowest success rate: ______
Recovery success rate: ______
Time below threshold: ______
```

The final result must be compared against the approved drill impact threshold.

---

# 14. Transaction Latency

The project threshold is:

```text id="u9k7aq"
Transaction P99 latency
> 300 ms
for 5 minutes
= P2 High
```

Record:

* Baseline P99
* Maximum P99
* Duration above threshold
* Time to return to baseline

---

# 15. EKS Recovery

The DR environment must have sufficient Kubernetes capacity.

The project monitoring threshold is:

```text id="5flq89"
EKS unready nodes > 2
for 3 minutes
= P2 High
```

### PASS

* Required nodes become Ready.
* Payment pods become healthy.
* No uncontrolled CrashLoopBackOff condition.
* Application replicas meet the approved DR capacity.

---

# 16. Security Controls

Security controls must remain active during failover.

Mandatory checks include:

* IAM authorization
* MFA
* KMS permissions
* Encryption at rest
* TLS
* WAF
* Security Groups
* Network Policies
* Audit logging
* Secrets management

### PASS

All required security controls remain operational.

### FAIL

Any uncontrolled security bypass or unauthorized access occurs.

---

# 17. KMS Monitoring

The project defines:

```text id="7ek4om"
KMS key usage
> 3× normal hourly volume
= P1 Critical
```

Any unexpected cryptographic activity must be investigated.

A drill must never disable key-management controls simply to make recovery easier.

---

# 18. Reconciliation Success

After failover, the team must reconcile transactions.

The reconciliation must cover:

* Transaction ID
* Merchant ID
* Amount
* Timestamp
* Payment status
* Settlement status
* Event processing status

### PASS

All test transactions have an explainable final state.

### FAIL

Unresolved transaction discrepancies remain after the reconciliation window.

---

# 19. Communication Success

The incident-response process must verify:

* Incident declared correctly
* Correct stakeholders notified
* Incident Commander identified
* Technical teams assigned
* Business stakeholders informed
* Status updates recorded
* Recovery completion communicated

A communication failure should be recorded even if the technical recovery succeeds.

---

# 20. Runbook Execution

The assigned team must execute the appropriate runbook.

The review checks:

* Correct runbook selected
* Steps followed in correct order
* AWS CLI commands usable
* Decision points understood
* Roles clearly assigned
* Timing recorded
* Evidence captured

### PASS

The runbook can be executed without undocumented critical steps.

### FAIL

A missing or incorrect step materially delays recovery.

---

# 21. Failback Success

After the primary region is restored:

1. Mumbai infrastructure is validated.
2. Data synchronization is verified.
3. Payment services are tested.
4. Transaction reconciliation is completed.
5. Security controls are checked.
6. Traffic is moved back under controlled approval.
7. Monitoring confirms stable operation.

### PASS

Mumbai resumes service without data-integrity problems.

### FAIL

Failback causes transaction loss, duplication, instability, or uncontrolled service disruption.

---

# 22. Evidence Requirements

Every PASS/FAIL decision must have supporting evidence.

Required evidence can include:

* CloudWatch metrics
* Route 53 health-check output
* EKS status
* Database replication metrics
* Kafka replication metrics
* Application logs
* Transaction records
* Reconciliation report
* Incident timeline
* Screenshots
* AWS CLI output
* Runbook checklist

---

# 23. Drill Scorecard

| Category              | Target              | Result | Status    |
| --------------------- | ------------------- | ------ | --------- |
| RTO                   | <5 min              | ____   | PASS/FAIL |
| RPO                   | <1 min              | ____   | PASS/FAIL |
| Payment API recovery  | Successful          | ____   | PASS/FAIL |
| Transaction integrity | No unexplained loss | ____   | PASS/FAIL |
| DNS failover          | Successful          | ____   | PASS/FAIL |
| Aurora replication    | Healthy             | ____   | PASS/FAIL |
| DynamoDB replication  | Healthy             | ____   | PASS/FAIL |
| Redis replication     | Healthy             | ____   | PASS/FAIL |
| Kafka replication     | Healthy             | ____   | PASS/FAIL |
| Monitoring            | Alerts generated    | ____   | PASS/FAIL |
| Security              | Controls preserved  | ____   | PASS/FAIL |
| Reconciliation        | Complete            | ____   | PASS/FAIL |
| Failback              | Successful          | ____   | PASS/FAIL |
| Evidence              | Complete            | ____   | PASS/FAIL |

---

# 24. Critical Failure Conditions

The following conditions require the drill to be classified as **FAIL** and escalated for corrective action:

1. Unexplained transaction loss.
2. Duplicate financial transactions that cannot be reconciled.
3. Security-control bypass.
4. Unauthorized access.
5. Inability to recover payment processing.
6. RPO target materially exceeded.
7. RTO target materially exceeded.
8. Critical DR data unavailable.
9. Failover causes uncontrolled production impact.
10. Required evidence cannot be produced.

---

# 25. Corrective Action

Every failed criterion must result in a corrective-action record.

The record must contain:

```text
Issue ID:
Scenario:
Failed Criterion:
Observed Result:
Expected Result:
Root Cause:
Severity:
Owner:
Corrective Action:
Target Completion Date:
Verification Method:
Status:
```

Corrective actions remain open until the responsible owner provides evidence that the issue has been resolved and retested.

---

# 26. Final Acceptance

The DR drill is formally accepted only after:

* Technical results are reviewed.
* RTO/RPO measurements are documented.
* Transaction reconciliation is complete.
* Security validation is complete.
* Failed criteria have owners.
* Evidence has been archived.
* Corrective actions are tracked.
* Business and technical stakeholders approve the final report.

This process ensures that DR readiness is demonstrated through measurable recovery performance rather than architecture documentation alone.
