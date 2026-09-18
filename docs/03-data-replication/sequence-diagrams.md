# Data Replication Sequence Diagrams

## 1. Purpose

This document describes the major data-replication and disaster-recovery flows for the PaySecure Gateway multi-region architecture.

The diagrams cover:

1. Aurora PostgreSQL replication
2. DynamoDB replication
3. Kafka event replication
4. Payment transaction and idempotency
5. Regional failover
6. Split-brain prevention
7. Post-failure data reconciliation

The diagrams use Mermaid sequence-diagram notation so they can be rendered directly by compatible Markdown viewers.

---

# 2. Aurora PostgreSQL Replication

Aurora PostgreSQL is responsible for critical relational data such as payment transactions and settlement information.

The normal replication flow is from the Mumbai primary database to the Hyderabad secondary database.

```mermaid
sequenceDiagram
    participant App as Mumbai Payment Service
    participant DB1 as Mumbai Aurora Primary
    participant Rep as Cross-Region Replication
    participant DB2 as Hyderabad Aurora Secondary
    participant Mon as Monitoring

    App->>DB1: Write transaction
    DB1-->>App: Commit response
    DB1->>Rep: Replicate database changes
    Rep->>DB2: Apply replicated changes
    DB2-->>Rep: Replication acknowledgement
    Rep->>Mon: Update replication status
    Mon->>Mon: Measure replication lag
```

### Explanation

The application normally writes to the Mumbai Aurora writer.

Database changes are asynchronously replicated to Hyderabad.

The monitoring system continuously tracks replication health and lag.

If replication lag approaches the RPO threshold, an alert is generated.

---

# 3. Aurora Failover

The following sequence represents database recovery during a Mumbai regional failure.

```mermaid
sequenceDiagram
    participant Monitor as Monitoring
    participant IC as Incident Commander
    participant Mumbai as Mumbai Aurora
    participant Fence as Write Fencing
    participant Hyd as Hyderabad Aurora
    participant App as Hyderabad Application

    Monitor->>IC: Mumbai database/regional failure alert
    IC->>Mumbai: Check availability
    Mumbai-->>IC: Unavailable / unsafe
    IC->>Fence: Prevent unsafe Mumbai writes
    Fence-->>IC: Write path fenced
    IC->>Hyd: Validate replicated state
    Hyd-->>IC: Replication state confirmed
    IC->>Hyd: Promote DR database
    Hyd-->>IC: Hyderabad writer ready
    IC->>App: Update database connectivity
    App->>Hyd: Test transaction database connection
    Hyd-->>App: Connection successful
```

The sequence demonstrates why write fencing is required before promoting the secondary database.

---

# 4. DynamoDB Replication

DynamoDB is used for high-scale application data, including idempotency-related metadata and transaction metadata.

```mermaid
sequenceDiagram
    participant App as Application
    participant DDB1 as Mumbai DynamoDB
    participant GT as Global Table Replication
    participant DDB2 as Hyderabad DynamoDB
    participant Mon as Monitoring

    App->>DDB1: Write idempotency record
    DDB1-->>App: Write accepted
    DDB1->>GT: Replicate item
    GT->>DDB2: Apply replicated item
    DDB2-->>GT: Replication acknowledgement
    GT->>Mon: Update replication status
    Mon->>Mon: Check replication health
```

The replicated record allows the Hyderabad application to access required state during regional recovery.

---

# 5. Payment Transaction and Idempotency

Payment processing must protect against duplicate requests.

The idempotency key provides a stable reference for retries.

```mermaid
sequenceDiagram
    participant Merchant
    participant API as Payment API
    participant DDB as Idempotency Store
    participant Pay as Payment Service
    participant DB as Transaction DB
    participant Kafka as Kafka

    Merchant->>API: Payment request + idempotency key
    API->>DDB: Check idempotency key

    alt Key does not exist
        DDB-->>API: New request
        API->>Pay: Process payment
        Pay->>DB: Create transaction
        DB-->>Pay: Transaction created
        Pay->>Kafka: Publish payment event
        Pay->>DDB: Store completed state
        DDB-->>API: Store result
        API-->>Merchant: Payment response
    else Key already exists
        DDB-->>API: Existing transaction found
        API->>DB: Retrieve transaction state
        DB-->>API: Existing result
        API-->>Merchant: Return existing result
    end
```

The second branch prevents the same merchant request from creating a second financial transaction.

---

# 6. Kafka Event Replication

Kafka carries asynchronous payment, settlement, webhook, notification, and audit events.

```mermaid
sequenceDiagram
    participant Pay as Payment Service
    participant K1 as Mumbai MSK
    participant Rep as Kafka Replication
    participant K2 as Hyderabad MSK
    participant Consumer as Hyderabad Consumer
    participant DB as Transaction State

    Pay->>K1: Publish transaction event
    K1-->>Pay: Event accepted
    K1->>Rep: Replicate event
    Rep->>K2: Copy event
    K2-->>Rep: Event replicated
    Consumer->>K2: Consume event
    Consumer->>DB: Validate transaction state
    DB-->>Consumer: State returned
    Consumer->>Consumer: Check event ID
    Consumer->>Consumer: Process idempotently
```

Each event should contain a unique event ID and transaction ID.

---

# 7. Kafka Duplicate Event Handling

Replicated events can potentially be delivered more than once.

The consumer therefore checks the event identifier before applying a financial side effect.

```mermaid
sequenceDiagram
    participant Kafka
    participant Consumer
    participant Store as Processed Event Store
    participant DB as Transaction DB

    Kafka->>Consumer: Deliver event
    Consumer->>Store: Check event ID

    alt Event already processed
        Store-->>Consumer: Event exists
        Consumer->>Consumer: Ignore duplicate
    else New event
        Store-->>Consumer: Event not found
        Consumer->>DB: Validate transaction state
        DB-->>Consumer: State valid
        Consumer->>DB: Apply event
        Consumer->>Store: Record event ID
    end
```

This mechanism protects settlement and other event-driven workflows from duplicate side effects.

---

# 8. Active-Passive Regional Failover

The active-passive architecture keeps Mumbai active and Hyderabad as warm standby.

```mermaid
sequenceDiagram
    participant Health as Health Monitoring
    participant IC as Incident Commander
    participant DNS as Route 53
    participant Mumbai as Mumbai Region
    participant Hyd as Hyderabad Region
    participant Data as Replicated Data

    Health->>IC: Mumbai failure detected
    IC->>Mumbai: Confirm regional state
    Mumbai-->>IC: Region unavailable
    IC->>Data: Check replication freshness
    Data-->>IC: Replication status
    IC->>Hyd: Activate DR services
    Hyd-->>IC: Application services ready
    IC->>DNS: Initiate regional failover
    DNS->>Hyd: Route production traffic
    Hyd-->>DNS: Endpoint healthy
    DNS-->>IC: Traffic switched
    IC->>Hyd: Validate payment processing
    Hyd-->>IC: Validation successful
```

The failover process includes detection, confirmation, data validation, DR activation, DNS change, and transaction validation.

---

# 9. Active-Active Regional Failure

In active-active mode, both regions normally serve traffic.

If one region fails, the healthy region continues serving traffic.

```mermaid
sequenceDiagram
    participant DNS as Route 53
    participant Mumbai as Mumbai Region
    participant Hyd as Hyderabad Region
    participant Monitor as Monitoring
    participant App as Merchant

    App->>DNS: Payment request
    DNS->>Mumbai: Route request
    Mumbai-->>App: Payment response

    Monitor->>Mumbai: Health check
    Mumbai-->>Monitor: Failure
    Monitor->>DNS: Mumbai unhealthy
    DNS->>DNS: Remove Mumbai from routing

    App->>DNS: Retry/payment request
    DNS->>Hyd: Route request
    Hyd-->>App: Payment response

    DNS->>Hyd: Continue production routing
```

The surviving region must have sufficient capacity to handle the additional traffic.

---

# 10. Split-Brain Prevention

A network partition can leave both regions operational while preventing communication between them.

```mermaid
sequenceDiagram
    participant Mumbai as Mumbai
    participant Control as Failover Controller
    participant Hyd as Hyderabad
    participant DB as Transaction Authority

    Mumbai->>Control: Regional health status
    Hyd->>Control: Regional health status

    Control->>Control: Detect communication partition

    Control->>Mumbai: Check write authority
    Control->>Hyd: Check write authority

    alt Safe ownership available
        Control->>DB: Confirm transaction ownership
        DB-->>Control: Ownership confirmed
        Control->>Mumbai: Continue approved writes
        Control->>Hyd: Restrict conflicting writes
    else Ownership uncertain
        Control->>Mumbai: Fence affected writes
        Control->>Hyd: Fence affected writes
        Control->>DB: Start reconciliation
    end
```

The objective is to prevent two regions from independently becoming authoritative for the same financial transaction.

---

# 11. Transaction State Validation

Every financial state transition must be validated.

```mermaid
sequenceDiagram
    participant Event as Kafka Event
    participant Service as Transaction Service
    participant DB as Transaction DB

    Event->>Service: Transaction state update
    Service->>DB: Read current state
    DB-->>Service: Current state + version

    alt Valid transition
        Service->>DB: Apply state update
        DB-->>Service: Update successful
        Service-->>Event: Processing complete
    else Invalid transition
        Service->>Service: Reject stale/invalid event
        Service->>Service: Create reconciliation exception
    end
```

This protects against delayed events and incorrect state transitions.

---

# 12. Replication Failure Detection

Replication failure should be detected before a disaster occurs.

```mermaid
sequenceDiagram
    participant DB as Primary Data Service
    participant Rep as Replication Layer
    participant DR as DR Data Service
    participant Monitor as Cloud Monitoring
    participant Engineer as On-Call Engineer

    DB->>Rep: Send changes
    Rep->>DR: Replicate data
    DR-->>Rep: Replication status

    Rep->>Monitor: Publish lag/status
    Monitor->>Monitor: Evaluate threshold

    alt Healthy
        Monitor-->>Monitor: Continue monitoring
    else Threshold exceeded
        Monitor->>Engineer: Replication alarm
        Engineer->>DB: Investigate source
        Engineer->>Rep: Check replication
        Engineer->>DR: Validate target
    end
```

Replication monitoring is an important part of maintaining the sub-one-minute RPO objective.

---

# 13. Post-Failure Reconciliation

After a regional failure, transactions processed immediately before the incident may require reconciliation.

```mermaid
sequenceDiagram
    participant Recovery as Recovery Team
    participant Source as Recovered Data
    participant DR as DR Data
    participant External as External Payment Network
    participant Recon as Reconciliation Service
    participant Ops as Payment Operations

    Recovery->>Source: Retrieve transaction records
    Recovery->>DR: Retrieve DR transaction records
    Recovery->>Recon: Compare transaction states
    Recon->>External: Verify external payment status
    External-->>Recon: External status

    alt Records consistent
        Recon->>Ops: Mark reconciliation complete
    else Difference detected
        Recon->>Ops: Create reconciliation exception
        Ops->>Ops: Investigate transaction
        Ops->>DR: Apply approved correction
        DR-->>Ops: Correction recorded
    end
```

Reconciliation ensures that internal payment state, replicated state, and external payment results are aligned after recovery.

---

# 14. End-to-End Disaster Recovery Flow

The complete regional recovery process combines monitoring, replication, failover, and validation.

```mermaid
sequenceDiagram
    participant Monitor as Monitoring
    participant IC as Incident Commander
    participant Mumbai as Mumbai
    participant Data as Replicated Data
    participant Hyd as Hyderabad
    participant DNS as Route 53
    participant Merchant

    Monitor->>IC: Regional failure alert
    IC->>Mumbai: Confirm failure
    Mumbai-->>IC: Failure confirmed

    IC->>Data: Check replication state
    Data-->>IC: Latest replicated state

    IC->>Mumbai: Fence unsafe writes
    IC->>Hyd: Activate/promote DR components
    Hyd-->>IC: DR services ready

    IC->>DNS: Initiate failover
    DNS->>Hyd: Route traffic
    Hyd-->>DNS: Healthy

    Merchant->>DNS: Payment request
    DNS->>Hyd: Forward request
    Hyd-->>Merchant: Payment response

    IC->>Hyd: Validate transaction processing
    Hyd-->>IC: Validation results

    Monitor->>IC: Continue DR monitoring
```

---

# 15. RPO Measurement Flow

The RPO must be measured during disaster recovery drills.

```mermaid
sequenceDiagram
    participant Primary as Primary Region
    participant Rep as Replication
    participant DR as DR Region
    participant Drill as DR Team

    Primary->>Rep: Replicate transaction
    Rep->>DR: Apply transaction
    Drill->>Primary: Record last transaction
    Drill->>Primary: Simulate regional failure
    Drill->>DR: Identify latest transaction
    DR-->>Drill: Latest replicated transaction
    Drill->>Drill: Calculate replication gap
```

The measured replication gap should be compared with the project's less-than-one-minute RPO objective.

---

# 16. RTO Measurement Flow

RTO is measured from the beginning of the disaster event to the first successful recovered transaction.

```mermaid
sequenceDiagram
    participant Drill as DR Team
    participant Monitor as Monitoring
    participant Hyd as Hyderabad
    participant DNS as Route 53
    participant Merchant as Test Merchant

    Drill->>Monitor: Start failure simulation
    Monitor->>Drill: Failure detected
    Drill->>Hyd: Activate recovery
    Hyd-->>Drill: Services ready
    Drill->>DNS: Switch traffic
    DNS-->>Drill: DNS routing updated
    Merchant->>DNS: Test payment
    DNS->>Hyd: Payment request
    Hyd-->>Merchant: Successful response
    Merchant-->>Drill: First valid transaction
    Drill->>Drill: Calculate RTO
```

The measured RTO should be compared with the project's less-than-five-minute target.

---

# 17. Sequence Diagram Summary

The diagrams demonstrate the core principles of the PaySecure DR architecture:

* Continuous regional replication
* Service-specific replication
* Idempotent payment processing
* Kafka event identification
* Transaction-state validation
* Controlled regional failover
* Split-brain prevention
* Replication monitoring
* Post-failure reconciliation
* Measured RPO and RTO

The sequence diagrams should be used together with the replication strategy, DNS failover design, and disaster recovery runbooks.

The diagrams represent the intended architecture and operational flows. Actual AWS configuration, replication lag, DNS behavior, and recovery timings must be validated through implementation and controlled DR testing.
