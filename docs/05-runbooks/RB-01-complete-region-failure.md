# RB-01 — Complete Region Failure

## 1. Runbook Information

| Field           | Value                                                        |
| --------------- | ------------------------------------------------------------ |
| Runbook ID      | RB-01                                                        |
| Scenario        | Complete Region Failure                                      |
| Primary Region  | Mumbai — `ap-south-1`                                        |
| DR Region       | Hyderabad — `ap-south-2`                                     |
| Severity        | SEV-1 / Critical                                             |
| RPO Target      | < 1 minute                                                   |
| RTO Target      | < 5 minutes                                                  |
| Primary Owner   | Incident Commander                                           |
| Technical Owner | Platform / Cloud Engineering                                 |
| Business Owner  | Payment Operations                                           |
| Communication   | Engineering, Management, Merchants, Regulators as applicable |

---

# 2. Scenario

The entire Mumbai AWS region becomes unavailable or is considered unsafe for production payment processing.

Potential affected components include:

* EKS workloads
* Application Load Balancers
* Aurora PostgreSQL
* DynamoDB access
* ElastiCache Redis
* Amazon MSK
* S3-dependent workflows
* Payment APIs
* Webhook processing
* Settlement services
* Monitoring and logging integrations

The objective is to restore critical payment processing from Hyderabad while maintaining transaction integrity and minimizing data loss.

---

# 3. Trigger Conditions

This runbook may be activated when one or more of the following conditions occur:

1. Multiple Mumbai services become unavailable.
2. Mumbai ALB health checks continuously fail.
3. Mumbai application health endpoints fail.
4. AWS regional service degradation prevents payment processing.
5. Database and messaging services cannot safely process transactions.
6. Engineering confirms that the incident is regional rather than application-specific.
7. AWS or internal monitoring confirms a Mumbai regional outage.

A single application alarm must not automatically be treated as a complete regional failure.

---

# 4. Roles

| Role                | Responsibility                                    |
| ------------------- | ------------------------------------------------- |
| Incident Commander  | Owns incident decision and failover authorization |
| Cloud Engineer      | Infrastructure and AWS recovery                   |
| Platform Engineer   | EKS/application recovery                          |
| Database Engineer   | Aurora/DynamoDB recovery                          |
| Messaging Engineer  | Kafka/MSK recovery                                |
| Security Engineer   | KMS/WAF/security validation                       |
| Payment Operations  | Transaction and settlement validation             |
| Communications Lead | Internal and merchant communication               |
| Compliance Lead     | Regulatory communication                          |

---

# 5. Initial Detection — 0 to 1 Minute

### Step 1 — Receive critical alert

Monitoring should generate a critical regional availability alert.

Example:

```text
ALARM: PaySecure Mumbai Regional Availability
Severity: CRITICAL
Region: ap-south-1
```

### Step 2 — Acknowledge incident

The on-call engineer acknowledges the alert and opens a SEV-1 incident.

Record:

```text
Incident ID:
Detection timestamp:
Alert source:
Affected region:
Initial symptoms:
```

### Step 3 — Check Mumbai API

Example:

```bash
curl -I https://api-mum.paysecure.example/health
```

If the endpoint repeatedly fails, continue investigation.

### Step 4 — Check ALB

Use AWS CLI:

```bash
aws elbv2 describe-load-balancers \
  --region ap-south-1
```

### Step 5 — Check EKS

```bash
aws eks list-clusters \
  --region ap-south-1
```

Then:

```bash
kubectl get nodes
kubectl get pods -A
```

---

# 6. Decision Point 1 — Regional or Application Failure?

```text
              Mumbai Failure
                    |
                    v
           Check multiple services
                    |
          +---------+---------+
          |                   |
      Only one service    Multiple services
          |                   |
          v                   v
    Application issue    Check AWS regional
    investigation       service availability
                              |
                       +------+------+
                       |             |
                  Regional issue   Unknown
                       |             |
                       v             v
                 Continue RB-01   Escalate
```

If only one application is affected, do not immediately activate the complete regional DR process.

---

# 7. Incident Declaration — 1 to 2 Minutes

### Step 6 — Declare SEV-1

Incident Commander declares:

```text
SEV-1: Mumbai regional failure.
DR activation assessment initiated.
```

### Step 7 — Assemble response team

Notify:

* Cloud Engineering
* Platform Engineering
* Database Engineering
* Messaging Engineering
* Security
* Payment Operations
* Compliance
* Communications

### Step 8 — Freeze non-essential changes

Pause:

* Deployments
* Infrastructure changes
* Database migrations
* Configuration changes
* Non-emergency automation

This reduces additional operational risk during recovery.

---

# 8. Check Data Replication — 1 to 2 Minutes

### Step 9 — Check Aurora replication status

Check the DR database and replication status using the approved AWS operational tooling.

Record:

```text
Last known primary transaction:
Latest replicated transaction:
Replication lag:
Replication status:
```

### Step 10 — Check DynamoDB replication

Validate that required global-table data is available in Hyderabad.

### Step 11 — Check Kafka replication

Validate:

* Replication status
* Consumer readiness
* Topic availability
* Consumer lag
* Latest replicated offsets

### Step 12 — Check S3 data availability

Validate required replicated objects and application access.

---

# 9. Decision Point 2 — Is RPO Acceptable?

```text
        Check replication state
                  |
                  v
        Replication lag measured
                  |
          +-------+-------+
          |               |
       < 1 minute      >= 1 minute
          |               |
          v               v
   Continue recovery   Declare RPO
                       exception
          |               |
          v               v
   Promote/activate    Continue with
       DR state         reconciliation
```

If the replication gap is greater than the project target, record the exception.

Do not hide or overwrite the measured RPO.

---

# 10. Write Fencing — 2 to 3 Minutes

### Step 13 — Stop unsafe Mumbai writes

The recovery team must ensure that Mumbai cannot continue accepting conflicting writes before Hyderabad becomes authoritative.

### Step 14 — Confirm write ownership

Record:

```text
Mumbai write status:
Hyderabad write status:
Database authority:
Failover authorization:
```

### Step 15 — Prevent split-brain

If Mumbai cannot be confirmed as unavailable, treat write ownership as unsafe and escalate to the Incident Commander.

---

# 11. Activate Hyderabad — 2 to 3 Minutes

### Step 16 — Validate EKS

```bash
aws eks list-clusters \
  --region ap-south-2
```

Check workloads:

```bash
kubectl get nodes
kubectl get pods -A
```

### Step 17 — Check application services

```bash
kubectl get deployments -A
kubectl get services -A
```

### Step 18 — Validate ALB

```bash
aws elbv2 describe-load-balancers \
  --region ap-south-2
```

### Step 19 — Validate Aurora

Confirm that the Hyderabad database is available and ready for the intended recovery role.

### Step 20 — Validate DynamoDB

Confirm application access to required replicated tables.

### Step 21 — Validate Redis

Confirm cache availability.

Cache data must not be treated as the authoritative source for financial transaction state.

### Step 22 — Validate Kafka

Confirm required topics and consumers are operational.

---

# 12. Application Recovery

### Step 23 — Check application health

```bash
curl -I https://api-hyd.paysecure.example/health
```

Expected result:

```text
HTTP 200
```

### Step 24 — Check readiness

```bash
curl -I https://api-hyd.paysecure.example/ready
```

Expected result:

```text
HTTP 200
```

### Step 25 — Validate application logs

```bash
kubectl logs -n <namespace> deployment/<deployment-name> --tail=100
```

Look for:

* Database connection failures
* Kafka connection failures
* Authentication failures
* KMS errors
* Configuration errors
* Repeated application exceptions

---

# 13. DNS Failover — 3 to 4 Minutes

### Step 26 — Validate Hyderabad health check

Confirm:

```text
paysecure-hyderabad-api-health = HEALTHY
```

### Step 27 — Authorize DNS failover

Incident Commander authorizes the traffic switch.

### Step 28 — Update/activate Route 53 failover

Use the approved Route 53 configuration and change procedure.

Example inspection command:

```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id <HOSTED_ZONE_ID>
```

### Step 29 — Verify DNS

```bash
nslookup api.paysecure.example
```

Confirm that traffic is resolving toward the intended Hyderabad endpoint.

---

# 14. Payment Smoke Test — 4 to 5 Minutes

### Step 30 — Send test transaction

Use the approved non-production/test merchant transaction mechanism.

Validate:

```text
API request
    ↓
Authentication
    ↓
Idempotency
    ↓
Transaction database
    ↓
Payment processing
    ↓
Kafka event
    ↓
Response
```

### Step 31 — Validate idempotency

Repeat the same test request using the same idempotency key.

Expected behavior:

```text
Existing transaction returned
```

A duplicate financial transaction must not be created.

### Step 32 — Validate Kafka event

Confirm that the payment event is published and consumed.

### Step 33 — Validate transaction state

Confirm that the transaction has the expected state in the authoritative database.

---

# 15. Decision Point 3 — Payment Validation

```text
            Payment smoke test
                    |
          +---------+---------+
          |                   |
        PASS                 FAIL
          |                   |
          v                   v
    Continue DR         Stop cutover
    operations               |
                             v
                      Investigate app,
                      database, Kafka,
                      security or DNS
                             |
                       +-----+-----+
                       |           |
                    Recover     Escalate
```

---

# 16. Monitoring After Failover

### Step 34 — Monitor API success rate

Monitor:

* HTTP 5xx rate
* Payment success rate
* P99 latency
* Request volume
* Authentication failures
* Database errors
* Kafka consumer lag

### Step 35 — Monitor capacity

Hyderabad must be monitored for:

* CPU
* Memory
* EKS pod capacity
* ALB connections
* Database connections
* Kafka throughput
* Redis memory

### Step 36 — Increase incident monitoring frequency

During the first recovery period, monitor critical payment metrics continuously according to the incident commander's operating cadence.

---

# 17. Merchant Communication

Communications Lead sends the approved merchant notification.

**Subject: PaySecure Gateway Service Continuity Update**

Dear Merchant,

PaySecure Gateway has activated its disaster recovery procedures following an infrastructure disruption affecting the primary processing region.

Payment processing has been redirected to the recovery environment.

Our engineering and payment operations teams are actively monitoring transaction processing and reconciliation.

Merchants should continue using the existing API endpoint unless otherwise instructed.

We will provide further updates as service stability is confirmed.

PaySecure Gateway Operations

18. Internal Engineering Notification
**SEV-1 — Mumbai Regional Failure**

Mumbai (`ap-south-1`) has been confirmed as unavailable for production payment processing.

DR recovery in Hyderabad (`ap-south-2`) is being activated.

Current status:

* Application: Recovery in progress
* Database: Replication validated
* Kafka: Recovery validation in progress
* DNS: Failover authorized/being validated
* Payment smoke test: Pending

All non-essential deployments and infrastructure changes are frozen until incident closure.

Incident Commander: [Name]
Incident ID: [ID]

19. Regulatory Communication

Where notification thresholds and applicable obligations are met, the Compliance Lead should initiate the organization's approved regulatory notification process.

The notification should contain:

Incident identification
Incident start time
Affected service/region
Observed customer impact
Current recovery status
Data integrity assessment
Transaction reconciliation status
Actions taken
Expected next update
Contact information

Applicable regulatory and incident-reporting requirements must be confirmed by the organization's compliance/legal function before sending an external notification.

20. Recovery Confirmation
Step 37 — Confirm production traffic

Verify that production requests are reaching Hyderabad.

Step 38 — Confirm transaction processing

Verify successful payment transactions.

Step 39 — Confirm event processing

Verify Kafka events and downstream consumers.

Step 40 — Confirm monitoring

All critical monitoring should report healthy status.

Step 41 — Record RTO

Record:

Disaster start:
First successful recovered transaction:
Measured RTO:
Target RTO: < 5 minutes
Step 42 — Record RPO

Record:

Last primary transaction:
Latest replicated transaction:
Measured RPO:
Target RPO: < 1 minute
21. Incident Stabilization

After payment processing is stable:

Maintain Hyderabad as the active processing region.
Continue monitoring Mumbai.
Continue transaction reconciliation.
Investigate any failed or uncertain transactions.
Preserve logs and incident evidence.
Maintain the incident bridge until stability is confirmed.
Do not immediately fail back to Mumbai.
22. Failback Preconditions

Mumbai must satisfy all required recovery conditions before failback:

Mumbai infrastructure healthy
        ↓
Application healthy
        ↓
Database synchronized
        ↓
Kafka synchronized
        ↓
Security controls validated
        ↓
Payment smoke test passed
        ↓
Incident Commander approval
        ↓
Controlled failback

Failback is a separate controlled procedure and should not be performed simply because Mumbai becomes reachable.

23. Post-Incident Actions

After the incident:

Preserve CloudWatch and application logs.
Record all timestamps.
Calculate RPO.
Calculate RTO.
Identify failed components.
Identify replication gaps.
Reconcile transactions.
Review merchant impact.
Review regulatory communication.
Review security events.
Identify automation improvements.
Update affected runbooks.
Schedule a post-incident review.
24. Evidence Checklist
[ ] Incident ID recorded
[ ] Detection timestamp recorded
[ ] Mumbai failure evidence captured
[ ] Replication status captured
[ ] RPO calculated
[ ] Write fencing confirmed
[ ] Hyderabad readiness confirmed
[ ] DNS failover evidence captured
[ ] Payment smoke test completed
[ ] Idempotency test completed
[ ] Kafka event validation completed
[ ] RTO calculated
[ ] Merchant communication recorded
[ ] Regulatory assessment recorded
[ ] Logs preserved
[ ] Reconciliation completed
[ ] Post-incident review scheduled
25. Exit Criteria

RB-01 can be closed when:

Payment processing is stable in Hyderabad.
Critical application services are healthy.
Database state is validated.
Kafka processing is stable.
No unresolved critical transaction integrity issue remains.
RPO and RTO measurements are recorded.
Required communications are completed.
Incident evidence is preserved.
Recovery ownership is transferred to normal operations.
Post-incident actions have been assigned.
26. Runbook Decision Summary
                 REGION FAILURE
                       |
                       v
              Confirm SEV-1 event
                       |
                       v
              Check replication
                       |
              +--------+--------+
              |                 |
          RPO < 1 min       RPO >= 1 min
              |                 |
              v                 v
        Normal recovery    RPO exception
              |                 |
              +--------+--------+
                       |
                       v
                Fence writes
                       |
                       v
             Activate Hyderabad
                       |
                       v
                Validate DR
                       |
              +--------+--------+
              |                 |
            PASS              FAIL
              |                 |
              v                 v
          DNS failover      Investigate
              |
              v
        Payment smoke test
              |
        +-----+-----+
        |           |
       PASS        FAIL
        |           |
        v           v
    Stabilize    Roll back/
    DR service   escalate
        |
        v
    Measure RPO/RTO
        |
        v
   Incident closure
27. Key Operational Principle

The objective of this runbook is not merely to redirect DNS traffic.

A successful regional recovery requires coordinated recovery of:

DNS
 ↓
Application
 ↓
Database
 ↓
Messaging
 ↓
Security
 ↓
Payment processing
 ↓
Transaction integrity
 ↓
Monitoring
 ↓
Business operations