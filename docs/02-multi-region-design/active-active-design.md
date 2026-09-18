# Active-Active Multi-Region Architecture Design

## 1. Architecture Overview

The active-active architecture provides a second multi-region option for PaySecure Gateway. In this model, both AWS Mumbai (`ap-south-1`) and AWS Hyderabad (`ap-south-2`) are active production regions.

Unlike the active-passive architecture, Hyderabad is not maintained only as a standby environment. Both regions receive production traffic and process application workloads.

The objective is to improve regional resilience, distribute application traffic, reduce dependency on a single production region, and provide continuous service availability during a regional incident.

The logical architecture is:

```text
                           Internet / Merchants
                                  |
                                  v
                           Amazon Route 53
                     Latency / Health-Based Routing
                              /          \
                             /            \
                            v              v
                    Mumbai Region      Hyderabad Region
                    ap-south-1          ap-south-2
                         ACTIVE              ACTIVE
                           |                   |
                          WAF                 WAF
                           |                   |
                          ALB                 ALB
                           |                   |
                         EKS                 EKS
                           |                   |
          +----------------+-----+   +---------+----------------+
          |                      |   |                          |
       Aurora               DynamoDB                       Aurora
       Primary/Global       Global Tables                  Global
          |                      |                             |
          +----------------------+-----------------------------+
                                 |
                        Cross-Region Replication
                                 |
                              Kafka
                         Replicated Events
```

Both regions require production-grade security, monitoring, capacity, deployment automation, and data replication.

---

## 2. Active-Active Traffic Model

In active-active mode, Route 53 distributes user traffic between Mumbai and Hyderabad.

Traffic can be directed using latency-based or health-aware routing according to the final DNS design.

A simplified request flow is:

```text
Merchant
   |
   v
Route 53
   |
   +--------------------+
   |                    |
   v                    v
Mumbai ALB          Hyderabad ALB
   |                    |
   v                    v
Mumbai EKS          Hyderabad EKS
   |                    |
   +---------+----------+
             |
       Shared Replicated
          Data Layer
```

Both regions must be capable of handling production requests.

If one region becomes unavailable, the unhealthy region is removed from DNS routing and traffic is directed to the remaining healthy region.

This means regional failure does not require bringing an entirely new application environment online.

---

## 3. Regional Capacity

Because both regions are active, each region requires sufficient capacity to process its assigned production workload.

Capacity planning must consider the PaySecure peak requirement of approximately 1,200 TPS.

A regional failure creates a second requirement: the surviving region must be able to absorb the traffic previously handled by the failed region.

For example, if traffic is distributed between Mumbai and Hyderabad during normal operation, the remaining region must have an approved scale-out mechanism.

The architecture therefore requires:

* EKS autoscaling
* Production-tested pod limits
* Node autoscaling
* ALB capacity
* Database capacity planning
* Kafka broker capacity
* Redis capacity
* Monitoring-based scaling
* Load testing

The DR drill must test this condition rather than assuming that the surviving region can automatically absorb all traffic.

---

## 4. Application Deployment

The same application version should be deployed to both regions.

The twelve core PaySecure services are:

1. API Gateway Service
2. Authentication Service
3. Merchant Service
4. Payment Service
5. Transaction Service
6. Fraud Detection Service
7. Payment Routing Service
8. Settlement Service
9. Notification Service
10. Webhook Service
11. Reconciliation Service
12. Audit Service

Application deployment should be controlled through Infrastructure as Code and automated CI/CD pipelines.

The deployment process should maintain version parity between regions.

A release is not considered complete until both regional environments have been validated.

Configuration differences should be minimized and explicitly documented.

---

## 5. Regional Request Processing

When a merchant sends a payment request, Route 53 selects a healthy regional endpoint.

For example:

```text
Payment Request
      |
      v
Route 53
      |
      +------------+
      |            |
      v            v
   Mumbai       Hyderabad
      |            |
      v            v
 Payment       Payment
 Service       Service
```

The selected region processes the request.

The payment request contains a globally unique idempotency key.

This key is important because the same merchant request can potentially be retried against another region.

The receiving region must determine whether the transaction has already been processed before initiating a new financial operation.

---

## 6. Idempotency Design

Idempotency is a core requirement for active-active payment processing.

A payment request should contain an idempotency key generated by the merchant or PaySecure API layer.

The logical record can contain:

| Field              | Purpose                        |
| ------------------ | ------------------------------ |
| Idempotency Key    | Prevent duplicate requests     |
| Merchant ID        | Identify merchant              |
| Transaction ID     | Identify financial transaction |
| Request ID         | Trace request                  |
| Status             | Current transaction state      |
| Created At         | Transaction timestamp          |
| Updated At         | Last state change              |
| Response Reference | Original response              |

If the same request reaches Mumbai and Hyderabad, both regions must use the same idempotency key.

The system should enforce a uniqueness rule for the key and return the previously recorded result when the transaction already exists.

This protects against duplicate processing during retries, network failures, and regional traffic shifts.

---

## 7. Aurora PostgreSQL Strategy

Aurora PostgreSQL contains important relational payment and settlement data.

In an active-active application model, database write ownership requires careful design.

A single globally writable relational database should not be assumed to provide conflict-free financial transaction processing.

The architecture therefore separates application traffic from authoritative financial writes.

For transaction-critical operations, the design should establish an explicit write-authority model.

Possible approaches include:

* Region-based transaction ownership
* Merchant-based partitioning
* Transaction-shard ownership
* Controlled primary-writer routing

For example, a merchant can be assigned to a home region.

```text
Merchant A
    |
    v
Mumbai Ownership
    |
    v
Mumbai Transaction Write

Merchant B
    |
    v
Hyderabad Ownership
    |
    v
Hyderabad Transaction Write
```

The ownership rule prevents both regions from independently updating the same transaction record.

Cross-region replication keeps the secondary copy available for recovery and read workloads.

---

## 8. Transaction Ordering

Payment systems require deterministic transaction ordering.

Each transaction should have a globally traceable transaction identifier and timestamp.

For state transitions, the system should maintain:

```text
INITIATED
    |
    v
AUTHORIZED
    |
    v
CAPTURED
    |
    v
SETTLEMENT_PENDING
    |
    v
SETTLED
```

Invalid transitions must be rejected.

For example, a transaction already marked `SETTLED` must not be moved back to `AUTHORIZED` because of a delayed replicated event.

The service handling a state transition should validate the current transaction state before applying the update.

Kafka event consumers should use the same state-machine validation.

---

## 9. DynamoDB Global Tables

DynamoDB Global Tables provide replicated copies of DynamoDB data across regions.

The active-active design can use the replicated DynamoDB data layer for workloads where multi-region access is appropriate.

Examples include:

* Idempotency metadata
* Session-related state
* Non-relational transaction metadata
* Application configuration
* High-scale lookup data

However, conflict-sensitive payment records require explicit application rules.

The application must define which update is authoritative.

Potential conflict-control mechanisms include:

* Version numbers
* Conditional writes
* State-transition validation
* Idempotency keys
* Transaction ownership
* Last-known version checks

Financial state should never be resolved simply by blindly accepting whichever update arrives last.

---

## 10. Conflict Resolution

Active-active introduces a major operational challenge: concurrent updates.

Consider the following example:

```text
Mumbai:
Transaction T100 -> AUTHORIZED

Hyderabad:
Transaction T100 -> FAILED
```

If both updates are accepted independently, the final state may become inconsistent.

Therefore, transaction state transitions must use explicit business rules.

A simplified rule is:

```text
Current State
      |
      v
Validate Expected Version
      |
      +---- Version Match ----> Apply Update
      |
      +---- Version Mismatch --> Reject / Reconcile
```

The reconciliation service can identify conflicting events and place them into an exception workflow.

No automatic conflict resolution should override financial correctness without an approved business rule.

---

## 11. Redis Active-Active Considerations

Redis is primarily used for low-latency and temporary application state.

Examples include:

* Session information
* Cache entries
* Rate limits
* Short-lived tokens
* Frequently accessed metadata

Active-active operation means both regions may read and update Redis-related state.

Not all cached information needs cross-region consistency.

For example, a cache entry can be rebuilt from the authoritative database.

For security-sensitive rate limits and session information, the application must define an acceptable consistency model.

Redis should not become the authoritative source for payment transaction status.

The durable transaction state remains in the appropriate database.

---

## 12. Kafka Active-Active Model

Kafka is used for asynchronous event processing.

Both regions maintain Kafka infrastructure and replicated topics.

Important topics include:

* Payment events
* Transaction events
* Settlement events
* Notification events
* Webhook events
* Audit events

The logical flow is:

```text
Mumbai Producers
       |
       v
Mumbai Kafka
       |
       | Replication
       v
Hyderabad Kafka

Hyderabad Producers
       |
       v
Hyderabad Kafka
       |
       | Replication
       v
Mumbai Kafka
```

Bidirectional event replication requires strong duplicate-event protection.

Every event should contain:

* Event ID
* Transaction ID
* Event type
* Source region
* Event timestamp
* Schema version

Consumers should maintain idempotent processing.

An event received twice must not produce two financial side effects.

---

## 13. Kafka Event Ordering

Kafka ordering is generally maintained within a partition.

Therefore, payment events should use a deterministic partition key.

A suitable logical key is the transaction ID.

For example:

```text
Transaction T100
       |
       v
Partition Key = T100
       |
       v
INITIATED
AUTHORIZED
CAPTURED
SETTLED
```

Events belonging to the same transaction should remain ordered within the relevant partitioning model.

Cross-region replication must preserve enough information for consumers to identify duplicates and stale events.

Consumers should reject or quarantine events that represent invalid state transitions.

---

## 14. External NPCI / UPI Dependencies

PaySecure depends on external payment networks and partners, including NPCI/UPI-related services.

An active-active architecture does not eliminate an outage caused by an external dependency.

For this reason, external dependency health must be monitored separately from regional infrastructure health.

The application should distinguish between:

```text
PaySecure Regional Failure
          vs
External Payment Network Failure
```

If Mumbai fails but external payment services remain healthy, Hyderabad can continue processing.

If NPCI/UPI services fail while both PaySecure regions are healthy, regional failover is not the appropriate response.

The system should instead use retry queues, controlled transaction states, merchant communication, and reconciliation procedures.

---

## 15. Security in Both Regions

Both Mumbai and Hyderabad must maintain equivalent security controls.

Required controls include:

* IAM least privilege
* KMS encryption
* Secrets Manager
* TLS/mTLS
* Security Groups
* Network segmentation
* WAF
* Shield
* CloudTrail
* Security monitoring
* PCI CDE controls

The security configuration should be managed through Infrastructure as Code.

A security control must not exist only in Mumbai.

The active-active architecture must therefore continuously check security configuration parity.

---

## 16. Data Localization

The proposed architecture keeps the regional environments within India.

Mumbai and Hyderabad provide the two-region architecture required for disaster recovery while retaining replicated application data within Indian AWS regions.

Data-flow documentation should identify:

* Merchant data
* Payment transaction data
* Settlement information
* Authentication data
* Logs
* Audit data
* Replicated database data
* Kafka events
* Backup data

Any third-party integration must be separately assessed for applicable data-transfer requirements.

---

## 17. Monitoring

Active-active requires monitoring of each region independently and the platform as a whole.

Key metrics include:

### Application

* Payment success rate
* HTTP 5xx
* P99 latency
* Request rate
* Pod restarts

### Database

* Database availability
* Replication lag
* Connections
* CPU
* Storage

### Kafka

* Broker health
* Consumer lag
* Replication lag
* Partition health
* Throughput

### Regional

* Route 53 health
* ALB health
* EKS health
* Regional traffic percentage

### Business

* Payment authorization rate
* Settlement queue depth
* Reconciliation exceptions
* Duplicate transaction alerts

The monitoring system must make it possible to identify whether a problem is regional, application-specific, database-specific, Kafka-specific, or external.

---

## 18. Regional Failure

One of the primary advantages of active-active is that the surviving region is already serving production traffic.

A simplified failure sequence is:

```text
Mumbai Failure
      |
      v
Health Check Fails
      |
      v
Remove Mumbai from Routing
      |
      v
Hyderabad Receives Traffic
      |
      v
Scale Hyderabad
      |
      v
Validate Transactions
      |
      v
Monitor
```

The application should not immediately assume every Mumbai transaction failed.

Transactions that were in progress must be reconciled using database state, idempotency records, Kafka events, and external payment responses.

This is especially important for payment requests that were acknowledged by an external payment network but whose final response did not reach the merchant.

---

## 19. Network Partition

Network partition is more complex than complete regional failure.

A region may remain operational while cross-region communication is unavailable.

For example:

```text
Mumbai EKS ----X---- Hyderabad EKS
     |                    |
   ACTIVE               ACTIVE
```

If both regions continue accepting writes while unable to communicate, conflicting transactions may be created.

Therefore, the architecture requires partition-handling rules.

Depending on the transaction ownership model, the platform may:

1. Continue processing independently owned transactions.
2. Restrict operations requiring cross-region coordination.
3. Temporarily stop selected write operations.
4. Route affected merchants to an authoritative region.

The decision must prioritize transaction correctness.

---

## 20. Failover and Recovery

Active-active regional failover primarily involves removing an unhealthy region from traffic.

The recovery process is:

### Detection

Health checks and monitoring detect regional degradation.

### Confirmation

The incident commander confirms that the issue is not a false positive.

### Traffic Control

The affected region is removed from Route 53 routing.

### Capacity Adjustment

The healthy region scales to handle additional traffic.

### Data Validation

Transaction and event replication status is checked.

### Application Validation

Payment APIs, authentication, settlement, webhooks, and reconciliation are tested.

### Monitoring

The surviving region is continuously monitored until capacity and transaction processing stabilize.

---

## 21. Failback

When the failed region becomes available, it should not immediately receive production traffic.

The region must first be:

* Rebuilt or validated
* Patched if required
* Synchronized
* Tested
* Reconnected to replication
* Validated against transaction state
* Checked for configuration drift

Only after these checks should traffic gradually return.

A controlled traffic restoration can be performed:

```text
Recovered Region
      |
      v
Health Validation
      |
      v
Data Synchronization
      |
      v
Application Validation
      |
      v
Small Traffic Percentage
      |
      v
Monitor
      |
      v
Gradual Traffic Increase
```

---

## 22. Active-Active Advantages

The active-active design provides several architectural characteristics:

* Both regions serve production traffic.
* Hyderabad infrastructure is continuously exercised.
* Regional failure can be handled by traffic redistribution.
* Infrastructure capacity is used during normal operation.
* Regional latency can be optimized through traffic routing.
* Failover does not depend entirely on starting a cold environment.

However, these benefits come with increased complexity.

---

## 23. Active-Active Challenges

The major challenges are:

### Data Conflicts

Multiple regions can attempt to update related records.

### Transaction Ordering

Distributed event processing requires explicit ordering rules.

### Duplicate Processing

Retries and replicated events can result in duplicate messages.

### Capacity

The surviving region must absorb additional traffic.

### Operational Complexity

Both regions are production environments and require continuous monitoring.

### Cost

Two production-grade environments generally require more infrastructure resources than an active-passive standby environment.

### Testing

The platform must test regional failures, network partitions, database conflicts, and message duplication.

---

## 24. Active-Active Recovery Model

The target recovery model is:

```text
                 NORMAL OPERATION

             +-------------------+
             |     Route 53      |
             +---------+---------+
                       |
             +---------+---------+
             |                   |
             v                   v
         Mumbai              Hyderabad
         ACTIVE                ACTIVE
             |                   |
             +---------+---------+
                       |
                Replicated Data


                 REGION FAILURE

             +-------------------+
             |     Route 53      |
             +---------+---------+
                       |
                       v
                  Hyderabad
                    ACTIVE
                       |
                 100% Traffic
```

The exact traffic distribution depends on the final Route 53 configuration and capacity model.

---

## 25. Active-Active Operational Requirements

To operate this architecture safely, PaySecure needs:

1. Infrastructure as Code.
2. Automated deployment pipelines.
3. Regional configuration parity.
4. Continuous replication monitoring.
5. Transaction idempotency.
6. Explicit transaction ownership.
7. Kafka event identifiers.
8. Duplicate-event protection.
9. Database conflict detection.
10. Automated health checks.
11. Capacity scaling policies.
12. Regional DR dashboards.
13. Regular failover testing.
14. Annual disaster recovery drills.
15. Documented incident runbooks.

These controls convert the architecture from a conceptual design into an operational disaster recovery capability.

---

## 26. Conclusion

The active-active architecture provides PaySecure with two simultaneously operational AWS regions: Mumbai and Hyderabad.

Both regions host the application stack and are capable of receiving production traffic. Route 53 provides health-aware traffic distribution, while replicated data services maintain regional copies of required information.

The most important design challenge is not application deployment but transaction consistency.

Payment processing requires explicit idempotency, transaction ownership, state-transition validation, event ordering, duplicate-event handling, and conflict detection.

Aurora PostgreSQL requires a carefully defined write-authority model, while DynamoDB and Kafka require application-level controls for conflict and duplicate handling.

The architecture can reduce regional dependency and allow the surviving region to continue serving customers during a regional outage. However, the increased operational complexity and infrastructure requirements must be evaluated against the active-passive design.

The final PaySecure architecture decision should therefore consider recovery objectives, transaction consistency, operational maturity, capacity requirements, compliance, and cost before selecting the production DR model.
