# PaySecure Gateway — Multi-Region Disaster Recovery Architecture

## Project 1C: DevOps & Cloud Engineer — Multi-Region DR Architecture for Payment Systems

**Project:** PaySecure Gateway Private Limited
**Primary Region:** AWS Mumbai (`ap-south-1`)
**DR Region:** AWS Hyderabad (`ap-south-2`)
**Architecture:** Hot Standby / Active-Passive Multi-Region DR
**Target Availability:** 99.99%
**Target RPO:** < 1 minute
**Target RTO:** < 5 minutes

---

## 1. Executive Summary

PaySecure Gateway is a mid-tier payment aggregator processing approximately **3.2 million transactions per day**, with a daily transaction value of approximately **₹500 crore** and around **45,000 merchants**.

The existing platform operates primarily from a single AWS Mumbai region and currently provides approximately **99.92% uptime**. The objective of this project is to design a production-oriented multi-region Disaster Recovery architecture capable of meeting a target availability of **99.99%**, an **RPO below one minute**, and an **RTO below five minutes**.

The proposed architecture uses:

* AWS Mumbai (`ap-south-1`) as the primary region
* AWS Hyderabad (`ap-south-2`) as the disaster recovery region
* Hot-standby / active-passive application architecture
* Amazon EKS for containerized workloads
* Aurora PostgreSQL Global Database
* DynamoDB Global Tables
* ElastiCache Redis Global Datastore
* Amazon MSK with cross-region replication
* Amazon S3 Cross-Region Replication
* Amazon Route 53 health checks and failover routing
* AWS KMS, WAF and Shield security controls
* CloudWatch, Prometheus, Grafana and PagerDuty for monitoring and incident response
* Terraform-based infrastructure management
* Structured disaster recovery runbooks and annual DR drills

---

## 2. Business Context

### Current Environment

| Metric                              | Current State |
| ----------------------------------- | ------------: |
| Daily Transactions                  |   3.2 million |
| Daily Transaction Value             |    ₹500 crore |
| Peak TPS                            |         1,200 |
| Merchants                           |        45,000 |
| Current Availability                |        99.92% |
| Target Availability                 |        99.99% |
| P99 Latency                         |        180 ms |
| Current Infrastructure              |    AWS Mumbai |
| Platform / Infrastructure Engineers |             8 |
| Current Infrastructure Spend        | ₹8 crore/year |

### Target DR Objectives

| Objective      |                 Target |
| -------------- | ---------------------: |
| Availability   |                 99.99% |
| RPO            |             < 1 minute |
| RTO            |            < 5 minutes |
| DR Region      |          AWS Hyderabad |
| Data Residency |                  India |
| Failover       | Automated / controlled |
| DR Validation  |     Quarterly + Annual |

The target of 99.99% availability corresponds to approximately **52.6 minutes of allowable downtime per year**.

---

## 3. Architecture Decision

The selected design is a **Hot Standby / Active-Passive multi-region architecture**.

### Primary Region

**Mumbai — `ap-south-1`**

The Mumbai region handles normal production traffic and acts as the primary writer/processing region.

### DR Region

**Hyderabad — `ap-south-2`**

The Hyderabad environment remains continuously synchronized and ready to accept production traffic during a regional failure or other declared disaster.

### Failover Flow

```text
                    Internet / Merchants
                           |
                           v
                 Amazon Route 53
                  Health Checks
                           |
             +-------------+-------------+
             |                           |
             v                           v
       Mumbai Region              Hyderabad Region
       ap-south-1                 ap-south-2
       PRIMARY                    DR / HOT STANDBY
             |                           |
             v                           v
          AWS EKS                    AWS EKS
             |                           |
             +-------------+-------------+
                           |
                    Data Replication
                           |
       +-------------------+-------------------+
       |                   |                   |
       v                   v                   v
 Aurora Global DB    DynamoDB Global      Redis Global
                     Tables               Datastore
       |
       +-------------------+
       |
       v
       Amazon MSK
       Cross-Region Replication
```

---

## 4. Core AWS Services

| Layer             | Technology                         | DR Strategy                      |
| ----------------- | ---------------------------------- | -------------------------------- |
| DNS               | Route 53                           | Health checks + failover routing |
| Compute           | Amazon EKS                         | Hot standby                      |
| Relational DB     | Aurora PostgreSQL Global Database  | Cross-region replication         |
| NoSQL             | DynamoDB Global Tables             | Multi-region replication         |
| Cache             | ElastiCache Redis Global Datastore | Cross-region replication         |
| Messaging         | Amazon MSK                         | Cross-region replication         |
| Object Storage    | Amazon S3                          | Cross-Region Replication         |
| Security          | KMS, WAF, Shield                   | Multi-region security controls   |
| Monitoring        | CloudWatch                         | Cross-region monitoring          |
| Metrics           | Prometheus / Grafana               | Centralized observability        |
| Incident Response | PagerDuty                          | P1/P2 alerting                   |
| Infrastructure    | Terraform                          | Infrastructure consistency       |

---

## 5. Disaster Recovery Objectives

The architecture is designed around the following recovery objectives:

### RPO — Recovery Point Objective

**Less than 1 minute**

Payment transaction data and supporting state should be replicated continuously so that a regional failure results in minimal data loss.

### RTO — Recovery Time Objective

**Less than 5 minutes**

The failover process is designed to detect a regional failure, validate the DR environment, redirect traffic and restore payment processing within the target recovery window.

### Availability

**99.99% target**

The multi-region architecture reduces dependency on a single AWS region and provides a controlled recovery path for regional failures.

---

## 6. Data Replication Strategy

### Aurora PostgreSQL

Aurora PostgreSQL Global Database is used for cross-region relational database replication.

Key considerations:

* Continuous replication from Mumbai to Hyderabad
* Replication lag monitoring
* Controlled writer promotion
* Point-in-time recovery
* Post-failover validation
* Split-brain prevention

### DynamoDB

DynamoDB Global Tables provide multi-region data replication.

Monitoring includes:

* Replication latency
* Write conflicts
* Failed replication events
* Region health
* Data consistency validation

### ElastiCache Redis

Redis Global Datastore provides cross-region replication for cache state.

Cache data is treated differently from system-of-record payment data. Cache recovery must not compromise transaction correctness.

### Amazon MSK

Kafka workloads use cross-region replication to maintain critical event streams.

Important controls include:

* Consumer lag monitoring
* Replication lag monitoring
* Topic validation
* Consumer-group validation
* Offset reconciliation
* Duplicate-event protection

### Amazon S3

S3 Cross-Region Replication is used for required objects and operational artifacts.

---

## 7. DNS Failover

Amazon Route 53 is used as the DNS failover layer.

### Normal State

```text
Merchant
   |
   v
Route 53
   |
   v
Mumbai ALB
   |
   v
Mumbai EKS
```

### Disaster State

```text
Merchant
   |
   v
Route 53
   |
   | Mumbai unhealthy
   v
Hyderabad ALB
   |
   v
Hyderabad EKS
```

Route 53 health checks monitor the production endpoint and support controlled traffic redirection during regional failure.

The repository contains:

```text
docs/04-dns-failover/
├── dns-failover-design.md
├── health-check-config.yaml
├── route53-config.json
└── failover-timing-diagram.md
```

---

## 8. Disaster Recovery Runbooks

Twelve production-oriented disaster scenarios are documented.

| ID    | Scenario                         |
| ----- | -------------------------------- |
| RB-01 | AWS Regional Failure             |
| RB-02 | Database Corruption              |
| RB-03 | DNS Poisoning                    |
| RB-04 | Kafka Cluster Failure            |
| RB-05 | Network Partition                |
| RB-06 | KMS / Key Compromise             |
| RB-07 | DDoS Attack                      |
| RB-08 | Third-Party / NPCI / UPI Outage  |
| RB-09 | Certificate Expiry / TLS Failure |
| RB-10 | Single Availability Zone Failure |
| RB-11 | Ransomware Attack                |
| RB-12 | Cascading Microservice Failure   |

Each runbook contains:

* Detection criteria
* Severity
* Initial response
* Decision points
* AWS CLI / operational commands
* Failover or containment procedure
* Validation steps
* Rollback / failback procedure
* Communication requirements
* Evidence collection
* Post-incident actions

---

## 9. Monitoring and Alert Thresholds

Critical monitoring thresholds include:

| Metric                           | Threshold                        | Severity |
| -------------------------------- | -------------------------------- | -------- |
| Aurora Global DB Replication Lag | >500 ms for 2 checks             | P1       |
| DynamoDB Replication Lag         | >1000 ms for 3 checks            | P1       |
| Redis Global Datastore Lag       | >2000 ms for 3 checks            | P2       |
| MSK Replicator Lag               | >10,000 messages for 5 min       | P2       |
| Route 53 Health Check            | Any failure                      | P1       |
| Payment API Success Rate         | <99.5% for 2 min                 | P1       |
| Transaction P99 Latency          | >300 ms for 5 min                | P2       |
| EKS Unready Nodes                | >2 for 3 min                     | P2       |
| KMS Usage Anomaly                | >3× normal hourly volume         | P1       |
| DR Composite Health              | Any critical component unhealthy | P1       |

These thresholds provide measurable triggers for incident response and DR escalation.

---

## 10. Security Architecture

The multi-region architecture applies security controls across both regions.

Key controls include:

* AWS KMS encryption
* Multi-region key strategy where required
* TLS 1.3
* mTLS for protected service communication
* AWS WAF
* AWS Shield
* IAM least privilege
* IAM drift detection
* DNSSEC
* Restricted Route 53 access
* Network segmentation
* PCI CDE isolation
* CI/CD deployment guardrails
* Security monitoring
* Audit logging
* Incident-response procedures

Special attention is given to preventing security-control drift between Mumbai and Hyderabad.

---

## 11. Data Sovereignty and Compliance

The design keeps payment-system data processing and replicated production data within Indian AWS regions.

The repository contains compliance documentation covering:

```text
docs/07-data-sovereignty/
├── compliance-matrix.md
└── data-flow-diagrams.md
```

The mapping addresses the project requirements associated with:

* RBI payment-system requirements
* RBI data-localization requirements
* PCI DSS v4.0
* NPCI / UPI operational requirements
* Encryption and key management
* Replication controls
* Evidence and auditability

**Important:** The compliance documents are architecture-assessment mappings based on the project brief. Before production implementation, the applicable current regulatory text, contractual requirements and legal interpretation must be independently verified.

---

## 12. Cost Analysis

The project includes a planning-level DR cost model.

### Annual Planning Estimates

| DR Tier       | Estimated Annual Cost |
| ------------- | --------------------: |
| Cold Standby  |           ₹8.60 crore |
| Warm Standby  |          ₹11.20 crore |
| Hot Standby   |          ₹13.60 crore |
| Active-Active |          ₹16.00 crore |

The selected Hot Standby architecture is modeled at approximately **₹13.60 crore/year**.

The cost model includes:

* EKS / compute
* Aurora PostgreSQL
* DynamoDB
* ElastiCache
* Amazon MSK
* NAT Gateway
* Inter-region data transfer
* Route 53
* S3
* KMS
* WAF
* AWS Shield
* CloudWatch
* Prometheus / Grafana
* PagerDuty / on-call
* DR drills and operations

See:

```text
docs/06-cost-analysis/
├── cost-model.xlsx
├── cost-summary.md
└── roi-analysis.md
```

---

## 13. DR Drill Program

The DR program uses quarterly exercises and an annual full business-continuity exercise.

### Quarterly Plan

| Quarter | Drill                    |
| ------- | ------------------------ |
| Q1      | Regional Failover        |
| Q2      | Database Recovery        |
| Q3      | Application Resilience   |
| Q4      | Full Business Continuity |

Each drill evaluates:

* RTO
* RPO
* Application availability
* Database recovery
* Kafka recovery
* DNS failover
* Security controls
* Transaction reconciliation
* Monitoring and alerting
* Failback
* Evidence collection

The drill documentation is located at:

```text
docs/08-dr-drill-plan/
├── annual-drill-plan.md
├── drill-success-criteria.md
└── post-drill-template.md
```

---

## 14. Repository Structure

```text
doc-5b-multi-region-dr/
│
├── README.md
├── CHANGELOG.md
│
├── docs/
│   ├── 01-current-state/
│   ├── 02-multi-region-design/
│   ├── 03-data-replication/
│   ├── 04-dns-failover/
│   ├── 05-runbooks/
│   ├── 06-cost-analysis/
│   ├── 07-data-sovereignty/
│   └── 08-dr-drill-plan/
│
├── configs/
│   ├── terraform/
│   ├── kubernetes/
│   └── monitoring/
│
└── scripts/
    ├── failover/
    ├── health-checks/
    └── dr-drill/
```

---

## 15. Documentation Deliverables

### Current-State Architecture

```text
docs/01-current-state/
├── architecture-diagram.drawio
├── architecture-diagram.png
└── current-architecture.md
```

### Multi-Region Design

```text
docs/02-multi-region-design/
├── active-active-diagram.drawio
├── active-active-diagram.png
├── active-passive-diagram.drawio
├── active-passive-diagram.png
├── active-active-design.md
├── active-passive-design.md
└── comparison-matrix.md
```

### Data Replication

```text
docs/03-data-replication/
├── replication-strategy.md
└── sequence-diagrams.md
```

### DNS Failover

```text
docs/04-dns-failover/
├── dns-failover-design.md
├── health-check-config.yaml
├── route53-config.json
└── failover-timing-diagram.md
```

### Disaster Runbooks

```text
docs/05-runbooks/
├── RB-01-region-failure.md
├── RB-02-database-corruption.md
├── RB-03-dns-poisoning.md
├── RB-04-kafka-cluster-failure.md
├── RB-05-network-partition.md
├── RB-06-key-compromise.md
├── RB-07-ddos-attack.md
├── RB-08-third-party-npci-upi-outage.md
├── RB-09-certificate-expiry-tls-failure.md
├── RB-10-single-az-power-failure.md
├── RB-11-ransomware-attack.md
└── RB-12-cascading-microservice-failure.md
```

---

## 16. Implementation Layer

The repository also reserves dedicated areas for infrastructure and operational automation:

```text
configs/terraform/
configs/kubernetes/
configs/monitoring/

scripts/failover/
scripts/health-checks/
scripts/dr-drill/
```

These directories are intended for infrastructure-as-code, Kubernetes configuration, monitoring definitions and DR automation.

---

## 17. Validation Checklist

Before declaring the architecture production-ready, validate:

* [ ] Both AWS regions are provisioned
* [ ] EKS clusters are healthy
* [ ] Aurora Global Database replication is healthy
* [ ] DynamoDB replication is validated
* [ ] Redis replication is validated
* [ ] MSK replication is validated
* [ ] S3 replication is validated
* [ ] Route 53 health checks are working
* [ ] DNS failover has been tested
* [ ] Payment API health checks are working
* [ ] Monitoring alerts are configured
* [ ] P1/P2 escalation paths are tested
* [ ] IAM permissions are validated
* [ ] KMS configuration is validated
* [ ] Security controls are consistent across regions
* [ ] Transaction reconciliation is tested
* [ ] RPO < 1 minute is demonstrated
* [ ] RTO < 5 minutes is demonstrated
* [ ] Failback is tested
* [ ] DR evidence is archived
* [ ] Runbooks are reviewed and approved

---

## 18. Key Engineering Principles

This project follows the following DR principles:

1. **Minimize single-region dependency**
2. **Automate detection wherever possible**
3. **Keep recovery procedures measurable**
4. **Protect transaction integrity during failover**
5. **Prevent split-brain database operation**
6. **Maintain consistent security controls across regions**
7. **Treat DNS as a controlled failover mechanism**
8. **Monitor replication continuously**
9. **Validate recovery through regular drills**
10. **Document every operational decision**
11. **Maintain evidence for audit and review**
12. **Design for controlled failback, not only failover**

---

## 19. Project Outcome

The resulting architecture provides PaySecure Gateway with a structured multi-region disaster recovery strategy covering:

* Current-state assessment
* Multi-region architecture
* Active-active evaluation
* Active-passive architecture
* Data replication
* DNS failover
* Health monitoring
* Disaster runbooks
* Cost modeling
* Data sovereignty
* Security controls
* Compliance mapping
* DR drills
* Recovery validation

The architecture is designed around the project's target of **99.99% availability, RPO below one minute and RTO below five minutes**.

---

## 20. Disclaimer

This repository is an **architecture and disaster-recovery engineering project** created for design, assessment and demonstration purposes.

AWS service availability, pricing, quotas and implementation details may change. Regulatory and compliance mappings in this project should be validated against the applicable current RBI, NPCI, PCI DSS and other contractual/legal requirements before production deployment.

---

## Author

**Vanshika Khandelwal**

**Role:** DevOps & Cloud Engineering Project

**Project:** PaySecure Gateway Multi-Region Disaster Recovery Architecture
