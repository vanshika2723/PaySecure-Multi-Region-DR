# PaySecure Gateway — Data Sovereignty & Compliance Matrix

## 1. Purpose

This document maps the PaySecure Gateway multi-region disaster recovery architecture against the regulatory and security requirements identified in the project brief.

The primary objective is to ensure that regional disaster recovery does not cause payment data to leave the required geographic boundary during normal operation or a regional failover.

The architecture uses:

* AWS Mumbai (`ap-south-1`) as the primary region
* AWS Hyderabad (`ap-south-2`) as the DR region
* Region-local processing for payment workloads
* Cross-region replication between Indian AWS regions
* Encryption using AWS KMS
* Network segmentation for PCI DSS workloads
* Monitoring and audit logging
* Route 53 controlled failover

---

## 2. Data Sovereignty Principle

PaySecure processes financial transactions for Indian merchants and customers.

The architecture therefore separates data into categories according to sensitivity and regulatory relevance.

### Primary principle

**Payment and transaction data must remain within India.**

The DR architecture keeps the primary and secondary payment-processing environments in:

```text
Mumbai
ap-south-1
      ↕
Hyderabad
ap-south-2
```

Both regions are located within India.

This allows regional disaster recovery while maintaining the geographic boundary required by the project brief.

---

## 3. Data Categories

| Data Category               | Examples                                                | Primary Location | DR Location | Cross-Border Transfer                         |
| --------------------------- | ------------------------------------------------------- | ---------------- | ----------- | --------------------------------------------- |
| Payment transaction data    | Transaction ID, amount, status, payment reference       | Mumbai           | Hyderabad   | No                                            |
| Card/payment-sensitive data | Tokenized payment information, authorization metadata   | Mumbai           | Hyderabad   | No                                            |
| Merchant data               | Merchant ID, settlement configuration, account metadata | Mumbai           | Hyderabad   | No                                            |
| Customer/payment metadata   | Transaction-linked customer metadata                    | Mumbai           | Hyderabad   | No                                            |
| Operational telemetry       | Metrics, logs, service health data                      | India            | India       | Restricted / assessed                         |
| Non-PII operational data    | Generic deployment metadata, technical documentation    | India            | India       | May be processed externally only after review |

The exact classification of any additional dataset must be determined by PaySecure's compliance and legal teams before enabling external processing.

---

## 4. RBI Payment-System Requirements

The project brief identifies the RBI regulatory framework as a core requirement for the architecture.

The DR design therefore maintains:

* A dedicated DR environment
* Documented RTO/RPO objectives
* Automated failover capability
* Replicated payment data
* Recovery runbooks
* Periodic DR testing
* Incident-response procedures
* Audit evidence

The architecture target is:

```text
RTO < 5 minutes
RPO < 1 minute
```

These targets provide the engineering objectives used throughout the DR design.

> **Source note:** The specific regulatory wording and penalty figures in the project brief are treated as assessment requirements. Legal/compliance teams should verify the current RBI text before production implementation.

---

## 5. RBI Data Localisation

The project brief requires payment data for Indian transactions to remain within India.

The architecture satisfies this design requirement by maintaining payment-processing infrastructure in:

```text
AWS Mumbai
      |
      | encrypted replication
      ↓
AWS Hyderabad
```

The following workloads remain inside Indian regions:

* Aurora PostgreSQL
* DynamoDB
* ElastiCache
* Kafka/MSK
* S3 payment-related objects
* Payment API workloads
* Settlement processing
* Transaction processing
* Payment audit records

No payment database replication is designed to a foreign AWS region.

---

## 6. PCI DSS v4.0

PCI DSS requirements influence the security architecture of the payment-processing environment.

The design includes:

### Network Segmentation

PCI-sensitive services are separated using:

* VPC segmentation
* Security Groups
* Network ACLs
* Kubernetes NetworkPolicies
* Private subnets
* Controlled ingress and egress

### Encryption

Sensitive information is protected using:

* TLS for network communication
* Encryption at rest
* AWS KMS
* Region-aware key management

### Access Control

Administrative access uses:

* IAM least privilege
* Role-based access
* MFA
* Short-lived credentials
* Audit logging

### Monitoring

Security and operational activity is monitored using:

* CloudWatch
* CloudTrail
* Security alerts
* Application monitoring
* Central incident management

### Incident Response

The 12 DR runbooks provide documented response procedures for:

* Regional failure
* Database corruption
* DNS compromise
* Kafka failure
* Network partition
* Key compromise
* DDoS
* Third-party outage
* Certificate failure
* AZ failure
* Ransomware
* Cascading application failure

---

## 7. NPCI / UPI Operational Requirements

The project brief identifies UPI availability and automated failover as important requirements.

The architecture therefore includes:

* Route 53 health checks
* Automated health evaluation
* DR-region application capacity
* Payment API health endpoints
* Replicated transaction state
* Monitoring and alerting
* Failover runbooks

The payment API remains protected against duplicate processing through:

* Idempotency keys
* Transaction identifiers
* Database constraints
* Settlement reconciliation
* Controlled failover

---

## 8. Data Replication Controls

Cross-region replication is limited to the required Indian regions.

### Aurora PostgreSQL

Aurora Global Database provides cross-region database replication.

Controls include:

* Replication-lag monitoring
* Writer/reader role verification
* Controlled global failover
* Recovery validation

### DynamoDB

DynamoDB Global Tables provide multi-region replication.

Controls include:

* Replication monitoring
* Conflict-resolution strategy
* Idempotent transaction design
* Application-level validation

### ElastiCache

Redis replication is used for distributed cache availability.

Cache data is treated differently from the authoritative transaction database.

Critical financial state must not depend solely on cache availability.

### Kafka

MSK replication provides cross-region event replication.

The design monitors:

* Replication lag
* Consumer offsets
* Topic health
* Partition availability

---

## 9. Encryption and Key Management

Sensitive data must be encrypted both at rest and in transit.

The architecture uses AWS KMS for encryption key management.

Key controls include:

* Restricted key policies
* Least-privilege IAM access
* Key rotation
* CloudTrail audit logging
* Detection of unusual key usage
* Separate administrative permissions

Multi-region key capabilities should be evaluated for services that require controlled cross-region cryptographic operations.

A key compromise in one region must trigger the security procedures defined in `RB-06-key-compromise.md`.

---

## 10. Data Flow During Normal Operation

Normal transaction processing follows:

```text
Customer
   |
   v
Route 53
   |
   v
Mumbai ALB
   |
   v
Payment API
   |
   +----> Aurora PostgreSQL
   |
   +----> DynamoDB
   |
   +----> Redis
   |
   +----> Kafka
   |
   +----> S3 / Audit
```

Replication then transfers required data to Hyderabad using encrypted AWS regional services.

---

## 11. Data Flow During Regional Failover

During a Mumbai regional failure:

```text
Customer
   |
   v
Route 53 Health Check
   |
   | Mumbai unhealthy
   v
Hyderabad ALB
   |
   v
Payment API
   |
   +----> Hyderabad Database
   +----> Hyderabad DynamoDB
   +----> Hyderabad Redis
   +----> Hyderabad Kafka
```

Because both recovery regions are within India, the failover does not require moving payment data to an overseas region.

---

## 12. Compliance Controls Matrix

| Requirement                   | Architecture Control                  | Evidence                            |
| ----------------------------- | ------------------------------------- | ----------------------------------- |
| Payment data remains in India | Mumbai + Hyderabad deployment         | AWS region configuration            |
| Regional DR                   | Secondary Hyderabad environment       | Terraform / architecture diagram    |
| RTO < 5 min                   | Hot Standby + Route 53 failover       | Failover drill records              |
| RPO < 1 min                   | Database/event replication monitoring | CloudWatch metrics                  |
| PCI network segmentation      | VPC + Kubernetes NetworkPolicy        | IaC manifests                       |
| Encryption at rest            | AWS KMS                               | KMS configuration                   |
| Encryption in transit         | TLS                                   | Load balancer/service configuration |
| Least privilege               | IAM roles/policies                    | IAM audit                           |
| Incident response             | 12 DR/security runbooks               | Runbook repository                  |
| DR testing                    | Annual DR drill plan                  | Drill reports                       |
| Auditability                  | CloudTrail/CloudWatch                 | Logs and dashboards                 |
| UPI resilience                | Health checks + failover              | DR drill evidence                   |
| Replication monitoring        | CloudWatch alarms                     | Alarm configuration                 |
| Key compromise response       | Key compromise runbook                | RB-06                               |
| Regional failure response     | Region failure runbook                | RB-01                               |

---

## 13. Evidence Required for Audit

The following evidence should be maintained:

1. Architecture diagrams
2. Terraform configuration
3. AWS region configuration
4. Database replication metrics
5. Route 53 health-check configuration
6. CloudWatch alarm configuration
7. IAM access reviews
8. KMS key policies
9. Network segmentation rules
10. DR drill reports
11. Incident-response runbooks
12. Failover test results
13. Transaction reconciliation reports
14. Security monitoring records
15. Change-management records

Audit evidence should be retained according to PaySecure's approved retention policy.

---

## 14. Data Sovereignty During DR

Data sovereignty controls must remain active during a disaster.

The failover process must not bypass normal security controls.

Before failover:

* Confirm Hyderabad is healthy
* Confirm required data replication
* Confirm encryption keys
* Confirm application configuration
* Confirm network segmentation
* Confirm monitoring

During failover:

* Redirect production traffic
* Verify payment processing
* Monitor replication and transaction state
* Verify settlement processing
* Maintain audit logging

After failover:

* Reconcile transactions
* Verify merchant settlement records
* Investigate incomplete transactions
* Review data integrity
* Record the event for audit

---

## 15. Compliance Gap Management

A compliance matrix should not be considered a one-time activity.

The following process should be followed:

```text
Requirement
     ↓
Architecture Control
     ↓
IaC Configuration
     ↓
Monitoring
     ↓
DR Drill
     ↓
Evidence Collection
     ↓
Compliance Review
     ↓
Remediation
```

Any control that cannot be demonstrated through evidence should be treated as a potential audit gap.

---

## 16. Conclusion

The PaySecure multi-region DR architecture is designed around an India-only payment-data processing model.

Mumbai and Hyderabad provide geographic separation while keeping payment-processing workloads within India.

The architecture combines:

* Regional redundancy
* Encrypted replication
* PCI-oriented network segmentation
* IAM least privilege
* KMS encryption
* Route 53 failover
* Continuous monitoring
* Documented recovery procedures
* Regular DR testing

The compliance matrix provides the traceability between regulatory objectives, architecture controls, implementation mechanisms, and audit evidence.

All regulatory interpretations must be validated against the latest applicable RBI, NPCI, PCI DSS, and legal requirements before production deployment.
