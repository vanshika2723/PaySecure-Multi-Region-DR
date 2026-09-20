# RB-05 — Network Partition Recovery Runbook

## 1. Runbook Metadata

| Field                   | Details                                                             |
| ----------------------- | ------------------------------------------------------------------- |
| Runbook ID              | RB-05                                                               |
| Scenario                | Network Partition                                                   |
| Severity                | High                                                                |
| Primary Region          | `ap-south-1` — Mumbai                                               |
| DR Region               | `ap-south-2` — Hyderabad                                            |
| Primary Components      | Inter-region connectivity, Aurora, DynamoDB, Redis, Kafka, EKS      |
| RTO Target              | < 5 minutes                                                         |
| RPO Target              | < 1 minute                                                          |
| Primary Risk            | Split-brain and replication divergence                              |
| Primary Owner           | Platform / SRE                                                      |
| Supporting Teams        | Database, Backend, Payments, Security, Network, Business Continuity |
| Regulatory Notification | Assess based on transaction/settlement impact                       |

---

# 2. Scenario Description

A network partition occurs when communication between the Mumbai primary environment and Hyderabad DR environment is interrupted or degraded.

The failure may affect:

* Cross-region database replication
* Kafka replication
* Redis replication
* Application-to-application communication
* Health checks
* Monitoring
* DNS failover decisions
* Administrative access
* Data reconciliation

The most important risk is **split-brain**: both regions may incorrectly believe that they are authoritative and accept conflicting writes.

The recovery objective is therefore to restore connectivity, establish which region is authoritative, protect transaction integrity, and prevent uncontrolled failover.

---

# 3. Trigger Conditions

Initiate RB-05 when one or more of the following occur:

* Mumbai-to-Hyderabad connectivity is unavailable.
* Hyderabad-to-Mumbai connectivity is unavailable.
* Inter-region replication lag increases sharply.
* Kafka Replicator stops progressing.
* Aurora Global Database replication stops.
* Redis Global Datastore replication is degraded.
* Application services cannot reach required regional dependencies.
* Network health checks fail while regional infrastructure remains healthy.
* Cross-region packet loss or timeout is observed.
* Replication status becomes unknown.

### Initial trigger flow

```text
Inter-region connectivity alert
          |
          v
Check network path
          |
     +----+----+
     |         |
   Healthy   Partition
     |         |
 Continue    Isolate affected
 normal      replication/failover
 operation   decisions
```

---

# 4. Roles and Responsibilities

| Role                     | Responsibility                                       |
| ------------------------ | ---------------------------------------------------- |
| Incident Commander       | Owns incident and recovery decision                  |
| Network Engineer         | VPC, routing, connectivity and network-path analysis |
| Platform/SRE             | EKS, AWS infrastructure and monitoring               |
| Database Engineer        | Aurora and DynamoDB replication validation           |
| Backend Engineer         | Application connectivity and service behavior        |
| Payments Team            | Transaction and settlement integrity                 |
| Security Engineer        | Security groups, NACLs, IAM and suspicious traffic   |
| Business Continuity Lead | RPO/RTO and failover coordination                    |
| Communications Lead      | Internal and merchant communication                  |
| Compliance/Legal         | Regulatory impact assessment                         |

---

# 5. Recovery Principles

During a network partition:

1. **Do not immediately fail over only because replication stopped.**
2. Determine which region is authoritative.
3. Prevent simultaneous independent writes where required.
4. Preserve transaction ordering.
5. Protect idempotency.
6. Record replication gaps.
7. Restore connectivity before normal replication is resumed.
8. Reconcile data before returning both regions to normal operation.

---

# 6. Recovery Procedure

## Step 1 — Declare the Incident

**Target: 0–1 minute**

Create a High Severity incident.

Record:

```text
Incident ID
Detection timestamp
Primary region
DR region
First failed connectivity check
Affected services
Current replication status
```

Example:

```text
SEV-1/SEV-2: PaySecure Inter-Region Network Partition
```

---

## Step 2 — Assign Incident Commander

**Target: within 1 minute**

Bring together:

```text
Incident Commander
Network/SRE
Database
Backend
Payments
Security
Business Continuity
Communications
```

Freeze non-essential infrastructure changes until the network condition is understood.

---

## Step 3 — Confirm the Partition

Check whether the failure is:

* Full inter-region outage
* Partial packet loss
* High latency
* DNS resolution failure
* Routing failure
* Security-control failure
* AWS service/network issue

Do not classify an application outage as a network partition without evidence.

---

## Step 4 — Check AWS Regional Health

Check the relevant AWS service and regional status through the approved operations process.

Determine whether the issue is:

```text
Regional
AWS networking
VPC-specific
Subnet-specific
Application-specific
```

Record the observation in the incident timeline.

---

## Step 5 — Check VPC Routing

Inspect the route tables associated with the affected subnets.

Review:

```text
Route tables
Transit Gateway routes
VPC peering / inter-region connectivity
NAT/egress paths
Security Groups
Network ACLs
```

The exact connectivity mechanism deployed by PaySecure must be used as the source of truth.

---

## Step 6 — Check Security Groups and NACLs

Verify that required traffic is not being blocked.

Check:

```text
Source CIDR
Destination CIDR
Required ports
Protocol
Security Group rules
Network ACL rules
```

Do not make broad `0.0.0.0/0` emergency rules as a recovery shortcut.

Any emergency security change must be approved and documented.

---

## Step 7 — Test Connectivity

From approved operational hosts in both regions, test the required private endpoints.

Example:

```bash
ping <approved-private-endpoint>
```

For TCP connectivity:

```bash
nc -vz <endpoint> <port>
```

Where ICMP is not permitted, use the approved TCP/application-level health check instead.

Record:

```text
Source region
Destination
Port
Result
Latency
Packet loss
Timestamp
```

---

## Step 8 — Determine Partition Direction

A partition may be:

```text
Mumbai → Hyderabad unavailable
Hyderabad → Mumbai unavailable
Both directions unavailable
Intermittent
High-latency
```

Do not assume bidirectional failure from a single failed test.

Perform tests from both sides.

---

# 7. Replication Health Assessment

## Step 9 — Check Aurora Global Database

Check Aurora replication lag:

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name AuroraGlobalDBReplicationLag \
  --dimensions Name=DBClusterIdentifier,Value=paysecure-secondary \
  --start-time <START_TIME> \
  --end-time <END_TIME> \
  --period 60 \
  --statistics Average
```

Record:

```text
Last successful replication
Current lag
Replication status
```

---

## Step 10 — Check Aurora Global Cluster Membership

Run:

```bash
aws rds describe-global-clusters \
  --global-cluster-identifier paysecure-global \
  --query 'GlobalClusters[0].GlobalClusterMembers[*].[DBClusterArn,IsWriter]' \
  --output table
```

Confirm which cluster is currently the writer.

### Critical rule

Do **not** promote the DR database merely because replication is delayed.

Promotion requires an explicit Incident Commander decision after data-integrity assessment.

---

## Step 11 — Check DynamoDB Replication

Validate the health of relevant Global Tables.

Check:

```text
Replication status
Replication latency
Throttling
Write conflicts
Failed replication
```

Record any period during which cross-region synchronization was unavailable.

---

## Step 12 — Check Redis Replication

Validate Redis Global Datastore status.

Check:

```text
Primary region
Secondary region
Replication status
Replication lag
Connection failures
Application cache errors
```

Remember that Redis should not become the authoritative source for financial transaction state.

Application recovery must rely on the authoritative transactional data stores.

---

## Step 13 — Check Kafka Replication

Check the MSK Replicator:

```bash
aws kafka list-replicators \
  --query 'Replicators[?ReplicatorName==`paysecure-replicator`].[ReplicatorState,KafkaClustersSummary]' \
  --output json
```

Record:

```text
Replicator state
Source cluster
Target cluster
Last known replicated event
Estimated lag
```

If replication has stopped, identify the last known safe offset/event.

---

# 8. Split-Brain Prevention

## Step 14 — Determine the Active Writer

Before any failover, establish:

```text
Which region is accepting writes?
Which database is writer?
Which application endpoint is active?
Which Kafka path is processing events?
Which DNS target is authoritative?
```

Create a simple incident record:

```text
Authoritative Region: <Mumbai/Hyderabad>
Database Writer: <cluster>
Application Writer: <region>
Kafka Processing Region: <region>
DNS Active Target: <target>
```

---

## Step 15 — Prevent Dual Writes

If there is evidence that both regions are accepting conflicting writes:

1. Stop automatic failover.
2. Restrict write traffic to the confirmed authoritative region.
3. Pause non-essential consumers if required.
4. Preserve transaction/event identifiers.
5. Escalate to Database + Payments teams.
6. Record the exact divergence window.

Do not attempt automatic conflict resolution for financial transactions.

---

## Step 16 — Check Route 53 Health Status

Run:

```bash
aws route53 get-health-check-status \
  --health-check-id HC123456 \
  --query 'HealthCheckObservations[*].[Region,StatusReport.Status]' \
  --output table
```

Confirm whether DNS health-check results reflect the actual service condition.

A network partition between regions must not automatically cause both regions to become active.

---

# 9. Failover Decision

## Step 17 — Decision Point

### Branch A — Network Partition Is Recovering

Conditions:

```text
Connectivity returning
AND
Replication restarting
AND
No split-brain
AND
Primary remains healthy
```

Action:

```text
Keep Mumbai authoritative.
Restore replication.
Monitor convergence.
```

---

### Branch B — Mumbai Unavailable and Hyderabad Healthy

Conditions:

```text
Mumbai service unavailable
AND
Hyderabad healthy
AND
DR data sufficiently current
AND
Incident Commander authorizes failover
```

Action:

```text
Perform controlled DR failover.
```

---

### Branch C — Both Regions Have Uncertain State

Conditions:

```text
Network partition persists
AND
Writer state uncertain
OR
Both regions accepting writes
```

Action:

```text
Freeze non-essential writes.
Prevent additional divergence.
Escalate to Database/Payments/Business Continuity.
Do not perform uncontrolled failover.
```

---

# 10. Controlled DR Failover

## Step 18 — Validate DR Region

Check:

```text
EKS nodes
Application pods
Database
Kafka
DynamoDB
Redis
Secrets
KMS
ALB
Monitoring
```

Example:

```bash
aws eks update-kubeconfig \
  --name paysecure-dr \
  --region ap-south-2 \
  --alias paysecure-dr
```

Then:

```bash
kubectl --context paysecure-dr get nodes -o wide
```

---

## Step 19 — Validate Application Health

Check the DR application health endpoints.

Validate:

```text
API availability
Database connectivity
Kafka connectivity
Authentication
Payment services
Settlement services
Webhook services
```

Do not expose DR traffic until the critical dependencies are healthy.

---

## Step 20 — Validate Database State

Before promotion, record:

```text
Latest committed transaction
Latest replicated transaction
Replication lag
Last successful replication timestamp
```

Calculate potential RPO exposure:

```text
Latest source commit
-
Latest replicated commit
=
Potential replication exposure
```

If exposure exceeds the `<1 minute` target, record the exception explicitly.

---

## Step 21 — Promote DR Database if Authorized

If controlled failover is approved, use the approved Aurora Global Database failover procedure.

Example command from the project appendix:

```bash
aws rds failover-global-cluster \
  --global-cluster-identifier paysecure-global \
  --target-db-cluster-identifier arn:aws:rds:ap-south-2:ACCOUNT:cluster:paysecure-secondary
```

Confirm the new writer:

```bash
aws rds describe-global-clusters \
  --global-cluster-identifier paysecure-global \
  --query 'GlobalClusters[0].GlobalClusterMembers[*].[DBClusterArn,IsWriter]' \
  --output table
```

---

# 11. DNS and Application Recovery

## Step 22 — Validate Route 53 Configuration

Confirm:

```text
Primary target
DR target
Health checks
Failover policy
TTL
EvaluateTargetHealth
```

Do not change DNS manually if automated failover is already correctly operating.

---

## Step 23 — Activate DR Application Traffic

If manual activation is required, follow the approved Route 53 change procedure.

Example structure:

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890 \
  --change-batch '<approved-change-batch>'
```

Record:

```text
Change ID
Timestamp
Operator
Previous target
New target
Reason
```

---

## Step 24 — Scale DR Capacity

If required:

```bash
kubectl --context paysecure-dr \
  -n paysecure \
  scale deployment payment-api \
  --replicas=12
```

Check:

```bash
kubectl --context paysecure-dr \
  -n paysecure \
  get pods -o wide
```

Confirm all required pods are ready before increasing traffic.

---

# 12. Transaction Integrity Validation

## Step 25 — Validate Payment Processing

Run controlled transaction validation.

Check:

```text
Transaction creation
Authorization
Capture
Settlement event
Database state
Idempotency
Audit event
```

No production transaction should be replayed manually without the approved reconciliation process.

---

## Step 26 — Validate Kafka Consumer State

For the DR cluster:

```bash
kafka-consumer-groups.sh \
  --bootstrap-server $DR_BOOTSTRAP \
  --group settlement-processor \
  --describe
```

Check:

```text
Current offset
Log-end offset
Lag
```

Confirm the consumer is progressing.

---

## Step 27 — Validate Settlement

Payments team verifies:

```text
Pending settlements
Successful settlements
Failed settlements
Duplicate detection
Settlement timestamps
```

If reconciliation identifies an uncertain transaction, isolate it for controlled review.

---

## Step 28 — Validate Webhooks

Check:

```text
Webhook queue
Delivery status
Retry count
Merchant acknowledgements
HTTP error rate
```

Resume delayed webhook processing only after payment state is confirmed.

---

## Step 29 — Validate Audit Pipeline

Confirm:

```text
Audit events generated
Audit events consumed
Audit storage updated
No unexplained event gap
```

Record any audit backlog for reconciliation.

---

# 13. Restore Inter-Region Connectivity

## Step 30 — Re-test Network Path

Once the underlying network issue is fixed, test from both directions again.

Record:

```text
Latency
Packet loss
TCP connectivity
Application connectivity
Replication connectivity
```

The target architecture has Mumbai-Hyderabad inter-region latency in the approximate **15–25 ms** range under normal conditions.

This value should be treated as the design/reference latency; the actual incident measurement must be recorded separately.

---

## Step 31 — Restart/Resume Replication Carefully

Do not immediately enable every replication stream simultaneously.

Recommended sequence:

```text
Network
   ↓
Database replication
   ↓
DynamoDB replication
   ↓
Kafka replication
   ↓
Redis replication
   ↓
Application synchronization
```

Monitor each stage before proceeding.

---

## Step 32 — Verify Convergence

Confirm:

```text
Aurora replication healthy
DynamoDB replication healthy
Kafka replication healthy
Redis replication healthy
No unresolved write conflicts
No unexpected transaction divergence
```

Record the time at which both regions become synchronized.

---

# 14. Failback

## Step 33 — Do Not Immediately Fail Back

After the incident is stabilized, keep the recovered region in the appropriate standby state until:

* Network is stable.
* Replication is healthy.
* Data is reconciled.
* Application health is normal.
* Business transaction validation is complete.
* Incident Commander approves failback.

---

## Step 34 — Controlled Failback

Perform failback using the approved database, application and DNS procedures.

Validate:

```text
New writer
DNS target
Application traffic
Kafka consumers
Settlement
Webhooks
Audit
```

Failback should be treated as a separate controlled change, not an automatic continuation of the incident.

---

# 15. CloudWatch Monitoring

During the incident monitor:

### Network

```text
Packet loss
Latency
Connection errors
VPC/TGW metrics
```

### Aurora

```text
AuroraGlobalDBReplicationLag
DatabaseConnections
CPUUtilization
WriteLatency
```

### Kafka

```text
UnderReplicatedPartitions
OfflinePartitionsCount
ConsumerLag
BytesInPerSec
BytesOutPerSec
```

### Application

```text
5xx rate
Request latency
Payment success rate
Settlement backlog
Webhook failures
```

---

# 16. Communication — Internal Engineering

```text
Subject: Network Partition Incident — PaySecure

Incident ID: <ID>
Start Time: <timestamp>

Affected Regions:
ap-south-1 ↔ ap-south-2

Observed Impact:
<services affected>

Network Status:
<partition/recovered>

Database Replication:
<status>

Kafka Replication:
<status>

Current Authoritative Region:
<region>

Failover:
<performed/not performed>

RPO Exposure:
<value>

RTO:
<value>

Transaction Integrity:
<validated/status>

Current Status:
<monitoring/recovered>

Next Action:
<reconciliation/failback/RCA>
```

---

# 17. Merchant Communication

Use only when merchant-facing impact occurred.

```text
Subject: PaySecure Service Update

Dear Merchant,

PaySecure experienced a temporary disruption affecting connectivity between components of our payment infrastructure.

Payment services have been restored/are being stabilized, and transaction integrity checks are in progress.

Some transaction notifications or settlement updates may have experienced delays.

We are monitoring the platform and completing reconciliation activities.

Regards,
PaySecure Gateway Operations
```

---

# 18. Regulatory Impact Assessment

The network partition itself does not automatically imply a regulatory notification.

Compliance must assess:

```text
Was payment processing materially affected?
Was settlement delayed?
Was transaction data lost?
Was there a security incident?
Was customer/payment data exposed?
Were applicable notification thresholds triggered?
```

If notification is required, Compliance/Legal owns the applicable notification process.

---

# 19. RPO/RTO Validation

Record:

### RPO

```text
Latest source transaction/event
-
Latest confirmed replicated transaction/event
=
Actual data exposure
```

Target:

```text
< 1 minute
```

### RTO

```text
Incident detection
→
Service restoration
=
Actual recovery time
```

Target:

```text
< 5 minutes
```

Never mark the target as achieved without recording actual measured values.

---

# 20. Evidence Checklist

Preserve:

* [ ] Incident timeline
* [ ] Connectivity test results
* [ ] Route table evidence
* [ ] Security Group/NACL evidence
* [ ] Aurora replication metrics
* [ ] DynamoDB replication status
* [ ] Redis replication status
* [ ] Kafka Replicator status
* [ ] Consumer offsets
* [ ] Consumer lag
* [ ] Route 53 health-check results
* [ ] DNS changes
* [ ] Application logs
* [ ] Payment validation results
* [ ] Settlement reconciliation
* [ ] Webhook status
* [ ] Audit status
* [ ] RPO calculation
* [ ] RTO calculation
* [ ] Failover/failback timestamps
* [ ] Communication records

Do not store credentials or sensitive payment information in the evidence repository.

---

# 21. Exit Criteria

RB-05 can be closed when:

1. Inter-region connectivity is stable.
2. Authoritative writer is clearly established.
3. No split-brain condition remains.
4. Aurora replication is healthy.
5. DynamoDB replication is healthy.
6. Redis replication is healthy.
7. Kafka replication is healthy.
8. Application traffic is stable.
9. Payment transactions are validated.
10. Settlement processing is stable.
11. Webhooks are stable.
12. Audit events are accounted for.
13. Any replication gap has been reconciled.
14. Actual RPO and RTO are recorded.
15. Incident evidence is preserved.
16. Incident Commander approves closure.

---

# 22. Decision Tree

```text
                  NETWORK PARTITION
                         |
                         v
                Confirm connectivity
                         |
              +----------+----------+
              |                     |
          Connectivity           Partition
            healthy                 |
              |                     v
           Monitor          Check writer state
                                    |
                          +---------+---------+
                          |                   |
                    Single writer        Uncertain/
                    confirmed            dual writer
                          |                   |
                          v                   v
                  Check replication      STOP automatic
                          |               failover
                    +-----+-----+         |
                    |           |         v
                 Healthy      Lagging   Protect writes
                    |           |         |
                    v           v         v
                 Resume      Assess     DB + Payments
                 normal      RPO        investigation
                 operation      |
                               |
                       +-------+-------+
                       |               |
                 Primary healthy   Primary failed
                       |               |
                       v               v
                 Restore network   Validate DR
                                       |
                                +------+------+
                                |             |
                              Healthy       Unhealthy
                                |             |
                                v             v
                           Controlled      Emergency
                           DR failover     recovery
                                |
                                v
                         Validate database
                                |
                                v
                         Validate Kafka
                                |
                                v
                         Validate payments
                                |
                                v
                       Restore replication
                                |
                                v
                            Reconcile
                                |
                                v
                           Failback
                                |
                                v
                         Close incident
```

---

# 23. Post-Incident Actions

## Network

* Identify root cause.
* Review route changes.
* Review connectivity architecture.
* Review monitoring coverage.
* Review inter-region latency and packet-loss alerts.

## Data

* Reconcile Aurora.
* Review DynamoDB conflicts.
* Verify Redis consistency requirements.
* Review Kafka replication gap.
* Confirm no transaction loss.

## Application

* Review retry behavior.
* Review timeout settings.
* Review circuit breakers.
* Review idempotency.
* Review failover automation.

## DR

* Measure actual RPO.
* Measure actual RTO.
* Test controlled failover.
* Update runbook gaps.
* Add missing monitoring.

## Security

* Review all emergency network/security changes.
* Remove temporary rules.
* Confirm least privilege.
* Preserve security evidence.

---

# 24. Final Recovery Principle

A network partition is primarily a **consistency and authority problem**, not simply a connectivity problem.

PaySecure must avoid:

```text
Two active writers
+
Uncontrolled database promotion
+
Duplicate payment processing
+
Uncontrolled Kafka replay
+
Unverified settlement
```

The preferred recovery sequence is:

```text
Detect
  ↓
Confirm partition
  ↓
Establish authority
  ↓
Protect writes
  ↓
Assess replication
  ↓
Choose recovery path
  ↓
Validate transactions
  ↓
Restore connectivity
  ↓
Reconcile data
  ↓
Controlled failback
  ↓
Close incident
```

**Runbook Status:** Production Recovery Procedure
**Runbook ID:** RB-05
**Scenario:** Network Partition
**Owner:** PaySecure Platform / SRE
**Review Frequency:** At least annually and after every major network/DR incident
