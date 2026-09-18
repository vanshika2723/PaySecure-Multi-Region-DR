# Active-Passive vs Active-Active Comparison Matrix

## 1. Purpose

PaySecure Gateway requires a multi-region disaster recovery architecture capable of supporting:

* 3.2 million daily transactions
* ₹500 crore daily transaction value
* 45,000 merchants
* Approximately 1,200 peak TPS
* Target uptime of 99.99%
* RPO of less than 1 minute
* RTO of less than 5 minutes

Two architectures have been designed for evaluation:

1. Active-Passive
2. Active-Active

Both architectures use Mumbai (`ap-south-1`) and Hyderabad (`ap-south-2`) as the two AWS regions.

---

## 2. High-Level Comparison

| Category                    | Active-Passive                         | Active-Active                        |
| --------------------------- | -------------------------------------- | ------------------------------------ |
| Mumbai                      | Active production                      | Active production                    |
| Hyderabad                   | Warm standby                           | Active production                    |
| Normal Traffic              | Mumbai                                 | Mumbai + Hyderabad                   |
| Regional Failure            | DNS failover to Hyderabad              | Traffic removed from failed region   |
| Application Deployment      | Both regions                           | Both regions                         |
| Database Strategy           | Primary + replicated secondary         | Distributed/controlled write model   |
| Transaction Write Authority | Primarily one region                   | Requires explicit ownership model    |
| Data Conflict Risk          | Lower                                  | Higher                               |
| Duplicate Processing Risk   | Controlled through failover            | Requires continuous idempotency      |
| Kafka Processing            | Primary + DR                           | Active processing in both regions    |
| Operational Complexity      | Lower                                  | Higher                               |
| Infrastructure Utilization  | Lower in DR region                     | Higher                               |
| Standby Capacity            | Warm standby                           | Production capacity                  |
| Failover Process            | Promote + activate + DNS switch        | Routing change + capacity adjustment |
| Failback                    | Controlled                             | Controlled                           |
| Cost Profile                | Lower than two full production regions | Higher                               |
| Testing Requirement         | High                                   | Very high                            |
| Split-Brain Risk            | Lower                                  | Higher                               |
| Scalability                 | Regional scale-out during DR           | Both regions scale normally          |
| Architecture Complexity     | Moderate                               | High                                 |

---

## 3. Availability Model

### Active-Passive

Mumbai serves production traffic under normal conditions.

Hyderabad remains available as a warm standby environment.

A regional disaster causes traffic to move from Mumbai to Hyderabad.

```text
Normal:

Users
  |
  v
Mumbai ACTIVE
  |
  v
Hyderabad STANDBY


Failure:

Users
  |
  v
Hyderabad ACTIVE
```

The model relies on a controlled failover procedure.

### Active-Active

Both regions serve production traffic.

```text
Normal:

             Users
               |
            Route 53
             /    \
            /      \
       Mumbai    Hyderabad
       ACTIVE      ACTIVE
```

If one region fails, traffic is directed to the surviving region.

---

## 4. RPO Comparison

The project target is an RPO of less than one minute.

### Active-Passive

Critical data is continuously or near-continuously replicated from Mumbai to Hyderabad.

Aurora PostgreSQL uses cross-region replication.

DynamoDB uses replicated regional tables.

Kafka events are replicated to the DR environment.

Replication lag must remain within the defined operational threshold.

### Active-Active

Data is replicated continuously between regions where the selected service and workload support the required model.

The additional challenge is not only replication lag but also concurrent updates.

The application must identify the authoritative transaction state.

---

## 5. RTO Comparison

The project target is an RTO of less than five minutes.

### Active-Passive

The recovery sequence includes:

1. Detect failure.
2. Confirm regional incident.
3. Fence unsafe writes.
4. Promote DR databases.
5. Activate application workloads.
6. Activate Kafka consumers.
7. Switch Route 53.
8. Validate payment processing.

Because Hyderabad is pre-provisioned as warm standby, the design avoids starting an entirely new environment during the incident.

### Active-Active

The recovery sequence is primarily:

1. Detect regional failure.
2. Confirm incident.
3. Remove unhealthy region from routing.
4. Scale surviving region.
5. Validate transaction state.
6. Monitor transaction processing.

The surviving region is already processing production traffic.

---

## 6. Data Consistency

| Area                     | Active-Passive           | Active-Active                         |
| ------------------------ | ------------------------ | ------------------------------------- |
| Primary Financial Writer | Normally Mumbai          | Requires explicit ownership           |
| Concurrent Writes        | Limited                  | Possible                              |
| Conflict Resolution      | Primarily failover-based | Required continuously                 |
| Transaction Ordering     | Controlled               | More complex                          |
| Idempotency              | Required                 | Critical                              |
| Reconciliation           | Required after failover  | Continuous reconciliation recommended |

Active-passive generally has a simpler transaction-authority model because normal production writes originate from one region.

Active-active requires a clear ownership model so that Mumbai and Hyderabad do not independently modify the same financial transaction.

---

## 7. Database Comparison

### Aurora PostgreSQL

| Consideration            | Active-Passive           | Active-Active                         |
| ------------------------ | ------------------------ | ------------------------------------- |
| Primary Writer           | Mumbai                   | Controlled ownership model            |
| DR Copy                  | Hyderabad                | Cross-region copy                     |
| Promotion                | Required during failover | May be required for regional recovery |
| Conflict Risk            | Lower                    | Higher                                |
| Financial State Handling | Centralized writer       | Requires transaction ownership        |

### DynamoDB

| Consideration     | Active-Passive          | Active-Active                  |
| ----------------- | ----------------------- | ------------------------------ |
| Replication       | Regional replication    | Multi-region replication       |
| Reads             | Can use regional copies | Both regions                   |
| Writes            | Primarily active region | Both regions where appropriate |
| Conflict Handling | Limited                 | Required                       |
| Idempotency       | Required                | Critical                       |

---

## 8. Kafka Comparison

### Active-Passive

Mumbai is the primary Kafka processing environment.

Hyderabad receives replicated topics.

During a regional failure, Hyderabad consumers are activated.

```text
Mumbai Kafka
     |
     | Replication
     v
Hyderabad Kafka
     |
     v
Activated during DR
```

### Active-Active

Both regions can actively process Kafka workloads.

```text
Mumbai Kafka <----Replication----> Hyderabad Kafka
     |                                  |
 Producers/Consumers              Producers/Consumers
```

This requires stronger duplicate-event protection and event conflict handling.

Every important event should contain an event ID and transaction ID.

---

## 9. DNS and Traffic Management

| Feature            | Active-Passive      | Active-Active                |
| ------------------ | ------------------- | ---------------------------- |
| Route 53           | Failover routing    | Latency/health-aware routing |
| Normal Traffic     | Primary region      | Both regions                 |
| Failure Response   | Switch to secondary | Remove failed region         |
| DNS Dependency     | High                | High                         |
| Health Checks      | Required            | Required                     |
| Client DNS Caching | Must be considered  | Must be considered           |

The final DNS implementation must be validated through controlled testing.

---

## 10. Infrastructure Cost

The active-passive design generally requires fewer continuously active production resources in the secondary region.

The Hyderabad environment can operate at warm-standby capacity and scale during a disaster.

Active-active requires both regions to maintain production-capable infrastructure during normal operation.

Therefore, the active-active architecture has greater infrastructure utilization.

Actual AWS cost must be established using the project cost model rather than assuming a fixed percentage difference.

---

## 11. Operational Complexity

### Active-Passive

Primary operational activities include:

* Standby health monitoring
* Replication monitoring
* Failover testing
* Database promotion
* DNS failover
* Standby scaling

### Active-Active

Additional activities include:

* Regional traffic balancing
* Cross-region transaction ownership
* Conflict detection
* Duplicate event handling
* Regional capacity balancing
* Bidirectional event processing
* More complex reconciliation

Therefore, the active-active architecture introduces additional operational controls.

---

## 12. Split-Brain Risk

Split-brain is particularly important for financial transactions.

### Active-Passive

Only Mumbai normally accepts production writes.

During disaster recovery, the team fences the failed region before activating Hyderabad.

This reduces the possibility of simultaneous production writers.

### Active-Active

Both regions normally process production traffic.

If cross-region connectivity fails, both regions may remain operational while unable to exchange state.

The architecture therefore requires explicit transaction ownership and partition-handling rules.

---

## 13. Security Comparison

Security controls must exist in both regions for both architectures.

| Control              | Active-Passive | Active-Active |
| -------------------- | -------------- | ------------- |
| IAM                  | Both regions   | Both regions  |
| KMS                  | Both regions   | Both regions  |
| Secrets Manager      | Both regions   | Both regions  |
| WAF                  | Both regions   | Both regions  |
| Shield               | Both regions   | Both regions  |
| CloudTrail           | Both regions   | Both regions  |
| Network Segmentation | Required       | Required      |
| PCI CDE Controls     | Required       | Required      |
| Security Monitoring  | Required       | Required      |

The security posture should remain consistent during failover.

Emergency recovery must not bypass security controls.

---

## 14. Data Sovereignty

Both architectures use Mumbai and Hyderabad as the proposed Indian AWS regions.

The design therefore provides regional separation while keeping the planned replicated environments within India.

Data-flow documentation must separately identify:

* Payment data
* Merchant data
* Settlement information
* Authentication data
* Audit records
* Logs
* Backups
* Kafka events

External integrations must be evaluated separately for applicable data-transfer requirements.

---

## 15. Monitoring Requirements

Both architectures require continuous monitoring.

### Common Metrics

* Payment success rate
* P99 latency
* HTTP 5xx rate
* Transaction throughput
* Database replication lag
* Kafka replication lag
* Consumer lag
* EKS health
* ALB health
* Route 53 health
* Reconciliation exceptions

### Additional Active-Active Metrics

Active-active requires additional monitoring for:

* Regional traffic distribution
* Transaction ownership
* Conflict events
* Duplicate events
* Cross-region synchronization
* Regional capacity

---

## 16. Failover Complexity

| Step                       | Active-Passive | Active-Active                 |
| -------------------------- | -------------- | ----------------------------- |
| Failure Detection          | Required       | Required                      |
| Incident Confirmation      | Required       | Required                      |
| Write Fencing              | Important      | Critical during partition     |
| Database Promotion         | Required       | Depends on failure/data model |
| Application Activation     | Required       | Mostly already active         |
| DNS Change                 | Required       | Routing adjustment            |
| Capacity Scaling           | Required       | Required                      |
| Transaction Reconciliation | Required       | Required                      |
| Post-Failover Monitoring   | Required       | Required                      |

Active-passive involves more explicit activation steps.

Active-active reduces application activation work but increases distributed-state management complexity.

---

## 17. DR Drill Requirements

Both architectures require regular disaster recovery drills.

### Active-Passive Drill

A drill should validate:

1. Mumbai failure detection.
2. Replication status.
3. Database promotion.
4. Application activation.
5. Kafka consumer activation.
6. DNS failover.
7. Payment validation.
8. Reconciliation.
9. Monitoring.
10. Recovery/failback.

### Active-Active Drill

A drill should additionally validate:

1. Regional traffic distribution.
2. Regional failure.
3. Traffic removal.
4. Capacity increase.
5. Transaction ownership.
6. Duplicate request handling.
7. Kafka duplicate-event handling.
8. Data conflict detection.
9. Reconciliation.
10. Controlled restoration.

---

## 18. Business Impact Comparison

| Business Requirement            | Active-Passive              | Active-Active                                 |
| ------------------------------- | --------------------------- | --------------------------------------------- |
| Regional Resilience             | Supported                   | Supported                                     |
| Payment Continuity              | Through controlled failover | Through surviving active region               |
| Merchant Availability           | Temporary failover period   | Traffic can continue through surviving region |
| Transaction Integrity           | Controlled writer model     | Requires distributed consistency controls     |
| Operational Simplicity          | Lower                       | Higher                                        |
| Infrastructure Utilization      | Lower in standby region     | Higher                                        |
| DR Testing                      | Required                    | Required                                      |
| Scaling During Regional Failure | Important                   | Critical                                      |
| Reconciliation                  | Important                   | Important                                     |

The table describes architectural characteristics rather than an overall ranking.

---

## 19. Decision Criteria

The final architecture selection should be based on measurable project requirements rather than a single architectural preference.

The Business Continuity Review Board should evaluate:

* RPO achievement
* RTO achievement
* Transaction consistency
* Split-brain protection
* Peak TPS capacity
* Merchant impact
* Data sovereignty
* PCI-DSS requirements
* RBI requirements
* NPCI/UPI requirements
* Infrastructure cost
* Operational complexity
* Engineering team capacity
* DR drill results

The selected architecture should be validated through testing against these criteria.

---

## 20. Validation Approach

The architecture should be considered operationally ready only after the following evidence is available:

```text
Architecture
     |
     v
Infrastructure Deployment
     |
     v
Replication Validation
     |
     v
Health Check Validation
     |
     v
Failover Test
     |
     v
Payment Transaction Test
     |
     v
Reconciliation
     |
     v
RPO/RTO Measurement
     |
     v
DR Drill Report
```

The measured RPO and RTO should be recorded during DR exercises.

If the measured result does not meet the target, the architecture or operational procedure must be adjusted and retested.

---

## 21. Summary

The two proposed architectures solve the regional resilience requirement using different operational models.

The active-passive model keeps Mumbai as the normal production region and Hyderabad as a warm standby environment. It provides a controlled failover process and a simpler transaction ownership model.

The active-active model allows both Mumbai and Hyderabad to operate as production regions. It can reduce dependency on a single active region but requires additional controls for transaction ownership, conflict resolution, duplicate processing, capacity management, and cross-region event processing.

Both architectures require:

* Multi-region application deployment
* Replicated data
* Health monitoring
* Route 53 traffic management
* Security controls
* Transaction idempotency
* Kafka event protection
* DR runbooks
* Regular disaster recovery drills
* RPO/RTO measurement
* Compliance validation

The final architecture decision should be made by the Business Continuity Review Board after reviewing technical validation, cost analysis, compliance requirements, operational readiness, and DR drill results.
