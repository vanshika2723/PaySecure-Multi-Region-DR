# RB-10 — Single-AZ Power Failure

**Runbook ID:** RB-10
**Scenario:** Data Centre Power Failure — Single Availability Zone
**Severity:** High
**Primary Region:** `ap-south-1` — Mumbai
**DR Region:** `ap-south-2` — Hyderabad
**Target RTO:** < 5 minutes
**Target RPO:** < 1 minute
**Primary Systems:** EKS, Aurora PostgreSQL, MSK Kafka, ALB, Route 53, CloudWatch
**Incident Commander:** Platform / SRE Lead
**Supporting Teams:** Database, Application, Kafka, Network, Security, Payments Operations

---

## 1. Scenario Description

One Availability Zone in the primary Mumbai region (`ap-south-1`) loses power.

According to the project scenario, the event affects approximately **33% of compute capacity**, **one database replica**, and **two Kafka brokers**.

The primary objective is to determine whether the remaining Availability Zones can continue processing payment traffic safely or whether PaySecure must activate the Hyderabad cross-region DR environment.

The first response should attempt automatic recovery through:

1. EKS pod rescheduling
2. Kubernetes node replacement
3. Aurora Multi-AZ recovery/failover
4. Kafka broker recovery and partition reassignment
5. Load balancer health-based traffic removal
6. Capacity validation

Cross-region failover must be considered if the remaining Mumbai capacity cannot safely sustain payment traffic or if multiple critical dependencies become unhealthy.

---

# 2. Incident Objectives

The response team must:

1. Confirm that the issue is isolated to one Availability Zone.
2. Identify affected compute nodes, database replicas and Kafka brokers.
3. Confirm that healthy AZs remain operational.
4. Prevent traffic from being sent to unhealthy targets.
5. Verify EKS automatic rescheduling.
6. Verify Aurora database availability.
7. Verify Kafka broker and partition health.
8. Confirm payment API availability.
9. Assess remaining capacity against peak demand.
10. Determine whether cross-region failover is required.
11. Maintain payment transaction integrity.
12. Validate RPO and RTO.
13. Capture evidence for post-incident analysis.

---

# 3. Initial Detection

Possible detection sources:

* CloudWatch alarms
* EKS node health alarms
* ALB target health
* Aurora database alarms
* MSK broker alarms
* Application error-rate alarms
* Payment transaction failure alerts
* Merchant reports
* AWS service/health notifications

### Initial timing target

| Activity                        |   Target |
| ------------------------------- | -------: |
| Alarm detection                 | 0–30 sec |
| Incident acknowledgement        |  < 1 min |
| AZ identification               |  < 2 min |
| Application capacity assessment |  < 3 min |
| Cross-region decision           |  < 4 min |
| Recovery/failover execution     |  < 5 min |

These are operational targets for this runbook and should be validated during DR drills.

---

# 4. Step-by-Step Recovery Procedure

## Step 1 — Declare the Incident

Incident Commander declares:

> **RB-10 activated: Single-AZ Power Failure in ap-south-1.**

Record:

* Detection timestamp
* Affected AZ
* Affected services
* Current transaction error rate
* Current TPS
* Number of affected EKS nodes
* Aurora status
* Kafka broker status

---

## Step 2 — Assign Incident Roles

Assign:

* Incident Commander
* EKS/Application Lead
* Database Lead
* Kafka Lead
* Network/DNS Lead
* Security Lead
* Payments Operations Lead
* Communications Owner

No individual should make the cross-region failover decision without the Incident Commander and Payments Operations Lead being informed.

---

## Step 3 — Confirm the Affected Availability Zone

Review EC2/EKS infrastructure:

```bash
aws ec2 describe-instances \
  --region ap-south-1 \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,AvailabilityZone,State.Name]' \
  --output table
```

Identify whether approximately one-third of compute capacity is unavailable.

---

## Step 4 — Check EKS Node Health

Update the Mumbai cluster context:

```bash
aws eks update-kubeconfig \
  --name paysecure-primary \
  --region ap-south-1 \
  --alias paysecure-primary
```

Check unhealthy nodes:

```bash
kubectl --context paysecure-primary get nodes -o wide
```

Then:

```bash
kubectl --context paysecure-primary get nodes \
  --field-selector='status.conditions[?(@.type=="Ready")].status=False'
```

Record:

* NotReady nodes
* AZ placement
* Number of available nodes
* Number of schedulable nodes

---

## Step 5 — Verify Pod Rescheduling

Check payment workloads:

```bash
kubectl --context paysecure-primary \
  -n paysecure get pods -o wide
```

Check pending pods:

```bash
kubectl --context paysecure-primary \
  -n paysecure get pods \
  --field-selector=status.phase=Pending
```

If pods are automatically rescheduled to healthy AZs, continue monitoring.

---

## Step 6 — Check Deployment Availability

```bash
kubectl --context paysecure-primary \
  -n paysecure get deployment
```

Check payment API:

```bash
kubectl --context paysecure-primary \
  -n paysecure get deployment payment-api \
  -o wide
```

Confirm:

* Desired replicas
* Available replicas
* Ready replicas
* Unavailable replicas

---

## Step 7 — Check EKS Scheduling Capacity

Inspect node resource availability:

```bash
kubectl --context paysecure-primary \
  top nodes
```

If `kubectl top` is unavailable, use:

```bash
kubectl --context paysecure-primary \
  describe nodes
```

Check:

* CPU utilisation
* Memory utilisation
* Pod density
* Pending workloads
* Node pressure conditions

---

## Step 8 — Check ALB Target Health

Identify the payment ALB:

```bash
aws elbv2 describe-load-balancers \
  --region ap-south-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `paysecure`)].[LoadBalancerArn,DNSName,State.Code]' \
  --output table
```

Check target groups:

```bash
aws elbv2 describe-target-groups \
  --region ap-south-1 \
  --query 'TargetGroups[].[TargetGroupArn,TargetGroupName,HealthCheckPath]' \
  --output table
```

Confirm unhealthy targets are removed from traffic.

---

## Step 9 — Validate Payment API

Test the health endpoint:

```bash
curl -fsS https://api.paysecure.in/health
```

Expected result:

```text
HTTP 200
```

Also verify:

* API latency
* HTTP 5xx rate
* connection failures
* payment authorization failures

---

# 5. Aurora Database Recovery

## Step 10 — Check Aurora Cluster

```bash
aws rds describe-db-clusters \
  --region ap-south-1 \
  --query 'DBClusters[?contains(DBClusterIdentifier, `paysecure`)].[DBClusterIdentifier,Status,Engine]' \
  --output table
```

---

## Step 11 — Check Aurora Instances

```bash
aws rds describe-db-instances \
  --region ap-south-1 \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `paysecure`)].[DBInstanceIdentifier,DBInstanceStatus,AvailabilityZone,DBInstanceClass]' \
  --output table
```

Confirm whether the affected AZ contained one Aurora replica.

---

## Step 12 — Verify Writer Availability

Check the current writer:

```bash
aws rds describe-db-clusters \
  --region ap-south-1 \
  --query 'DBClusters[?contains(DBClusterIdentifier, `paysecure`)].DBClusterMembers[*].[DBInstanceIdentifier,IsClusterWriter]' \
  --output table
```

If Aurora has automatically failed over to a healthy replica, verify that the new writer is healthy.

---

## Step 13 — Check Replication Lag

Review Aurora replication metrics:

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name AuroraReplicaLag \
  --dimensions Name=DBClusterIdentifier,Value=paysecure-primary \
  --start-time 2026-03-23T14:00:00Z \
  --end-time 2026-03-23T14:10:00Z \
  --period 60 \
  --statistics Average
```

Use the actual incident start/end timestamps during production execution.

---

# 6. Kafka Recovery

## Step 14 — Check MSK Cluster

```bash
aws kafka describe-cluster \
  --cluster-arn <PAYSECURE_MSK_CLUSTER_ARN> \
  --query 'ClusterInfo.State'
```

Expected state:

```text
ACTIVE
```

---

## Step 15 — Check Kafka Broker Distribution

Confirm whether the two brokers in the affected AZ are unavailable.

Review:

* Broker availability
* Partition leadership
* Under-replicated partitions
* Offline partitions

---

## Step 16 — Check Kafka Topics

```bash
kafka-topics.sh \
  --bootstrap-server $BOOTSTRAP \
  --list
```

Confirm critical topics exist:

* payment events
* settlement
* webhook events
* audit events
* transaction status events

---

## Step 17 — Check Consumer Groups

```bash
kafka-consumer-groups.sh \
  --bootstrap-server $BOOTSTRAP \
  --group settlement-processor \
  --describe
```

Review:

* Consumer lag
* Active consumers
* Partition ownership
* Rebalancing status

---

## Step 18 — Check Event Processing

Confirm:

* Payment events continue to publish
* Settlement consumers are processing
* Webhook events are being consumed
* Audit events continue to be written

If Kafka automatically rebalances successfully, continue with the Mumbai recovery path.

---

# 7. Capacity Assessment

## Step 19 — Calculate Remaining Compute Capacity

The scenario assumes approximately **33% compute capacity** is lost.

The remaining infrastructure therefore needs to safely process the current transaction load.

Review:

* Current TPS
* CPU utilisation
* Memory utilisation
* EKS desired/available replicas
* ALB request rate
* Payment API latency
* Database connections
* Kafka consumer lag

---

## Step 20 — Compare Current Load With Capacity

PaySecure's architecture uses a peak reference of approximately **1,200 TPS**.

Decision should be based on actual current traffic and validated capacity, not merely the percentage of failed infrastructure.

### Decision Point A

**If healthy Mumbai AZs have sufficient capacity:**

→ Continue operating in `ap-south-1`.

**If capacity is approaching predefined safety thresholds:**

→ Scale remaining Mumbai capacity.

**If capacity cannot safely support payment traffic:**

→ Prepare cross-region failover.

---

## Step 21 — Scale EKS if Required

Example:

```bash
kubectl --context paysecure-primary \
  -n paysecure scale deployment payment-api \
  --replicas=12
```

Use the approved production replica count determined by the capacity model.

Then verify:

```bash
kubectl --context paysecure-primary \
  -n paysecure get pods -o wide
```

---

## Step 22 — Verify Horizontal Scaling

Check:

```bash
kubectl --context paysecure-primary \
  -n paysecure get hpa
```

Confirm:

* Desired replicas
* Current replicas
* Available replicas
* CPU/memory metrics

---

# 8. Cross-Region Failover Decision

Cross-region failover should **not** be triggered solely because one AZ is unavailable.

The Incident Commander should consider Hyderabad only when one or more of the following conditions exist:

1. Remaining Mumbai compute capacity is insufficient.
2. Payment API error rate remains above the approved threshold.
3. Aurora cannot maintain healthy database availability.
4. Kafka cannot maintain required event processing.
5. Multiple critical services are degraded simultaneously.
6. The AZ outage is expanding beyond the original failure domain.
7. AWS service information indicates a broader regional event.
8. The projected recovery time exceeds the RTO.

---

# 9. Decision Branches

## Branch A — Automatic Recovery Successful

Conditions:

* EKS pods rescheduled
* Aurora healthy
* Kafka healthy
* ALB healthy
* Payment API healthy
* Capacity sufficient

Action:

→ Remain in Mumbai.

Continue enhanced monitoring for at least 30 minutes.

---

## Branch B — Mumbai Capacity Degraded

Conditions:

* One AZ unavailable
* Remaining AZs operational
* Application works
* Capacity is approaching safety limits

Action:

→ Scale workloads in healthy AZs.

→ Enable additional capacity according to the approved scaling policy.

→ Monitor payment success rate and latency continuously.

Do **not** fail over unless capacity remains insufficient.

---

## Branch C — Mumbai Cannot Safely Process Payments

Conditions:

* Critical services remain unavailable
* Database recovery is unsuccessful
* Kafka remains degraded
* Capacity is insufficient
* RTO risk is increasing

Action:

→ Declare cross-region DR decision.

→ Validate Hyderabad readiness.

→ Execute RB-01 regional recovery procedure if full regional failover becomes necessary.

---

# 10. Validate Hyderabad DR Readiness

Check EKS:

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

Check:

```bash
kubectl --context paysecure-dr \
  -n paysecure get deployment
```

Validate:

* EKS nodes
* Payment API deployment
* Aurora secondary
* DynamoDB availability
* Redis availability
* MSK replication
* Route 53 health checks
* Secrets/KMS
* ALB

---

# 11. Monitoring and CloudWatch Alarms

Recommended alarms for this scenario:

### EKS Node Availability

```text
Metric: node readiness / unhealthy nodes
Condition: unhealthy nodes > 0
Evaluation: 2 consecutive periods
```

### ALB 5xx

```text
Metric: HTTPCode_Target_5XX_Count
Threshold: > approved baseline
Evaluation: 2 consecutive periods
```

### ALB Target Health

```text
Metric: UnHealthyHostCount
Condition: > 0 for critical payment target group
Evaluation: 2 consecutive periods
```

### Aurora Availability

```text
Metric: DatabaseConnections
Metric: CPUUtilization
Metric: ReplicaLag
Condition: sustained deviation from approved baseline
```

### Kafka

Monitor:

* Under-replicated partitions
* Offline partitions
* Consumer lag
* Broker health

Alarm when critical payment or settlement topics exceed their approved lag threshold.

Threshold values must be calibrated from PaySecure's production baseline during implementation and DR drills.

---

# 12. Transaction Integrity Validation

Before closing the incident, verify:

* No duplicate payment transactions
* No missing payment events
* No unexpected transaction-state transitions
* Settlement queue is processing
* Webhook delivery is recovering
* Idempotency keys remain valid
* Database writer is correct
* Kafka consumer offsets are progressing

Run a controlled synthetic transaction where permitted.

---

# 13. Communication — Internal Engineering Notification

> **Subject: RB-10 Single-AZ Power Failure — PaySecure**
>
> PaySecure Engineering has activated RB-10 following an Availability Zone power failure in `ap-south-1`.
>
> Impact:
>
> * One AZ unavailable
> * Approximately 33% compute capacity affected
> * Database/Kafka components in the affected AZ under assessment
>
> Current status:
>
> * EKS rescheduling: [Healthy/Degraded]
> * Aurora: [Healthy/Degraded]
> * Kafka: [Healthy/Degraded]
> * Payment API: [Healthy/Degraded]
> * Cross-region failover: [Not Required/Under Evaluation/Activated]
>
> Incident Commander: [Name]
>
> Next update: [Time]

---

# 14. Communication — Merchant Notification

> **Subject: PaySecure Service Availability Update**
>
> We are currently managing an infrastructure incident affecting a portion of our payment processing environment.
>
> Our redundant infrastructure is actively recovering affected workloads, and payment services remain under continuous monitoring.
>
> Merchants will receive further updates if transaction processing is materially affected.
>
> PaySecure Operations

---

# 15. Regulatory Assessment

The Incident Commander and Compliance Lead must assess:

* Duration of service impact
* Number of failed/delayed transactions
* Transaction integrity
* Settlement impact
* Data loss
* Customer/merchant impact
* Whether applicable regulatory notification thresholds are triggered

If the incident remains isolated to one AZ and automatic recovery succeeds without material transaction or settlement impact, document the assessment and rationale.

If the incident develops into a broader outage, data-loss event, or material payment disruption, follow the applicable regulatory notification procedure.

---

# 16. RPO Validation

Confirm:

```text
Observed replication lag: ______
Maximum transaction data exposure: ______
RPO target: < 1 minute
Status: PASS / FAIL
```

No failover should be declared complete until transaction consistency has been assessed.

---

# 17. RTO Validation

Record:

```text
Incident detection: ______
Incident acknowledgement: ______
AZ identification: ______
Application recovery: ______
Database recovery: ______
Kafka recovery: ______
Full service recovery: ______
Total recovery time: ______
RTO target: < 5 minutes
Status: PASS / FAIL
```

---

# 18. Evidence Checklist

Collect:

* CloudWatch alarm screenshots/export
* EKS node status
* EKS pod status
* ALB target health
* Aurora cluster status
* Aurora replica status
* Aurora replication metrics
* Kafka broker status
* Kafka consumer lag
* Application logs
* Payment success/failure metrics
* Route 53 health status
* Incident timeline
* Commands executed
* Decisions and approvals
* Communication records

Store evidence according to PaySecure's incident-retention policy.

---

# 19. Exit Criteria

RB-10 can be closed when:

* Failed AZ status is understood.
* Required workloads are running in healthy AZs.
* EKS has stable capacity.
* Aurora is healthy.
* Kafka is healthy.
* Payment API is stable.
* Transaction processing is normal.
* No unexpected transaction duplication is detected.
* Settlement processing is normal.
* RPO is validated.
* RTO is recorded.
* Monitoring shows stable service.
* Incident Commander approves closure.

---

# 20. Post-Incident Actions

Within the post-incident review:

1. Identify root cause of AZ power failure.
2. Determine exact compute capacity lost.
3. Measure EKS rescheduling time.
4. Measure Aurora recovery time.
5. Measure Kafka recovery/rebalancing time.
6. Review payment transaction impact.
7. Review capacity headroom.
8. Identify workloads that were not sufficiently distributed.
9. Verify pod anti-affinity configuration.
10. Verify Multi-AZ database placement.
11. Verify Kafka broker distribution.
12. Review autoscaling configuration.
13. Review CloudWatch alarm sensitivity.
14. Update capacity model.
15. Update this runbook based on drill/incident evidence.

---

# 21. Preventive Controls

PaySecure should maintain:

* Multi-AZ EKS worker capacity
* Pod anti-affinity for critical payment workloads
* Multi-AZ Aurora deployment
* Distributed Kafka brokers
* Load balancer health checks
* Automated EKS rescheduling
* Horizontal Pod Autoscaling
* Capacity headroom
* Cross-region DR environment
* Route 53 health checks
* Continuous CloudWatch monitoring
* Regular AZ-failure simulations
* Annual DR drill validation

---

# 22. Decision Tree

```text
                 SINGLE-AZ FAILURE
                        |
                        v
              Is one AZ confirmed down?
                   /           \
                 NO             YES
                 |               |
              Investigate        v
                           EKS rescheduling
                                 |
                                 v
                       Are payment workloads
                           healthy?
                        /             \
                      YES              NO
                       |               |
                       v               v
                 Check Aurora      Investigate
                       |            EKS capacity
                       v
                Aurora healthy?
                 /          \
               YES           NO
                |             |
                v             v
          Check Kafka     Aurora recovery
                |             |
                v             v
          Kafka healthy?  Recovery success?
           /       \        /       \
         YES       NO     YES       NO
          |         |      |         |
          v         v      v         v
      Capacity   Kafka   Continue   DR decision
      assessment recovery Mumbai       |
          |                          |
          v                          v
     Capacity sufficient?      Hyderabad ready?
       /          \             /          \
     YES          NO          YES           NO
      |            |           |             |
      v            v           v             v
 Continue      DR decision   Activate      Escalate
 Mumbai                        DR
```

---

# 23. Recovery Principle

A Single-AZ power failure is primarily an **intra-region resilience event**.

The first objective is to allow the healthy Availability Zones to absorb the failure through EKS rescheduling, Aurora recovery, Kafka redistribution and load-balancer health management.

Cross-region failover should be used when the remaining Mumbai infrastructure cannot safely maintain payment processing, when critical dependencies remain unavailable, or when the event threatens the defined RTO.

The final recovery decision must prioritize:

**Payment integrity → customer availability → transaction consistency → capacity safety → RPO/RTO compliance.**
