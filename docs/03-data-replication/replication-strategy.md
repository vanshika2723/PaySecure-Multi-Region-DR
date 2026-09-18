# Data Replication Strategy

## 1. Purpose

PaySecure Gateway processes approximately 3.2 million transactions per day with a daily transaction value of approximately ₹500 crore. The disaster recovery architecture therefore requires continuous replication of critical application and payment data between Mumbai (`ap-south-1`) and Hyderabad (`ap-south-2`).

The target Recovery Point Objective (RPO) is less than one minute.

The replication strategy is designed around four primary data platforms:

* Aurora PostgreSQL
* DynamoDB
* ElastiCache Redis
* Apache Kafka / Amazon MSK

S3-based objects and backups are also included where required.

The replication model differs by service because payment transactions, cache entries, and asynchronous events have different consistency and recovery requirements.

---

## 2. Replication Principles

The DR replication design follows these principles:

1. Critical payment data must have a regional recovery copy.
2. Replication must remain within the approved geographic/data-localization boundary.
3. Replication lag must be continuously monitored.
4. Financial transaction state must remain authoritative and auditable.
5. Duplicate processing must be prevented.
6. Replicated events must be traceable.
7. Split-brain conditions must be prevented.
8. Failover must be tested regularly.
9. RPO and RTO must be measured rather than assumed.
10. Replication failures must generate operational alerts.

---

## 3. Data Classification

Not all data requires the same replication behavior.

| Data Category              | Example                       | Recovery Requirement |
| -------------------------- | ----------------------------- | -------------------- |
| Financial Transaction Data | Payment/transaction records   | Critical             |
| Settlement Data            | Settlement records            | Critical             |
| Merchant Data              | Merchant configuration        | Critical             |
| Idempotency Data           | Request keys/status           | Critical             |
| Kafka Events               | Payment/settlement events     | Critical             |
| Audit Data                 | Security/payment audit events | Critical             |
| Session Data               | Login/session state           | Important            |
| Cache Data                 | Frequently accessed data      | Reconstructable      |
| Logs                       | Application logs              | Important            |
| Temporary Data             | Short-lived processing state  | Lower                |

Critical data receives the highest replication and monitoring priority.

---

# 4. Aurora PostgreSQL Replication

Aurora PostgreSQL is used for relational workloads including transaction and settlement data.

The proposed architecture uses a cross-region Aurora Global Database model.

```text
Mumbai
Aurora PostgreSQL
Primary Writer
       |
       | Cross-Region Replication
       v
Hyderabad
Aurora PostgreSQL
Secondary
```

Mumbai is the normal primary writer in the active-passive architecture.

The Hyderabad cluster continuously receives database changes.

Replication is asynchronous, so replication lag must be monitored continuously.

---

## 5. Aurora RPO

The project requires an RPO of less than one minute.

The operations team should monitor the replication lag between the primary and secondary database.

The target should be represented by an operational alarm.

Example logical condition:

```text
IF replication_lag >= defined_RPO_threshold
THEN
    Alert DR Operations
```

A sustained replication-lag condition should trigger investigation before it becomes a regional disaster.

The exact production alarm threshold should be validated during implementation and DR drills.

---

## 6. Aurora Failover

During a regional disaster:

1. Confirm Mumbai failure.
2. Determine whether Mumbai can still accept writes.
3. Fence or isolate unsafe Mumbai write paths.
4. Check the latest replicated database state.
5. Promote the Hyderabad database according to the approved procedure.
6. Update application database connectivity.
7. Validate transaction and settlement data.
8. Enable production processing.
9. Monitor database health.
10. Start reconciliation.

The sequence prevents both regions from simultaneously becoming authoritative writers.

---

# 7. Aurora Data Consistency

Payment records require explicit state validation.

A simplified transaction lifecycle is:

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

A delayed or duplicated update must not move a transaction into an invalid state.

Each transaction should therefore include a version or state-validation mechanism.

Before updating a transaction:

```text
Read Current State
       |
       v
Validate Expected Version
       |
       +---- Match ----> Apply Update
       |
       +---- Mismatch -> Reject / Reconcile
```

This protects transaction integrity during replication and recovery.

---

# 8. DynamoDB Replication

DynamoDB is used for high-scale NoSQL workloads such as idempotency metadata, transaction metadata, and other application state.

The proposed architecture uses DynamoDB Global Tables.

```text
DynamoDB Mumbai
      |
      | Global Table Replication
      |
      v
DynamoDB Hyderabad
```

The regional copies allow the application to access replicated data from the surviving region.

---

## 9. DynamoDB Idempotency

Idempotency is particularly important for payment requests.

An idempotency record can contain:

```text
idempotencyKey
merchantId
transactionId
requestId
status
createdAt
updatedAt
responseReference
```

When a retry reaches another region, the application checks the replicated idempotency record.

If the original transaction already exists, the system should return or reconcile the existing transaction rather than create a duplicate financial operation.

---

# 10. DynamoDB Conflict Handling

Active-active processing can result in concurrent updates.

The application must therefore define rules for conflict detection.

Possible mechanisms include:

* Conditional writes
* Version numbers
* Transaction ownership
* State-transition validation
* Idempotency keys
* Reconciliation queues

For financial records, conflict handling should not rely only on a generic last-write-wins approach.

Financial state requires explicit business validation.

---

# 11. ElastiCache Redis Replication

Redis provides low-latency access for cache and temporary application state.

The proposed architecture uses cross-region Redis replication capabilities appropriate to the final deployment model.

```text
Mumbai Redis
   |
   | Cross-Region Replication
   v
Hyderabad Redis
```

Redis data should be classified according to recovery importance.

### Reconstructable

Examples:

* Product/configuration cache
* Frequently accessed lookup data

### Important

Examples:

* Session-related information
* Rate-limiting state

### Non-authoritative

Redis must not become the authoritative source for payment transaction status.

Aurora and DynamoDB remain the appropriate durable data sources.

---

# 12. Redis Recovery

During regional failover:

1. Validate Hyderabad Redis health.
2. Confirm replication state where applicable.
3. Activate the DR Redis configuration.
4. Validate application connectivity.
5. Check session behavior.
6. Check rate-limit behavior.
7. Allow cache misses to rebuild from durable systems.

The application must be designed to tolerate cache misses.

A Redis outage should not result in loss of authoritative financial transaction data.

---

# 13. Kafka / Amazon MSK Replication

Kafka is used for asynchronous processing of payment and operational events.

Important topics include:

* Payment events
* Transaction events
* Settlement events
* Notification events
* Webhook events
* Audit events

The architecture maintains Kafka infrastructure in both regions.

```text
Mumbai MSK
    |
    | Cross-Region Topic Replication
    v
Hyderabad MSK
```

The replication mechanism should maintain required topics and monitor replication lag.

---

# 14. Kafka Event Identity

Every important event should contain a unique event identifier.

Example:

```json id="nqcc6f"
{
  "eventId": "EVT-123456",
  "transactionId": "TXN-987654",
  "eventType": "PAYMENT_AUTHORIZED",
  "sourceRegion": "ap-south-1",
  "timestamp": "2026-09-18T10:00:00Z",
  "schemaVersion": "1"
}
```

The `eventId` allows consumers to identify duplicate messages.

The `transactionId` allows events to be associated with the correct financial transaction.

---

# 15. Kafka Ordering

Transaction-related Kafka events should use a deterministic partitioning strategy.

The transaction ID can be used as the logical partition key.

```text
Transaction T100
       |
       v
Partition Key = T100
       |
       +--> INITIATED
       +--> AUTHORIZED
       +--> CAPTURED
       +--> SETTLED
```

This helps preserve ordering for events associated with the same transaction within the applicable Kafka partitioning model.

Consumers must still validate transaction state because cross-region replication and retries can introduce duplicate or delayed events.

---

# 16. Kafka Duplicate Processing

A replicated event can potentially be consumed more than once.

The consumer should therefore implement idempotent processing.

Simplified processing:

```text
Receive Event
     |
     v
Check Event ID
     |
     +---- Already Processed ---> Ignore / Return
     |
     +---- New Event ----------> Validate State
                                      |
                                      v
                                Process Event
                                      |
                                      v
                                Record Event ID
```

This is especially important for settlement, webhook, notification, and reconciliation workflows.

---

# 17. S3 Replication

S3 may be used for documents, reports, logs, exports, backups, and other objects depending on the application implementation.

Where regional recovery requires a second copy, S3 Cross-Region Replication can be configured between the approved regions.

Logical model:

```text
S3 Mumbai
    |
    | Cross-Region Replication
    v
S3 Hyderabad
```

Object replication must include appropriate encryption, access-control, and lifecycle policies.

Sensitive data should follow the project's data-localization and security requirements.

---

# 18. Backup Strategy

Replication does not replace backups.

A regional replica can replicate corrupted or incorrectly modified data.

Therefore, PaySecure requires separate backup and recovery mechanisms.

Backup strategy should include:

* Database backups
* Point-in-time recovery
* Application configuration backups
* Infrastructure as Code
* Kubernetes manifests
* Kafka configuration
* Security configuration
* Audit records

Backups should be periodically restored in a controlled environment to verify recoverability.

---

# 19. Synchronous vs Asynchronous Replication

Replication can generally be categorized as synchronous or asynchronous.

### Synchronous

The write is considered complete only after required replicas acknowledge it.

Conceptually:

```text
Write
 |
 +----> Region A
 |
 +----> Region B
 |
 v
Acknowledgement
```

Advantages:

* Stronger consistency
* Lower possibility of unreplicated data

Challenges:

* Higher latency
* Cross-region network dependency
* More complex failure handling

### Asynchronous

The primary region acknowledges the operation and replication occurs afterward.

```text
Write
 |
 v
Primary
 |
 +----> Acknowledge
 |
 +----> Replicate asynchronously
              |
              v
           DR Region
```

Advantages:

* Lower write latency
* Better separation between application response and replication

Challenges:

* Replication lag
* Potential data loss within the RPO window

The proposed architecture uses asynchronous cross-region replication where appropriate and relies on monitoring to maintain the required RPO objective.

---

# 20. Replication Latency

The architecture planning assumption is approximately 15–25 ms Mumbai-to-Hyderabad round-trip latency.

Replication performance depends on:

* Network conditions
* Database workload
* Kafka throughput
* Number of replicated records
* Service configuration
* Regional capacity

Therefore, theoretical network latency must not be treated as the actual replication lag.

Actual replication lag must be measured.

---

# 21. RPO Monitoring

The DR monitoring system should continuously collect:

* Aurora replication lag
* DynamoDB replication status
* Redis replication status
* Kafka replication lag
* S3 replication status
* Backup freshness

Example operational states:

```text
GREEN
Replication healthy

YELLOW
Replication approaching threshold

RED
Replication exceeds RPO threshold
```

A red state should trigger an incident or escalation according to the operational runbook.

---

# 22. Replication Failure Handling

If replication fails while both regions remain operational:

1. Generate an alert.
2. Identify affected service.
3. Check regional connectivity.
4. Check service health.
5. Measure replication lag.
6. Determine whether the RPO is still achievable.
7. Protect financial writes if necessary.
8. Repair replication.
9. Validate data consistency.
10. Run reconciliation.
11. Close the incident only after monitoring confirms recovery.

The system should not silently continue operating with unknown replication state.

---

# 23. Split-Brain Protection

Split-brain is a critical risk for payment systems.

A regional network partition may leave both regions operational while cross-region communication is unavailable.

```text
Mumbai ACTIVE
      |
      X
      |
Hyderabad ACTIVE
```

If both regions independently process the same transaction, conflicting financial state may occur.

The design therefore requires:

* Transaction ownership
* Idempotency keys
* Version validation
* Explicit write authority
* Fencing procedures
* Reconciliation

Only an approved region or transaction owner should be authoritative for a particular financial write.

---

# 24. Replication During Active-Passive DR

In active-passive mode:

```text
Mumbai
Primary
   |
   +---- Aurora -----> Hyderabad
   |
   +---- DynamoDB ---> Hyderabad
   |
   +---- Kafka ------> Hyderabad
   |
   +---- Redis ------> Hyderabad
```

Hyderabad receives replicated state and remains ready for promotion.

The main concern is replication freshness before failover.

---

# 25. Replication During Active-Active DR

In active-active mode:

```text
Mumbai <-----------------> Hyderabad
  |                            |
  +---- Application -----------+
  +---- Data Replication ------+
  +---- Event Replication -----+
```

The architecture requires additional conflict-management mechanisms because both regions can process production workloads.

The application must identify transaction ownership and prevent duplicate financial side effects.

---

# 26. Recovery Sequence

A generalized recovery sequence is:

```text
Regional Failure
       |
       v
Health Check / Monitoring
       |
       v
Incident Confirmation
       |
       v
Check Replication State
       |
       v
Fence Unsafe Writes
       |
       v
Promote / Activate DR Data
       |
       v
Start Required Consumers
       |
       v
Switch / Adjust DNS
       |
       v
Validate Transactions
       |
       v
Reconciliation
       |
       v
Continuous Monitoring
```

The exact execution differs between active-passive and active-active configurations.

---

# 27. Data Reconciliation

Reconciliation is required after a disaster or replication interruption.

The reconciliation process compares:

* Transaction IDs
* Payment states
* Settlement states
* Kafka event IDs
* External payment responses
* Merchant-facing statuses
* Idempotency records

Exceptions should be placed into a controlled reconciliation queue.

Example:

```text
Source A
Transaction State
       |
       v
Compare
       ^
       |
Source B
Replicated State
       |
       v
Match? ---- YES ---> Complete
  |
  NO
  |
  v
Exception Queue
  |
  v
Manual / Automated Reconciliation
```

---

# 28. Observability

A dedicated replication dashboard should provide a single operational view.

Recommended panels include:

### Aurora

* Replication lag
* Database availability
* Connections
* CPU

### DynamoDB

* Replication status
* Throttling
* Write activity

### Redis

* Replication health
* Memory
* Connection count

### Kafka

* Replication lag
* Consumer lag
* Broker health
* Partition health

### S3

* Replication status
* Failed objects

### Business

* Payment success rate
* Transaction mismatch count
* Settlement exceptions
* Reconciliation queue size

---

# 29. Alerting

Alerts should be created for:

* Aurora replication lag
* Database failure
* DynamoDB replication issue
* Kafka replication lag
* Kafka consumer lag
* Redis replication failure
* S3 replication failure
* Backup freshness failure
* Transaction mismatch
* Reconciliation queue growth

Alerts should include severity and escalation ownership.

Critical payment-data replication failures should immediately reach the on-call engineering team.

---

# 30. Testing Strategy

Replication must be tested regularly.

Testing should include:

### Database

* Replication lag test
* Secondary promotion
* Point-in-time recovery
* Transaction validation

### DynamoDB

* Regional availability
* Idempotency validation
* Conflict handling

### Redis

* Regional recovery
* Cache rebuild
* Session behavior

### Kafka

* Topic replication
* Consumer restart
* Duplicate-event processing
* Offset validation

### S3

* Object replication
* Object recovery
* Encryption validation

---

# 31. RPO Validation

The target RPO is less than one minute.

During a DR drill, the team should record:

```text
Failure Detection Time
Replication Lag
Last Known Good Transaction
Recovery Start Time
Data Promotion Time
First Successful Transaction
```

The actual measured data-loss window should then be calculated.

Example:

```text
Last replicated transaction:
10:00:55

Regional failure:
10:01:20

Measured replication gap:
25 seconds
```

The example demonstrates how the RPO measurement should be documented; it is not a production measurement.

---

# 32. RTO Validation

The RTO target is less than five minutes.

The drill should record:

```text
T0 = Failure
T1 = Detection
T2 = Incident Confirmation
T3 = Data Promotion
T4 = Application Activation
T5 = DNS / Traffic Switch
T6 = First Valid Payment
```

The measured recovery duration is:

```text
RTO = First Valid Payment Time - Failure Time
```

The final project evidence should contain actual drill measurements.

---

# 33. Operational Ownership

Replication requires clear ownership.

| Responsibility          | Primary Role                 |
| ----------------------- | ---------------------------- |
| Database Replication    | Database / Platform Engineer |
| Kafka Replication       | Platform Engineer            |
| Application Idempotency | Application Engineering      |
| Redis Recovery          | Platform Engineering         |
| DNS                     | Cloud / Platform Engineering |
| Monitoring              | SRE / Operations             |
| Reconciliation          | Payment Operations           |
| Incident Command        | Incident Commander           |
| Compliance              | Compliance / Security Team   |

The exact team structure should be aligned with PaySecure's operational organization.

---

# 34. Final Replication Model

The proposed replication architecture can be summarized as:

```text
                    PAYSECURE
                       |
          +------------+-------------+
          |                          |
      MUMBAI                     HYDERABAD
    ap-south-1                   ap-south-2
          |                          |
          |                          |
       Aurora <----------------> Aurora
          |
      DynamoDB <--------------> DynamoDB
          |
       Redis <----------------> Redis
          |
       Kafka <----------------> Kafka
          |
        S3 <------------------> S3
```

The direction and write behavior of individual services depends on whether the deployment is active-passive or active-active.

The replication architecture must always preserve payment transaction integrity.

---

# 35. Conclusion

The PaySecure disaster recovery design uses service-specific replication rather than applying a single replication mechanism to every component.

Aurora PostgreSQL provides the relational database replication layer. DynamoDB provides replicated NoSQL data. Redis provides replicated or recoverable temporary state. Kafka provides replicated asynchronous events, while S3 can provide regional object recovery where required.

The target RPO of less than one minute requires continuous monitoring of replication freshness.

The most important controls are idempotency, transaction ordering, transaction ownership, duplicate-event protection, conflict detection, reconciliation, and split-brain prevention.

Replication alone does not guarantee disaster recovery. The replicated data must be tested, promoted, validated, reconciled, and monitored during controlled DR exercises.

The final evidence for the project should therefore include measured replication lag, measured RPO, measured RTO, successful failover results, and documented reconciliation outcomes.
