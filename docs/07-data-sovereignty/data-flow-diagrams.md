# PaySecure Gateway — Data Flow Diagrams

## 1. Purpose

This document describes how payment, transaction, replication, and failover data flows through the PaySecure Gateway multi-region architecture.

The diagrams cover:

1. Normal Mumbai production traffic
2. Cross-region data replication
3. Mumbai regional failure
4. Hyderabad DR processing
5. Recovery and reconciliation

The design keeps payment-processing workloads within the Indian AWS regions used by the project:

* Primary: `ap-south-1` — Mumbai
* DR: `ap-south-2` — Hyderabad

---

# 2. Normal Production Data Flow

Under normal operating conditions, Mumbai handles production payment traffic.

```mermaid
flowchart LR
    C[Customer / Payment Client]
    R53[Amazon Route 53]
    WAF[AWS WAF]
    ALB[Application Load Balancer]
    EKS[EKS Payment Services]

    AURORA[(Aurora PostgreSQL)]
    DDB[(DynamoDB)]
    REDIS[(ElastiCache Redis)]
    MSK[(Amazon MSK)]
    S3[(Amazon S3)]
    CW[CloudWatch / Monitoring]

    C --> R53
    R53 --> WAF
    WAF --> ALB
    ALB --> EKS

    EKS --> AURORA
    EKS --> DDB
    EKS --> REDIS
    EKS --> MSK
    EKS --> S3

    EKS --> CW
```

### Flow Description

1. The customer sends a payment request.
2. Route 53 resolves the PaySecure payment endpoint.
3. AWS WAF evaluates the incoming request.
4. The Application Load Balancer forwards valid traffic to EKS.
5. Payment services process the transaction.
6. Aurora PostgreSQL stores authoritative relational transaction state.
7. DynamoDB stores distributed application data where required.
8. Redis provides low-latency cache access.
9. Kafka/MSK carries asynchronous payment and settlement events.
10. S3 stores appropriate objects and audit-related data.
11. CloudWatch and monitoring systems observe application and infrastructure health.

---

# 3. Cross-Region Replication Flow

Mumbai continuously replicates required data to the Hyderabad DR environment.

```mermaid
flowchart LR
    subgraph M["AWS Mumbai — ap-south-1"]
        A[(Aurora PostgreSQL)]
        D[(DynamoDB)]
        R[(ElastiCache Redis)]
        K[(Amazon MSK)]
        S[(Amazon S3)]
    end

    subgraph H["AWS Hyderabad — ap-south-2"]
        A2[(Aurora PostgreSQL DR)]
        D2[(DynamoDB DR)]
        R2[(ElastiCache Redis DR)]
        K2[(Amazon MSK DR)]
        S2[(Amazon S3 DR)]
    end

    A -->|Global Database replication| A2
    D <-->|Global Tables replication| D2
    R -->|Global Datastore replication| R2
    K -->|MSK Replicator| K2
    S -->|S3 Cross-Region Replication| S2
```

## Replication Characteristics

### Aurora PostgreSQL

Aurora Global Database provides cross-region replication for the relational database layer.

The design monitors replication lag continuously.

The DR objective is:

```text
RPO < 1 minute
```

### DynamoDB

DynamoDB Global Tables provide multi-region replication.

Application logic must maintain idempotency and transaction correctness.

### ElastiCache Redis

Redis replication maintains the required cache state in the DR region.

The cache is not treated as the authoritative source for financial transactions.

### Amazon MSK

Kafka topics and required consumer state are replicated to the secondary environment.

Replication lag must be monitored because asynchronous replication can introduce delayed events.

### Amazon S3

Required objects are replicated from Mumbai to Hyderabad.

Replication status is monitored to ensure DR readiness.

---

# 4. Payment Data Sovereignty Flow

Payment-related data remains within the Indian regions used by the architecture.

```mermaid
flowchart TB
    USER[Customer]
    MUM[ Mumbai - ap-south-1 ]
    HYD[ Hyderabad - ap-south-2 ]

    USER --> MUM

    MUM -->|Payment processing| MP[Payment Services]
    MP --> MD[(Payment Data)]
    MD -->|Encrypted replication| HYD
    HYD --> HD[(DR Payment Data)]

    style MUM stroke-width:3px
    style HYD stroke-width:3px
```

The intended design does not replicate payment databases to an overseas AWS region.

Operational data that is not subject to the same payment-data restrictions must still undergo security and compliance review before any external processing is enabled.

---

# 5. Regional Failure Flow

If Mumbai becomes unavailable, Route 53 health checks detect the failure and traffic is redirected toward Hyderabad.

```mermaid
flowchart LR
    USER[Customers]
    DNS[Route 53 Health Checks]

    M[ Mumbai<br/>ap-south-1<br/>UNHEALTHY ]
    H[ Hyderabad<br/>ap-south-2<br/>HEALTHY ]

    ALB2[Hyderabad ALB]
    EKS2[Hyderabad EKS]
    DB2[(Hyderabad Databases)]
    K2[(Hyderabad Kafka)]

    USER --> DNS
    DNS -->|Health check failure| H
    DNS -.->|Traffic removed| M

    H --> ALB2
    ALB2 --> EKS2
    EKS2 --> DB2
    EKS2 --> K2
```

## Failover Sequence

```text
1. Mumbai health degradation detected
2. Route 53 health checks report failure
3. Incident Commander declares regional incident
4. Replication lag is verified
5. Hyderabad application capacity is validated
6. Database writer role is verified/promoted as required
7. Route 53 failover is activated
8. Hyderabad receives production traffic
9. Payment API health is verified
10. Transaction processing is monitored
11. Settlement and reconciliation checks begin
12. Incident communication is issued
```

---

# 6. Detailed Failover Data Flow

```mermaid
sequenceDiagram
    participant C as Customer
    participant R as Route 53
    participant M as Mumbai
    participant H as Hyderabad
    participant DB as DR Database
    participant K as DR Kafka
    participant MON as Monitoring

    C->>R: Payment request
    R->>M: Normal routing

    M->>MON: Health metrics
    MON-->>R: Mumbai unhealthy

    R->>H: Failover routing
    H->>DB: Validate/promote database state
    H->>K: Validate replicated topics
    H->>MON: Report DR health

    H-->>R: DR healthy
    R-->>C: Route payment request to Hyderabad
    C->>H: Payment request
    H->>DB: Commit transaction
    H->>K: Publish transaction event
    H->>MON: Transaction success metric
```

---

# 7. Replication-Lag Decision Flow

Replication status must be checked before a controlled regional failover.

```mermaid
flowchart TD
    START[Regional Failure Detected]
    CHECK[Check Replication Lag]

    A{Aurora lag acceptable?}
    D{DynamoDB lag acceptable?}
    K{Kafka lag acceptable?}

    FAILSAFE[Escalate / Recovery Procedure]
    READY[Continue DR Failover]
    VERIFY[Verify Transaction Integrity]

    START --> CHECK
    CHECK --> A

    A -->|No| FAILSAFE
    A -->|Yes| D

    D -->|No| FAILSAFE
    D -->|Yes| K

    K -->|No| FAILSAFE
    K -->|Yes| READY

    READY --> VERIFY
```

The exact thresholds are defined in the project's monitoring requirements and runbooks.

The failover operator must not assume that replication is current without checking the relevant metrics.

---

# 8. Hyderabad DR Processing Flow

After failover, Hyderabad becomes the active payment-processing environment.

```mermaid
flowchart TB
    R53[Route 53]
    WAF[AWS WAF]
    ALB[Hyderabad ALB]
    EKS[Hyderabad EKS]

    PAY[Payment API]
    TXN[Transaction Processor]
    SET[Settlement Engine]

    A[(Aurora)]
    D[(DynamoDB)]
    RED[(Redis)]
    K[(Kafka)]

    R53 --> WAF
    WAF --> ALB
    ALB --> EKS

    EKS --> PAY
    EKS --> TXN
    EKS --> SET

    PAY --> A
    PAY --> D
    PAY --> RED
    TXN --> K
    SET --> K
```

The DR environment must preserve the same security and compliance controls as the primary environment.

---

# 9. Transaction Idempotency During Failover

Payment transactions must not be processed twice when traffic moves between regions.

```mermaid
sequenceDiagram
    participant Client
    participant API as Payment API
    participant DB as Transaction DB
    participant Key as Idempotency Store

    Client->>API: Payment + Idempotency Key
    API->>Key: Check key

    alt Key does not exist
        API->>DB: Create transaction
        DB-->>API: Transaction created
        API->>Key: Store successful result
        API-->>Client: Success
    else Key already exists
        Key-->>API: Existing transaction
        API-->>Client: Return previous result
    end
```

The idempotency key prevents a retry after failover from creating an additional transaction.

This control is particularly important for:

* Customer retries
* Network timeouts
* DNS transition
* Mid-transaction regional failure
* Application retries
* Kafka replay

---

# 10. Kafka Event Flow

Kafka carries asynchronous events such as transaction-processing and settlement events.

```mermaid
flowchart LR
    P[Payment API]
    M[MSK Mumbai]
    R[MSK Replicator]
    H[MSK Hyderabad]
    C[Consumer]
    S[Settlement Engine]

    P --> M
    M --> R
    R --> H
    H --> C
    C --> S
```

Kafka replication is asynchronous.

Therefore, the system monitors:

* Replication lag
* Consumer lag
* Topic availability
* Partition health
* Consumer offsets

Critical financial state must not rely solely on an unverified Kafka event being present in the DR region.

---

# 11. Recovery Back to Mumbai

After the Mumbai region has been repaired, traffic should not immediately switch back.

The recovery process should be controlled.

```mermaid
flowchart TD
    H[Hyderabad Serving Traffic]
    M[Repair Mumbai]
    TEST[Test Mumbai Health]
    SYNC[Verify Data Synchronization]
    RECON[Transaction Reconciliation]
    DECIDE{Mumbai Ready?}
    SWITCH[Controlled Traffic Shift]
    CONTINUE[Continue Hyderabad Operations]

    H --> M
    M --> TEST
    TEST --> SYNC
    SYNC --> RECON
    RECON --> DECIDE

    DECIDE -->|Yes| SWITCH
    DECIDE -->|No| CONTINUE
    SWITCH --> CONTINUE
```

Before returning traffic to Mumbai:

1. Infrastructure must be healthy.
2. Database synchronization must be confirmed.
3. Kafka consumers must be healthy.
4. Payment APIs must pass health checks.
5. Security controls must be verified.
6. Transactions must be reconciled.
7. Monitoring must show stable operation.
8. Change approval must be obtained.

---

# 12. Compliance Evidence Flow

The architecture should produce evidence that the controls are operating.

```mermaid
flowchart LR
    ARCH[Architecture]
    IAC[Terraform / Kubernetes]
    MON[CloudWatch / Monitoring]
    LOG[CloudTrail / Audit Logs]
    DR[DR Drill]
    EVID[Compliance Evidence]

    ARCH --> IAC
    IAC --> MON
    MON --> LOG
    LOG --> EVID
    DR --> EVID
```

Evidence can include:

* Region configuration
* Replication metrics
* Health-check results
* IAM audit records
* KMS activity
* Network-policy configuration
* Failover timestamps
* Transaction reconciliation
* DR drill results
* Incident reports

---

# 13. Data Sovereignty Control Summary

The intended data flow follows these principles:

```text
Payment Data
     |
     +----> Mumbai — ap-south-1
     |
     +----> Encrypted Replication
     |
     +----> Hyderabad — ap-south-2
```

The architecture avoids making an overseas region part of the primary payment-data replication path.

Any non-payment operational data processed outside India must undergo separate legal, security, and compliance assessment.

---

# 14. Final Architecture Flow

The complete high-level flow is:

```mermaid
flowchart TB
    USER[Customers / Merchants]
    DNS[Route 53]

    subgraph M["Primary — Mumbai ap-south-1"]
        MWAF[WAF]
        MALB[ALB]
        MEKS[EKS]
        MDB[(Aurora)]
        MDDB[(DynamoDB)]
        MRED[(Redis)]
        MKAFKA[(MSK)]
    end

    subgraph H["DR — Hyderabad ap-south-2"]
        HWAF[WAF]
        HALB[ALB]
        HEKS[EKS]
        HDB[(Aurora)]
        HDDB[(DynamoDB)]
        HRED[(Redis)]
        HKAFKA[(MSK)]
    end

    USER --> DNS
    DNS --> MWAF
    MWAF --> MALB
    MALB --> MEKS

    MEKS --> MDB
    MEKS --> MDDB
    MEKS --> MRED
    MEKS --> MKAFKA

    MDB -->|Replication| HDB
    MDDB <-->|Global Tables| HDDB
    MRED -->|Replication| HRED
    MKAFKA -->|Replication| HKAFKA

    DNS -. Failover .-> HWAF
    HWAF --> HALB
    HALB --> HEKS

    HEKS --> HDB
    HEKS --> HDDB
    HEKS --> HRED
    HEKS --> HKAFKA
```

---

# 15. Conclusion

The PaySecure data-flow architecture provides a controlled path for payment processing, regional replication, disaster recovery, and transaction reconciliation.

The design keeps the primary payment-processing environments within Indian AWS regions and provides a clear failover path from Mumbai to Hyderabad.

The most important controls are:

* India-region payment data processing
* Encrypted cross-region replication
* Replication-lag monitoring
* Route 53 health-based failover
* Idempotency protection
* Transaction reconciliation
* Kafka replication monitoring
* Consistent security controls in both regions
* Audit evidence collection
* Controlled failback

These flows complement the compliance matrix and provide the implementation-level view required to demonstrate how data moves through the multi-region DR architecture.
