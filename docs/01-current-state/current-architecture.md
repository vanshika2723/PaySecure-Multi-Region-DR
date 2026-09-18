# Current-State Architecture — PaySecure Gateway

## 1. Overview

PaySecure Gateway Private Limited is a mid-tier payment aggregator operating its production platform from a single AWS region, Mumbai (`ap-south-1`). The platform processes approximately 3.2 million transactions per day with a daily transaction value of around ₹500 crore. The platform supports approximately 45,000 merchants and experiences peak traffic of approximately 1,200 transactions per second (TPS).

The current production environment provides approximately 99.92% uptime. Although the platform is distributed across multiple Availability Zones within the Mumbai region, the architecture remains region-dependent. A complete regional outage, regional networking problem, or large-scale AWS service disruption in Mumbai could therefore affect the complete payment-processing platform.

The current architecture is designed around Amazon EKS for containerized microservices and uses managed AWS data services including Amazon Aurora PostgreSQL, Amazon DynamoDB, Amazon ElastiCache for Redis, and Amazon MSK for Apache Kafka workloads.

The current architecture is the baseline for designing the future multi-region disaster recovery solution.

---

## 2. AWS Region and VPC Architecture

The complete production workload is hosted in AWS Mumbai (`ap-south-1`). The primary VPC uses the CIDR range `10.0.0.0/16`.

The workload is distributed across three Availability Zones:

* `ap-south-1a`
* `ap-south-1b`
* `ap-south-1c`

The VPC is logically divided into public, private application, and private database networking areas.

Public-facing components provide controlled entry into the application environment. Application workloads operate inside private subnets, while database and data services are isolated from direct internet access.

Security Groups and IAM policies are used to control communication between application, database, messaging, and infrastructure components.

The three-AZ design reduces the impact of an individual Availability Zone failure. However, all three Availability Zones are still located inside the same AWS region. Therefore, an outage affecting the complete Mumbai region remains a major failure domain.

---

## 3. Internet and Application Traffic Flow

External merchants and payment clients connect to PaySecure through HTTPS/TLS.

The logical request flow is:

```text
Merchant / Internet
        |
        v
Amazon Route 53
        |
        v
AWS WAF / AWS Shield
        |
        v
Application Load Balancer
        |
        v
Amazon EKS
        |
        v
PaySecure Microservices
```

Amazon Route 53 provides DNS resolution for the application endpoint.

AWS WAF provides web-application protection, while AWS Shield provides protection against distributed denial-of-service attacks.

The Application Load Balancer acts as the application entry point and distributes HTTPS traffic to the EKS workloads. Listener rules can route traffic toward appropriate application services.

The architecture uses HTTPS/TLS for external communication and HTTPS or gRPC for service-to-service communication where applicable.

---

## 4. Amazon EKS and Microservices

Amazon EKS hosts the application's containerized microservices.

The production platform contains twelve major microservices:

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

The microservices are deployed across the three Availability Zones to provide application-level redundancy.

The API Gateway and payment-related services receive requests from the Application Load Balancer. Authentication validates requests and merchant identity. Merchant and transaction services manage merchant and transaction information.

The Payment Service handles payment processing while Fraud Detection performs transaction-risk evaluation. Payment Routing determines the appropriate payment route. Settlement and Reconciliation support downstream financial processing.

Notification and Webhook services communicate payment status to relevant consumers, while Audit Service records important application and transaction events.

Inter-service communication can use HTTPS or gRPC. Asynchronous events are delivered through Apache Kafka.

---

## 5. Aurora PostgreSQL Database

Amazon Aurora PostgreSQL is used for relational transactional workloads.

The database layer contains the primary transactional data required by the platform, including merchant, transaction, and settlement information.

Aurora provides database availability within the Mumbai region through its managed architecture. Database access is restricted to authorized application workloads through private networking and security controls.

Payment and transaction services interact with Aurora using encrypted database connections.

The major limitation of the current design is regional dependency. Even when Aurora provides high availability within `ap-south-1`, a complete regional failure can make the database unavailable to the application.

This regional dependency is one of the key reasons for introducing cross-region database replication in the future DR architecture.

---

## 6. DynamoDB

Amazon DynamoDB is used for high-scale NoSQL workloads such as transaction metadata and idempotency-related records.

Idempotency records are particularly important for payment processing because the same payment request must not accidentally result in multiple financial transactions when clients retry requests.

The application communicates with DynamoDB through AWS APIs.

DynamoDB provides a managed and scalable data layer, but the current deployment remains part of the overall Mumbai-region architecture. Therefore, regional resilience must be considered when designing the future disaster recovery solution.

---

## 7. ElastiCache Redis

Amazon ElastiCache for Redis is used for low-latency data access.

Typical workloads include:

* Session information
* Frequently accessed cached data
* Rate-limiting information
* Short-lived application state

Redis improves application response times by reducing repeated database access.

Because Redis contains application state and cached information, the DR design must distinguish between data that can simply be recreated and state that must be preserved or replicated during a disaster.

A regional failure can affect Redis availability even when the application tier itself is deployed across multiple Availability Zones.

---

## 8. Amazon MSK and Apache Kafka

Amazon MSK provides the Apache Kafka messaging layer.

Kafka is used for asynchronous event processing across payment, settlement, webhook, and audit workflows.

Representative event categories include:

* Payment events
* Transaction events
* Settlement events
* Webhook events
* Audit events

Kafka allows services to decouple synchronous payment processing from downstream asynchronous processing.

For example, a payment transaction can produce an event that is consumed by settlement, notification, webhook, reconciliation, or audit workflows.

Kafka is therefore a critical component of the payment platform. A major Kafka outage can cause event-processing delays, settlement delays, webhook delays, and audit-data gaps.

The current architecture remains dependent on the Mumbai Kafka environment, making cross-region messaging resilience an important requirement for the future DR architecture.

---

## 9. Security Architecture

Security is implemented through multiple layers.

The architecture uses:

* IAM for identity and access management
* Security Groups for network-level access control
* AWS KMS for encryption-key management
* AWS Secrets Manager for application secrets
* TLS for encrypted communication
* AWS CloudTrail for API and activity auditing
* AWS WAF and AWS Shield for edge protection

Payment and card-related workloads are treated as part of the PCI DSS Cardholder Data Environment (CDE).

The CDE boundary separates sensitive payment-processing components from general application workloads. Access should follow least-privilege principles, and sensitive data should be encrypted both in transit and at rest.

Security logs and audit information are monitored to identify unauthorized activity and operational anomalies.

---

## 10. Observability and Monitoring

The production environment requires continuous monitoring because payment processing is a business-critical workload.

The observability layer includes:

* Amazon CloudWatch
* Prometheus
* Grafana
* Centralized application logs
* AWS CloudTrail
* Alerting and incident-management tooling

Important metrics include transaction success rate, request latency, HTTP error rates, application health, database health, Kafka consumer lag, infrastructure utilization, and security events.

The platform currently reports approximately 99.92% uptime with approximately 180 ms P99 latency.

Monitoring is also important for future disaster recovery because automated health checks will be required to determine whether the primary region is healthy enough to continue serving payment traffic.

---

## 11. External Payment Integrations

PaySecure communicates with external payment ecosystem components such as NPCI/UPI, banks, and payment partners.

These integrations are outside the direct control of the PaySecure AWS infrastructure.

Therefore, an external NPCI/UPI outage must be distinguished from an internal AWS-region failure.

A healthy PaySecure application cannot guarantee successful payment processing if a required external payment dependency is unavailable.

This distinction will be important in the future DR runbooks, where the operations team must determine whether a failure is caused by PaySecure infrastructure, the AWS region, or an external payment dependency.

---

## 12. Current Failure Domains

The current architecture has several failure domains.

### Availability Zone Failure

The three-AZ deployment provides resilience against failure of an individual Availability Zone. Application workloads can continue using resources in other Availability Zones, subject to available capacity and dependency health.

### Database Failure

A database failure can affect transaction processing, merchant operations, settlement, and reconciliation workflows.

### Kafka Failure

A Kafka failure can affect asynchronous event processing and create consumer lag or delayed downstream workflows.

### Network Failure

A networking problem can prevent application components from communicating with databases, Kafka, external payment providers, or users.

### Complete Region Failure

The largest failure domain is the complete AWS Mumbai region.

If `ap-south-1` becomes unavailable, all production application and data services located in that region can be affected simultaneously.

---

## 13. Current Single Points of Regional Dependency

Although the platform is distributed across three Availability Zones, it remains a single-region architecture.

The major regional dependencies include:

* EKS production workloads
* Aurora PostgreSQL
* DynamoDB workloads
* ElastiCache Redis
* Amazon MSK
* Application Load Balancer
* Regional networking
* Regional security and supporting infrastructure

The absence of a fully operational second-region production environment means that recovery from a complete regional failure would require significant recovery actions.

This creates risk against the target RPO of less than one minute and RTO of less than five minutes.

---

## 14. Baseline for Disaster Recovery

The current architecture establishes the baseline for the multi-region DR project.

The target architecture must extend the existing Mumbai environment into a second AWS Indian region while preserving payment-processing integrity, security, observability, and regulatory requirements.

The future design will evaluate active-active and active-passive deployment models.

The disaster recovery architecture must address:

* Cross-region application deployment
* Database replication
* Kafka replication
* Redis replication
* DNS failover
* Automated health checks
* Data consistency
* Transaction ordering
* Idempotency
* Split-brain prevention
* Security-key management
* Data sovereignty
* Disaster recovery runbooks
* Cost and operational impact

The current Mumbai architecture therefore serves as the reference architecture against which the future multi-region solution will be compared.

---

## 15. Conclusion

PaySecure's current three-AZ Mumbai deployment provides useful Availability Zone-level resilience, but it does not eliminate the risk of a complete regional outage.

The architecture contains a complete payment-processing stack consisting of Route 53, WAF/Shield, an Application Load Balancer, Amazon EKS, twelve microservices, Aurora PostgreSQL, DynamoDB, ElastiCache Redis, Amazon MSK, security services, monitoring services, and external payment integrations.

The primary architectural limitation is that these critical workloads remain dependent on a single AWS region.

The next stage of the project will therefore design multi-region active-passive and active-active architectures, evaluate their operational characteristics, define component-specific replication strategies, and establish DNS-based disaster failover capable of meeting the project's RPO and RTO objectives.
