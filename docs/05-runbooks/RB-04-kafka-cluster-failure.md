# RB-04 — Kafka Cluster Failure Recovery Runbook

## 1. Runbook Metadata

| Field                   | Details                                                                                         |
| ----------------------- | ----------------------------------------------------------------------------------------------- |
| Runbook ID              | RB-04                                                                                           |
| Scenario                | Kafka Cluster Failure                                                                           |
| Severity                | High                                                                                            |
| Primary Components      | Amazon MSK, settlement processing, webhooks, audit pipeline                                     |
| Primary Region          | `ap-south-1` — Mumbai                                                                           |
| DR Region               | `ap-south-2` — Hyderabad                                                                        |
| RTO Target              | < 5 minutes                                                                                     |
| RPO Target              | < 1 minute                                                                                      |
| Regulatory Notification | Not normally required unless settlement is materially delayed or regulatory impact is confirmed |
| Primary Owner           | Platform / DevOps Engineer                                                                      |
| Supporting Teams        | SRE, Backend, Payments, Database, Security, Business Continuity                                 |
| Communication Lead      | Incident Commander                                                                              |
| Recovery Strategy       | Restore healthy Kafka service or activate DR Kafka path                                         |

---

## 2. Scenario Description

This runbook is executed when the PaySecure Kafka platform experiences a cluster-level failure affecting payment-event processing, settlement workflows, merchant webhooks, audit events, or other asynchronous services.

Kafka is a critical event backbone for the payment platform. A failure may result in consumer lag, unavailable topics, producer failures, delayed settlement events, webhook delays, or loss of processing continuity.

The objective is to:

1. Confirm whether the issue is isolated to Kafka.
2. Protect payment transaction integrity.
3. Prevent duplicate settlement or webhook processing.
4. Restore Kafka processing within the RTO target.
5. Preserve events and ordering wherever technically possible.
6. Use replicated DR Kafka infrastructure if primary recovery is not sufficiently fast.
7. Verify consumer offsets and application health before declaring recovery.
8. Preserve incident evidence for post-incident review.

---

## 3. Trigger Conditions

Initiate RB-04 when one or more of the following conditions occur:

* Amazon MSK cluster becomes unavailable.
* Multiple Kafka brokers become unavailable.
* Producers cannot publish payment events.
* Consumers cannot consume required topics.
* Consumer lag increases rapidly.
* Settlement processor stops receiving events.
* Webhook processor experiences sustained Kafka errors.
* Audit-event ingestion stops.
* Kafka replication to the DR region is unavailable.
* CloudWatch reports sustained broker or cluster health alarms.

### Primary indicators

```text
Kafka broker unavailable
        OR
Producer errors
        OR
Consumer lag > defined threshold
        OR
Settlement event processing stopped
        OR
MSK cluster state unhealthy
```

---

## 4. Roles and Responsibilities

| Role                     | Responsibility                                           |
| ------------------------ | -------------------------------------------------------- |
| Incident Commander       | Owns incident coordination and recovery decision         |
| Platform/SRE             | MSK, networking, infrastructure and Kubernetes checks    |
| Backend Engineer         | Producer/consumer and application validation             |
| Payments Team            | Settlement and payment-event validation                  |
| Database Engineer        | Verify downstream database consistency                   |
| Security Engineer        | Validate access, IAM, encryption and suspicious activity |
| Business Continuity Lead | RTO/RPO and escalation coordination                      |
| Communications Lead      | Internal and merchant communication                      |
| Compliance/Legal         | Assess regulatory notification requirement               |

No production recovery action should be performed without an Incident Commander unless an emergency safety procedure explicitly authorizes autonomous action.

---

# 5. Recovery Procedure

## Step 1 — Declare the Incident

**Target: 0–1 minute**

The monitoring system or engineer detecting the failure must open a High Severity incident.

Record:

* Incident start time
* Detection source
* Kafka cluster
* Affected region
* Affected topics
* First observed error
* Current consumer lag
* Current settlement impact

Example incident title:

```text
SEV-1/SEV-2: PaySecure Kafka Cluster Failure — ap-south-1
```

---

## Step 2 — Assign Incident Commander

**Target: within 1 minute**

The Incident Commander confirms ownership and creates the incident bridge/channel.

Required participants:

```text
Incident Commander
Platform/SRE
Backend
Payments/Settlement
Database
Security
Business Continuity
Communications
```

Start an incident timeline immediately.

---

## Step 3 — Check MSK Cluster State

**Target: 1 minute**

Run:

```bash
aws kafka describe-cluster \
  --cluster-arn arn:aws:kafka:ap-south-1:ACCOUNT:cluster/paysecure-primary/uuid \
  --query 'ClusterInfo.State'
```

Expected healthy state:

```text
ACTIVE
```

If the cluster is not `ACTIVE`, continue investigation.

Record the exact returned state.

---

## Step 4 — Check Broker Health

Review the Amazon MSK cluster and broker metrics in CloudWatch.

Focus on:

```text
ActiveControllerCount
OfflinePartitionsCount
UnderReplicatedPartitions
UnderMinIsrPartitionCount
BytesInPerSec
BytesOutPerSec
MessagesInPerSec
```

A sudden increase in `OfflinePartitionsCount` or `UnderReplicatedPartitions` indicates that Kafka availability or replication may be degraded.

Record metric timestamps and values in the incident timeline.

---

## Step 5 — Check Network Connectivity

**Target: 1 minute**

From an approved application/operations environment, validate connectivity to the Kafka bootstrap endpoints.

Check:

```text
VPC routing
Security Groups
Network ACLs
DNS resolution
Private connectivity
Application-to-MSK connectivity
```

The objective is to distinguish a Kafka cluster failure from a network connectivity failure.

### Decision Point

```text
Can application hosts reach MSK?
        |
   +----+----+
   |         |
  YES       NO
   |         |
Check      Check network,
Kafka      routing and
cluster    security controls
```

Do not modify security controls blindly during an active payment incident.

---

## Step 6 — Retrieve Kafka Bootstrap Information

Obtain the current bootstrap information from the approved MSK configuration.

Example:

```bash
aws kafka get-bootstrap-brokers \
  --cluster-arn arn:aws:kafka:ap-south-1:ACCOUNT:cluster/paysecure-primary/uuid
```

Store the result in the incident evidence.

Do not expose bootstrap credentials or authentication secrets in the incident channel.

---

## Step 7 — Test Kafka Topic Availability

From the approved Kafka administration environment:

```bash
kafka-topics.sh \
  --bootstrap-server $PRIMARY_BOOTSTRAP \
  --list
```

Expected critical topics include examples such as:

```text
payment-events
settlement-events
webhook-events
audit-events
```

Confirm whether:

* Topics are visible.
* Topic metadata can be retrieved.
* Partitions are available.
* Replication is healthy.

---

## Step 8 — Inspect Critical Topics

For each critical topic, inspect partition status:

```bash
kafka-topics.sh \
  --bootstrap-server $PRIMARY_BOOTSTRAP \
  --describe \
  --topic payment-events
```

Repeat for:

```text
settlement-events
webhook-events
audit-events
```

Check:

```text
Partition count
Leader
Replicas
ISR
```

Record any partition without a healthy leader.

---

## Step 9 — Check Consumer Groups

**Target: 1 minute**

Inspect the settlement processor:

```bash
kafka-consumer-groups.sh \
  --bootstrap-server $PRIMARY_BOOTSTRAP \
  --group settlement-processor \
  --describe
```

Repeat for important groups such as:

```text
webhook-processor
audit-processor
payment-event-processor
```

Record:

```text
CURRENT-OFFSET
LOG-END-OFFSET
LAG
```

---

## Step 10 — Determine Consumer-Lag Severity

Use the observed lag and business impact to classify the incident.

### Branch A — Low/Recoverable Lag

If Kafka is recovering and consumer lag is decreasing:

```text
Continue primary-region recovery.
```

### Branch B — High and Increasing Lag

If lag continues increasing:

```text
Investigate producer/consumer failure.
Prepare DR Kafka activation.
```

### Branch C — Cluster Unavailable

If Kafka cannot be recovered within the RTO window:

```text
Escalate to DR Kafka recovery.
```

The Incident Commander records the selected branch.

---

## Step 11 — Check Producer Errors

Review application logs for:

```text
TimeoutException
NotLeaderOrFollowerException
NetworkException
BrokerNotAvailable
RecordTooLargeException
AuthorizationException
```

Example Kubernetes command:

```bash
kubectl -n paysecure logs deployment/payment-api --since=10m | grep -i kafka
```

Check whether producers are:

* timing out,
* retrying,
* failing authentication,
* unable to resolve brokers,
* receiving partition errors.

---

## Step 12 — Protect Payment Transaction Integrity

**Critical safety step**

The Payments team must determine whether payment requests are:

```text
Accepted
Pending
Completed
Failed
Unknown
```

Do not blindly replay payment events.

Use the platform's transaction ID and idempotency key to determine whether an event has already been processed.

Example control:

```text
transaction_id
+
idempotency_key
+
processing_status
```

The same payment event must not result in duplicate settlement.

---

## Step 13 — Check Settlement Impact

The Payments team checks:

```text
Pending settlements
Failed settlements
Settlement queue depth
Settlement processing timestamp
Last successfully processed event
```

Record:

```text
Last known successful settlement event:
<timestamp>

Current pending settlement count:
<count>
```

If settlement delay is material, escalate to Business Continuity and Compliance.

---

## Step 14 — Check Webhook Impact

Inspect webhook processing.

Confirm:

```text
Webhook queue depth
Failed deliveries
Retry count
Last successful delivery
Merchant-facing webhook status
```

Do not manually replay all webhook events without checking idempotency.

Merchant webhook delivery should preserve the existing retry and deduplication controls.

---

## Step 15 — Check Audit Pipeline

Verify whether audit events are still being generated or buffered.

Check:

```text
Audit event producer
Audit Kafka topic
Audit consumer
Audit storage
```

If audit events are buffered elsewhere, record the buffer location and oldest event timestamp.

---

## Step 16 — Check Kafka Replicator

If MSK Replicator is configured, inspect its state:

```bash
aws kafka list-replicators \
  --query 'Replicators[?ReplicatorName==`paysecure-replicator`].[ReplicatorState,KafkaClustersSummary]' \
  --output json
```

Confirm:

```text
Replicator state
Source cluster
Target cluster
Replication status
Approximate replication lag
```

If replication is healthy, the DR Kafka cluster can be considered for activation.

---

## Step 17 — Verify DR Kafka Cluster

**Target: within 2–3 minutes**

Switch the approved operations context to the DR region:

```bash
aws kafka describe-cluster \
  --cluster-arn arn:aws:kafka:ap-south-2:ACCOUNT:cluster/paysecure-dr/uuid \
  --query 'ClusterInfo.State'
```

Expected:

```text
ACTIVE
```

Retrieve bootstrap brokers:

```bash
aws kafka get-bootstrap-brokers \
  --cluster-arn arn:aws:kafka:ap-south-2:ACCOUNT:cluster/paysecure-dr/uuid
```

---

## Step 18 — Validate DR Topics

Run:

```bash
kafka-topics.sh \
  --bootstrap-server $DR_BOOTSTRAP \
  --list
```

Confirm critical topics exist:

```text
payment-events
settlement-events
webhook-events
audit-events
```

Then inspect:

```bash
kafka-topics.sh \
  --bootstrap-server $DR_BOOTSTRAP \
  --describe \
  --topic settlement-events
```

Verify partition and replication availability.

---

## Step 19 — Check DR Consumer Offsets

Inspect the settlement consumer group:

```bash
kafka-consumer-groups.sh \
  --bootstrap-server $DR_BOOTSTRAP \
  --group settlement-processor \
  --describe
```

Compare the DR offsets with the latest known primary offsets.

Record:

```text
Primary last known offset
DR available offset
Estimated replication gap
```

The gap must be assessed against the RPO target.

---

## Step 20 — Calculate Potential RPO Exposure

Determine:

```text
Latest source event timestamp
-
Latest successfully replicated event timestamp
=
Replication exposure
```

If the exposure is greater than the `<1 minute` target:

1. Escalate to Incident Commander.
2. Record the exact exposure.
3. Identify affected event IDs.
4. Prevent duplicate replay.
5. Plan reconciliation after recovery.

Do not claim RPO compliance if measured replication exposure exceeds the target.

---

## Step 21 — Decision: Recover Primary or Activate DR

The Incident Commander makes the operational decision based on evidence.

### Branch 1 — Primary Kafka Recovering

Conditions:

```text
MSK cluster recovering
AND
critical topics available
AND
consumer lag decreasing
AND
settlement processing can resume
```

Action:

```text
Continue primary recovery.
```

### Branch 2 — Primary Kafka Unavailable but DR Healthy

Conditions:

```text
Primary Kafka unavailable
AND
DR Kafka ACTIVE
AND
replication state acceptable
AND
DR application path available
```

Action:

```text
Activate DR Kafka processing path.
```

### Branch 3 — Both Kafka Paths Unhealthy

Conditions:

```text
Primary unavailable
AND
DR unavailable/unhealthy
```

Action:

```text
Activate emergency payment-event buffering/
degraded processing controls and escalate immediately.
```

---

## Step 22 — Prepare DR Application Path

If DR activation is authorized, update the approved application configuration to use the DR Kafka bootstrap endpoint.

Verify:

```text
Kafka bootstrap endpoint
TLS configuration
SASL/IAM authentication
Secrets
Security Groups
DNS/service discovery
```

Do not expose credentials in commands or incident communications.

---

## Step 23 — Scale DR Consumers

Ensure sufficient consumer capacity exists for the expected backlog.

Example:

```bash
kubectl --context paysecure-dr \
  -n paysecure \
  scale deployment settlement-processor \
  --replicas=6
```

Scale only after confirming DR cluster capacity.

Monitor:

```text
CPU
Memory
Kafka consumer lag
Processing rate
Error rate
```

---

## Step 24 — Resume Settlement Processing

Enable the settlement processor according to the approved deployment configuration.

Monitor:

```text
Events consumed/sec
Settlement success rate
Consumer lag
Database writes
Duplicate transaction detection
Processing latency
```

Do not immediately process the entire backlog at unrestricted speed.

Use controlled recovery if downstream systems could be overloaded.

---

## Step 25 — Validate Event Ordering

For payment and settlement events, verify expected event ordering.

Example:

```text
Payment Created
      ↓
Payment Authorized
      ↓
Payment Captured
      ↓
Settlement Created
```

If ordering is violated, stop automated replay for the affected workflow and escalate to the Payments team.

---

## Step 26 — Validate Idempotency

Before replaying delayed events, verify that:

```text
transaction_id
idempotency_key
event_id
```

are checked by the consuming service.

Test with a known safe transaction/event in the approved validation environment.

Expected result:

```text
Duplicate event detected
→ no duplicate settlement
→ original transaction state preserved
```

---

## Step 27 — Recover Webhooks

After payment and settlement processing is stable:

1. Check pending webhook events.
2. Check failed delivery count.
3. Resume retry processing.
4. Monitor HTTP response codes.
5. Verify merchant acknowledgement.
6. Prevent duplicate webhook delivery where idempotency is supported.

Do not prioritize webhook recovery over payment transaction integrity.

---

## Step 28 — Recover Audit Events

Verify audit consumer health.

Check:

```text
Audit consumer lag
Audit event count
Storage ingestion
Event timestamps
```

If a backlog exists, process it in controlled batches.

Record any audit-event gap for post-incident reconciliation.

---

## Step 29 — Monitor Recovery

For at least the initial stabilization period, continuously monitor:

```text
Kafka broker health
Offline partitions
Under-replicated partitions
Consumer lag
Producer errors
Settlement success rate
Webhook failures
Audit processing
Database latency
Application error rate
```

CloudWatch and application dashboards must remain under active observation.

---

## Step 30 — Confirm Business Transactions

Payments team validates a controlled set of transactions.

Verify:

```text
Payment status
Settlement status
Event ID
Transaction ID
Idempotency
Webhook status
Audit record
```

The validation must cover the complete event path:

```text
API
 ↓
Kafka
 ↓
Consumer
 ↓
Database
 ↓
Settlement/Webhook
 ↓
Audit
```

---

## Step 31 — Assess Regulatory Impact

The source scenario specifies that regulatory notification is **not normally required unless settlement delay occurs**.

Compliance must assess:

```text
Was settlement materially delayed?
Was customer/payment data lost?
Was there transaction inconsistency?
Was there a security event?
Were regulatory thresholds triggered?
```

If notification is required, Compliance/Legal coordinates the applicable notification process.

---

## Step 32 — Internal Engineering Notification

Send:

```text
Subject: RESOLVED — PaySecure Kafka Cluster Failure

Incident: RB-04
Primary Region: ap-south-1
DR Region: ap-south-2
Start Time: <timestamp>
Recovery Time: <timestamp>

Impact:
<affected services and duration>

Kafka Status:
<recovered/DR activated>

Settlement Status:
<status>

Consumer Lag:
<final lag>

RPO Exposure:
<measured exposure>

RTO:
<measured recovery time>

Current Status:
Monitoring completed and services are stable.

Next Steps:
Root-cause analysis and post-incident actions will follow.
```

---

## 6. Merchant Communication Template

Use only if merchant-facing impact occurred.

```text
Subject: Service Update — Delayed Event Processing

Dear Merchant,

We experienced a temporary disruption affecting asynchronous payment event processing.

Payment processing has been restored and our systems are currently being monitored.

Some transaction-related notifications or settlement updates may have experienced a delay.

We are completing reconciliation checks to ensure transaction integrity.

No action is required from merchants unless separately communicated by PaySecure.

Regards,
PaySecure Gateway Operations
```

---

# 7. Recovery Validation Checklist

The incident can move toward closure only after:

* [ ] MSK cluster healthy
* [ ] Critical Kafka topics available
* [ ] No unexpected offline partitions
* [ ] Replication healthy
* [ ] Producer errors returned to baseline
* [ ] Consumer lag decreasing
* [ ] Settlement processor healthy
* [ ] Settlement backlog controlled
* [ ] No duplicate settlements detected
* [ ] Webhook processor healthy
* [ ] Audit processor healthy
* [ ] Database writes validated
* [ ] Idempotency verified
* [ ] DR replication status documented
* [ ] RPO exposure recorded
* [ ] RTO recorded
* [ ] Merchant impact assessed
* [ ] Regulatory impact assessed
* [ ] Monitoring stable

---

# 8. Exit Criteria

RB-04 may be closed when:

1. Kafka service is stable.
2. All critical topics are operational.
3. Consumer lag is within the defined operational threshold.
4. Settlement processing is normal.
5. Webhooks are processing normally.
6. Audit events are being ingested.
7. No unexplained transaction duplication exists.
8. Any replication gap has been reconciled.
9. RPO and RTO measurements are recorded.
10. Incident communications are complete.
11. Evidence has been preserved.
12. Incident Commander approves closure.

---

# 9. Evidence Checklist

Preserve:

```text
MSK cluster state
CloudWatch metric screenshots/exports
Kafka topic descriptions
Consumer-group offsets
Consumer-lag measurements
MSK Replicator status
Application logs
Settlement queue metrics
Webhook metrics
Audit metrics
DR activation timestamps
DNS/configuration changes
Deployment changes
Incident timeline
Communication records
RPO calculation
RTO calculation
```

Do not store credentials, private keys, or sensitive payment data in the evidence repository.

---

# 10. Post-Incident Actions

Within the post-incident review:

### Infrastructure

* Review broker failure cause.
* Review MSK capacity.
* Review partition distribution.
* Review replication health.
* Review network dependencies.

### Application

* Review producer retry behavior.
* Review consumer retry behavior.
* Review dead-letter handling.
* Review idempotency controls.
* Review event ordering.

### Settlement

* Reconcile delayed events.
* Verify settlement completeness.
* Verify duplicate prevention.
* Confirm merchant-facing status.

### DR

* Validate MSK replication.
* Validate DR consumer offsets.
* Measure actual RPO.
* Measure actual RTO.
* Update DR procedures if gaps were observed.

### Monitoring

Add or improve alarms for:

```text
OfflinePartitionsCount
UnderReplicatedPartitions
UnderMinIsrPartitionCount
ConsumerLag
ProducerErrors
ConsumerErrors
ReplicationLag
SettlementBacklog
WebhookFailureRate
```

---

# 11. Recommended CloudWatch Alarm Definitions

The following alarms should be configured according to the deployed MSK metric dimensions and monitoring standards.

### Alarm 1 — Offline Partitions

```text
Namespace: AWS/Kafka
Metric: OfflinePartitionsCount
Statistic: Maximum
Period: 60 seconds
Evaluation Periods: 1
Threshold: > 0
Severity: Critical
```

### Alarm 2 — Under-Replicated Partitions

```text
Namespace: AWS/Kafka
Metric: UnderReplicatedPartitions
Statistic: Maximum
Period: 60 seconds
Evaluation Periods: 3
Threshold: > 0
Severity: High
```

### Alarm 3 — Consumer Lag

```text
Metric: Application Consumer Lag
Period: 60 seconds
Evaluation Periods: 3
Threshold: Team-defined critical lag
Severity: High
```

The exact consumer-lag threshold should be established from normal PaySecure production traffic rather than invented during the incident.

---

# 12. Decision Tree

```text
                 Kafka Failure Detected
                          |
                          v
                 Check MSK Cluster
                          |
             +------------+------------+
             |                         |
          Healthy                   Unhealthy
             |                         |
             v                         v
     Check consumer lag         Check broker/partition
             |                   and network health
       +-----+-----+                   |
       |           |                   v
     Falling     Rising          Can primary recover?
       |           |                   |
       v           v              +----+----+
   Continue     Investigate       |         |
   monitoring   DR readiness     YES       NO
                                   |         |
                                   v         v
                              Recover     Check DR
                              primary     Kafka
                                             |
                                      +------+------+
                                      |             |
                                    Healthy      Unhealthy
                                      |             |
                                      v             v
                                Activate DR    Emergency
                                processing     degraded path
                                      |
                                      v
                              Validate offsets
                                      |
                                      v
                              Resume consumers
                                      |
                                      v
                              Validate settlement
                                      |
                                      v
                              Validate webhooks
                                      |
                                      v
                              Validate audit
                                      |
                                      v
                              Measure RPO/RTO
                                      |
                                      v
                                Close incident
```

---

# 13. Recovery Timing Target

| Activity                   |  Target |
| -------------------------- | ------: |
| Incident declaration       | 0–1 min |
| MSK state assessment       |   1 min |
| Topic/partition assessment | 1–2 min |
| Consumer-lag assessment    |   1 min |
| DR readiness check         | 1–2 min |
| DR activation decision     | ≤ 3 min |
| Consumer recovery          | 1–2 min |
| Transaction validation     | 1–2 min |
| Initial stabilization      | ≤ 5 min |

The actual recovery time must be measured from incident detection to confirmed service recovery. These are operational targets, not guaranteed timings.

---

# 14. Recovery Principle

The priority during a Kafka outage is **transaction integrity before throughput**.

PaySecure must avoid:

```text
Duplicate settlement
+
Incorrect transaction ordering
+
Uncontrolled replay
+
Unverified consumer offsets
```

A slower controlled recovery is preferable to uncontrolled event replay that can create financial inconsistencies.

The final incident record must clearly document:

```text
What failed
→
What was affected
→
What was recovered
→
Whether DR was activated
→
RPO achieved
→
RTO achieved
→
What remains to be improved
```

**Runbook Status:** Production Recovery Procedure
**Runbook ID:** RB-04
**Scenario:** Kafka Cluster Failure
**Owner:** PaySecure Platform / SRE
**Review Frequency:** At least annually and after every Kafka-related production incident
