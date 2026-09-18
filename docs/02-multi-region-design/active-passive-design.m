# Active-Passive Multi-Region Architecture Design

## 1. Architecture Overview

PaySecure Gateway currently operates its production payment platform from AWS Mumbai (`ap-south-1`). The proposed active-passive design introduces AWS Hyderabad (`ap-south-2`) as a disaster recovery region.

Mumbai remains the primary production region and serves normal customer and merchant traffic. Hyderabad is maintained as a warm standby environment with application infrastructure, replicated data services, security controls, monitoring, and failover configuration prepared in advance.

The purpose of the architecture is to provide regional disaster recovery while preserving payment transaction integrity and minimizing service interruption.

The high-level architecture is:

```text
                         Merchants / Internet
                                  |
                                  v
                           Amazon Route 53
                         Failover + Health Check
                              /          \
                             /            \
                            v              v
                 Mumbai Primary       Hyderabad DR
                  ap-south-1           ap-south-2
                 ACTIVE REGION       WARM STANDBY
                      |                    |
                      v                    v
                    WAF                  WAF
                      |                    |
                     ALB                  ALB
                      |                    |
                     EKS                  EKS
                      |                    |
          12 Production Services     12 Standby Services
                      |                    |
       +--------------+-------------+------+------+
       |              |             |             |
     Aurora        DynamoDB       Redis          Kafka
       |              |             |             |
       +--------------+-------------+-------------+
                       Replication
```

Under normal conditions, Mumbai receives production traffic. Hyderabad remains synchronized and ready to become the production region when a confirmed regional disaster occurs.

---

## 2. Regional Selection

Mumbai (`ap-south-1`) is retained as the primary region because it is the existing production region.

Hyderabad (`ap-south-2`) is selected as the disaster recovery region because it provides geographic separation from Mumbai while remaining within India. This separation reduces the probability that a localized Mumbai regional incident will simultaneously affect the DR environment.

The approximate Mumbai-to-Hyderabad network round-trip latency used for architectural planning is 15–25 ms. This makes cross-region replication practical for asynchronous replication patterns while maintaining the required geographic separation.

The two-region design also supports India's data-localization requirement by keeping replicated payment-related data within Indian AWS regions.

---

## 3. Application Architecture

The application layer is deployed on Amazon EKS in both regions.

Mumbai contains the active production EKS cluster. The cluster hosts the twelve PaySecure microservices:

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

The same application versions and Kubernetes configurations are maintained in Hyderabad.

The Hyderabad EKS environment is warm standby rather than a normal production serving environment. Required Kubernetes Deployments, Services, ConfigMaps, Secrets references, ingress configuration, and observability components are pre-provisioned.

The standby environment should continuously perform health validation so that deployment drift is detected before an actual disaster.

Infrastructure and Kubernetes configuration are maintained using Infrastructure as Code. Terraform is used for AWS infrastructure and Kubernetes manifests or Helm-based deployment processes are used for application configuration.

---

## 4. Normal Traffic Flow

During normal operation, all production traffic is directed to Mumbai.

The normal request path is:

```text
Merchant
   |
   v
Route 53
   |
   v
AWS WAF / Shield
   |
   v
Mumbai ALB
   |
   v
Mumbai EKS
   |
   +----> Aurora PostgreSQL
   +----> DynamoDB
   +----> ElastiCache Redis
   +----> Amazon MSK
```

Hyderabad does not normally receive production payment traffic.

Route 53 health checks continuously evaluate the health of the primary endpoint. Application health should be determined using meaningful application-level checks rather than only checking whether an ALB is reachable.

---

## 5. Aurora PostgreSQL Replication

Aurora PostgreSQL is the primary relational database for transaction, merchant, and settlement workloads.

Mumbai acts as the primary Aurora cluster. Hyderabad maintains the secondary Aurora cluster through Aurora Global Database replication.

The replication model is asynchronous.

```text
Mumbai Aurora
Primary Writer
     |
     | Cross-region asynchronous replication
     v
Hyderabad Aurora
Secondary Cluster
```

During normal operation, writes occur in Mumbai.

The Hyderabad cluster continuously receives replicated database changes. Replication lag must be monitored through CloudWatch metrics and operational alarms.

During a regional failure, the DR procedure first verifies that Mumbai is genuinely unavailable or unsafe for writes. The Hyderabad Aurora cluster is then promoted according to the approved failover procedure.

The application connection configuration is changed so that payment services use the promoted Hyderabad writer.

Database promotion must be coordinated with DNS and application activation to prevent both regions from accepting conflicting writes.

---

## 6. DynamoDB Replication

DynamoDB is used for transaction metadata, idempotency records, and other high-scale NoSQL workloads.

The proposed design uses DynamoDB Global Tables to maintain replicated table data between Mumbai and Hyderabad.

The logical model is:

```text
DynamoDB Mumbai
       |
       | Global Table replication
       |
       v
DynamoDB Hyderabad
```

DynamoDB replication provides regional copies of required application data.

Particular attention is required for payment idempotency records. A retry generated during failover must not result in a duplicate financial transaction.

Therefore, every payment request should contain a durable idempotency key. The key and associated transaction state must be replicated consistently enough to prevent duplicate processing.

Application logic must also validate transaction state before creating a new financial operation.

---

## 7. Redis Replication

ElastiCache Redis is used for sessions, caching, rate limits, and short-lived application state.

The proposed architecture uses a cross-region Redis replication approach appropriate to the selected ElastiCache deployment.

Not every Redis value has the same recovery requirement.

Cache entries can generally be recreated from durable systems. However, session state and rate-limiting information may affect user experience and security controls.

Therefore, the DR design categorizes Redis data into:

* Reconstructable cache data
* Replicated session state
* Rate-limit state
* Temporary operational state

During failover, the application should not assume that every cached value is authoritative.

Durable transaction state remains in Aurora and DynamoDB.

---

## 8. Kafka Replication

Apache Kafka is an important part of the PaySecure asynchronous processing architecture.

Mumbai contains the primary Amazon MSK cluster. Hyderabad contains the DR Kafka environment.

Relevant topics include:

* Payment events
* Transaction events
* Settlement events
* Webhook events
* Notification events
* Audit events

Cross-region Kafka replication is used to copy required events to Hyderabad.

Replication monitoring must track:

* Replication lag
* Consumer lag
* Topic availability
* Partition health
* Message throughput
* Offset differences

During normal operation, Mumbai is the authoritative event-processing region.

During failover, the DR Kafka environment is activated and consumers are started according to the runbook.

The failover process must avoid processing the same financial event twice. Consumers therefore require idempotent processing and transaction-state validation.

---

## 9. DNS Failover

Amazon Route 53 provides the regional traffic-switching mechanism.

The DNS configuration uses failover routing:

```text
                   Route 53
                      |
              Health Check
                 /         \
                /           \
        PRIMARY             SECONDARY
       Mumbai              Hyderabad
     ap-south-1             ap-south-2
```

Mumbai is configured as the primary endpoint.

Hyderabad is configured as the secondary endpoint.

If Mumbai fails the required health checks, Route 53 can return the secondary endpoint.

The DNS health check must represent application availability rather than only infrastructure availability.

For example, the health endpoint should validate that:

* Application pods are responding
* Required dependencies are reachable
* The payment API is operational
* Database connectivity is healthy
* The application is not in a maintenance or fail-safe state

DNS TTL must be selected and tested as part of the DR drill because DNS propagation and client-side caching can influence the actual recovery time.

---

## 10. Health Monitoring

Health monitoring is divided into several layers.

### Infrastructure Health

Monitor:

* EKS node health
* ALB health
* CPU and memory utilization
* Network errors
* Availability Zone status

### Application Health

Monitor:

* HTTP 5xx rate
* Payment success rate
* API latency
* Request throughput
* Pod restart rate
* Circuit-breaker state

### Database Health

Monitor:

* Aurora availability
* Database connections
* CPU
* storage
* replication lag
* failover state

### Kafka Health

Monitor:

* Broker health
* Partition availability
* Consumer lag
* Replication lag
* Under-replicated partitions

### DR Health

Monitor:

* Mumbai-to-Hyderabad replication status
* Backup freshness
* Application deployment drift
* Standby capacity
* DNS health-check status

---

## 11. RPO Strategy

The target Recovery Point Objective is less than one minute.

The design therefore uses continuous or near-continuous replication for critical data.

The primary mechanisms are:

| Component         | Replication Approach                                 |
| ----------------- | ---------------------------------------------------- |
| Aurora PostgreSQL | Cross-region asynchronous replication                |
| DynamoDB          | Global Tables                                        |
| Redis             | Cross-region replication / Global Datastore approach |
| Kafka             | Cross-region topic replication                       |
| S3                | Cross-region replication where applicable            |
| Application       | Pre-deployed in both regions                         |

Replication lag must be continuously monitored.

A DR controller should not automatically promote the secondary region merely because a single metric crosses a threshold. Promotion requires a controlled decision process to avoid split-brain conditions.

---

## 12. RTO Strategy

The target Recovery Time Objective is less than five minutes.

The architecture reduces recovery time by keeping critical infrastructure pre-provisioned.

The recovery sequence is:

```text
Region Failure Detected
        |
        v
Confirm Incident
        |
        v
Freeze / Prevent Unsafe Writes
        |
        v
Promote DR Databases
        |
        v
Activate EKS Workloads
        |
        v
Activate Kafka Consumers
        |
        v
Validate Payment APIs
        |
        v
Route 53 Failover
        |
        v
Monitor Transactions
```

The exact timing must be validated through controlled DR drills.

A five-minute RTO should be treated as a tested objective rather than an assumption.

---

## 13. Split-Brain Prevention

Split-brain is one of the most important risks in a payment-processing architecture.

Split-brain occurs when both regions believe that they are authoritative and independently accept writes.

To prevent this, failover must follow an explicit fencing procedure.

Before Hyderabad becomes the active region:

1. Confirm Mumbai regional failure.
2. Verify whether Mumbai can still accept traffic.
3. Disable or fence Mumbai write paths where possible.
4. Confirm replication state.
5. Promote the Hyderabad database.
6. Activate Hyderabad application processing.
7. Switch DNS.
8. Validate transaction processing.

Only one region should be designated as the authoritative payment-processing writer at a time.

---

## 14. Transaction Ordering and Idempotency

Payment transactions require strong protection against duplicate processing.

Every payment request should have a unique idempotency key.

The application should store:

* Idempotency key
* Merchant identifier
* Request identifier
* Transaction identifier
* Processing status
* Timestamp
* Result

When a request is retried after failover, the DR application first checks the replicated transaction state.

If the transaction already completed, the original result is returned instead of creating another payment operation.

Kafka consumers should also implement idempotent processing.

This approach reduces the risk of duplicate settlement, duplicate webhook delivery, or duplicate downstream financial operations.

---

## 15. Security Architecture

Security controls must be maintained consistently in both regions.

The design includes:

* IAM least-privilege policies
* AWS KMS encryption
* AWS Secrets Manager
* TLS/mTLS
* Security Groups
* Network segmentation
* AWS WAF
* AWS Shield
* CloudTrail
* Centralized security monitoring

Encryption keys and secrets required by the Hyderabad environment must be available through a controlled and auditable process.

PCI-related workloads must remain isolated within the appropriate Cardholder Data Environment boundary.

Security controls must not be relaxed during an emergency failover.

---

## 16. Observability During DR

Both regions must send operational telemetry to the monitoring platform.

Important DR dashboards include:

* Regional health
* Transaction success rate
* P99 latency
* Database replication lag
* Kafka replication lag
* Kafka consumer lag
* DNS health
* EKS pod health
* Error rates
* Payment reconciliation status

A dedicated DR dashboard should show whether the Hyderabad environment is actually ready to accept production traffic.

Alerts should be configured for replication lag and standby health rather than discovering these issues only during an incident.

---

## 17. Failover Process

The high-level failover procedure is:

### Phase 1 — Detection

Monitoring detects degradation or complete loss of Mumbai.

### Phase 2 — Assessment

The incident commander determines whether the problem is regional, application-specific, database-specific, or caused by an external dependency.

### Phase 3 — Fencing

Unsafe Mumbai writes are stopped or isolated to prevent split-brain.

### Phase 4 — Data Promotion

Hyderabad Aurora is promoted.

DynamoDB and replicated messaging systems are validated.

Redis is activated according to the DR procedure.

### Phase 5 — Application Activation

Hyderabad EKS workloads are scaled to production capacity.

Required consumers and background workers are enabled.

### Phase 6 — Traffic Switching

Route 53 changes the active endpoint from Mumbai to Hyderabad.

### Phase 7 — Validation

The team validates:

* Authentication
* Merchant APIs
* Payment authorization
* Transaction status
* Settlement processing
* Webhooks
* Reconciliation
* Monitoring

### Phase 8 — Stabilization

Traffic, error rates, latency, database state, and Kafka lag are continuously monitored.

---

## 18. Failback Strategy

Failback should not happen immediately after Mumbai becomes available.

First, Mumbai infrastructure must be rebuilt or validated.

Database synchronization must be established.

The team must confirm that no outstanding transactions or settlement events remain inconsistent.

A controlled failback sequence should then be executed:

```text
Validate Mumbai
      |
      v
Synchronize Data
      |
      v
Validate Applications
      |
      v
Controlled Traffic Shift
      |
      v
Monitor
      |
      v
Return to Normal Primary/Standby State
```

Failback should be performed during a controlled maintenance window unless business continuity requirements demand otherwise.

---

## 19. Capacity Planning

Hyderabad must have enough pre-provisioned capacity to meet the recovery objective.

Warm standby capacity should support essential production workloads immediately and provide a defined scale-out mechanism for the remaining workload.

Capacity planning must consider the peak throughput requirement of approximately 1,200 TPS.

The team should maintain tested scaling policies for:

* EKS nodes
* Application pods
* Aurora capacity
* Kafka brokers
* Redis
* Load balancers

Peak-load failover must be included in DR drills because a standby environment that works only under low traffic does not satisfy the practical recovery objective.

---

## 20. Operational Trade-offs

The active-passive model reduces the complexity of concurrent multi-region transaction processing because only one region normally acts as the production writer.

However, it introduces several operational requirements.

The standby environment creates additional infrastructure cost even when it is not serving normal production traffic.

The team must continuously maintain configuration parity between Mumbai and Hyderabad.

Replication lag can also result in a small amount of data exposure during a sudden regional failure, which is why replication monitoring and the sub-one-minute RPO objective are important.

DNS caching can influence the actual time required for every client to move to Hyderabad.

These limitations must be measured through regular DR drills.

---

## 21. Business Continuity Model

The proposed active-passive architecture provides a controlled disaster recovery model:

| Area           | Mumbai         | Hyderabad              |
| -------------- | -------------- | ---------------------- |
| Normal Traffic | Active         | Standby                |
| EKS            | Production     | Warm Standby           |
| Aurora         | Primary        | Secondary              |
| DynamoDB       | Global Replica | Global Replica         |
| Redis          | Primary        | Secondary              |
| Kafka          | Primary        | DR Replica             |
| Route 53       | Primary Target | Failover Target        |
| Monitoring     | Active         | Continuously Monitored |
| Failover       | N/A            | Activated during DR    |

This model simplifies transaction ownership and reduces split-brain risk compared with allowing both regions to process financial writes simultaneously.

---

## 22. Conclusion

The proposed active-passive architecture extends PaySecure from a single-region Mumbai deployment to a two-region Indian disaster recovery platform.

Mumbai remains the active production region while Hyderabad operates as a continuously monitored warm standby environment.

The design uses EKS for application redundancy, Aurora PostgreSQL cross-region replication for relational data, DynamoDB Global Tables for NoSQL replication, cross-region Redis replication for required state, and Kafka replication for asynchronous events.

Route 53 provides DNS-level regional failover, while CloudWatch, Prometheus, Grafana, and application health checks provide continuous visibility into regional and replication health.

The design emphasizes controlled failover, transaction idempotency, transaction ordering, split-brain prevention, security, and data localization.

The target of less than one-minute RPO and less than five-minute RTO must ultimately be demonstrated through measured disaster recovery drills. The architecture therefore provides the foundation, while the runbooks, automation, monitoring, and annual DR exercises validate whether the operational objectives are actually achieved.
