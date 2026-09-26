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

PaySecure Gateway is a mid-tier payment aggregator processing approximately **3.2 million transactions per day**, with approximately **₹500 crore daily transaction value** and around **45,000 merchants**.

The existing platform operates primarily from a single AWS Mumbai region with approximately **99.92% availability**.

This project designs a multi-region Disaster Recovery architecture targeting:

* **99.99% availability**
* **RPO < 1 minute**
* **RTO < 5 minutes**
* Indian data residency
* Controlled regional failover
* Continuous replication of critical data
* Repeatable DR validation and recovery procedures

### Proposed Architecture

* AWS Mumbai (`ap-south-1`) — Primary
* AWS Hyderabad (`ap-south-2`) — DR / Hot Standby
* Amazon EKS
* Aurora PostgreSQL Global Database
* DynamoDB Global Tables
* ElastiCache Redis Global Datastore
* Amazon MSK with cross-region replication
* Amazon S3 Cross-Region Replication
* Amazon Route 53 health checks and failover
* AWS KMS
* AWS WAF and Shield
* CloudWatch
* Prometheus / Grafana
* Terraform
* Kubernetes manifests
* DR health-check and drill scripts
* 12 operational DR runbooks

---

# 2. Business Context

## Current Environment

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

## DR Objectives

| Objective      |                 Target |
| -------------- | ---------------------: |
| Availability   |                 99.99% |
| RPO            |             < 1 minute |
| RTO            |            < 5 minutes |
| DR Region      |          AWS Hyderabad |
| Data Residency |                  India |
| Failover       | Automated / Controlled |
| DR Validation  |     Quarterly + Annual |

A 99.99% availability target corresponds to approximately **52.6 minutes of allowable downtime per year**.

---

# 3. Architecture Decision

The selected DR model is:

## Hot Standby / Active-Passive Multi-Region

### Mumbai — Primary

`ap-south-1` handles normal production traffic and acts as the primary processing region.

### Hyderabad — DR / Hot Standby

`ap-south-2` maintains synchronized infrastructure and replicated data and is prepared to accept production traffic during a declared disaster.

## Failover Flow

```text
                    Internet / Merchants
                            |
                            v
                     Amazon Route 53
                      Health Checks
                            |
                +-----------+-----------+
                |                       |
                v                       v
          Mumbai Region           Hyderabad Region
          ap-south-1              ap-south-2
          PRIMARY                 DR / HOT STANDBY
                |                       |
                v                       v
             AWS EKS                 AWS EKS
                |                       |
                +-----------+-----------+
                            |
                    Data Replication
                            |
        +-------------------+-------------------+
        |                   |                   |
        v                   v                   v
  Aurora Global       DynamoDB Global      Redis Global
     Database              Tables            Datastore
        |
        v
      Amazon MSK
 Cross-Region Replication
```

---

# 4. Core AWS Services

| Layer          | Technology             | DR Strategy                        |
| -------------- | ---------------------- | ---------------------------------- |
| DNS            | Route 53               | Health checks + failover           |
| Compute        | Amazon EKS             | Hot standby                        |
| Relational DB  | Aurora PostgreSQL      | Cross-region replication           |
| NoSQL          | DynamoDB Global Tables | Multi-region replication           |
| Cache          | ElastiCache Redis      | Cross-region replication           |
| Messaging      | Amazon MSK             | Cross-region replication           |
| Object Storage | Amazon S3              | Cross-Region Replication           |
| Encryption     | AWS KMS                | Regional / replicated key strategy |
| Edge Security  | WAF / Shield           | Multi-region controls              |
| Monitoring     | CloudWatch             | Infrastructure monitoring          |
| Metrics        | Prometheus / Grafana   | Application observability          |
| Infrastructure | Terraform              | Infrastructure consistency         |
| Orchestration  | Kubernetes             | Regional application deployment    |

---

# 5. Recovery Objectives

## RPO — Recovery Point Objective

**Target: < 1 minute**

Critical payment data and supporting state are designed for continuous or near-continuous replication so that regional failure minimizes potential data loss.

## RTO — Recovery Time Objective

**Target: < 5 minutes**

The recovery workflow is designed around:

1. Failure detection
2. Incident declaration
3. DR readiness validation
4. Database / application promotion
5. DNS traffic redirection
6. Application health validation
7. Transaction verification

## Availability

**Target: 99.99%**

The multi-region design reduces dependency on a single AWS region and provides a controlled recovery path for regional failures.

---

# 6. Data Replication Strategy

## Aurora PostgreSQL

Aurora PostgreSQL Global Database is used as the relational database replication strategy.

Controls include:

* Continuous cross-region replication
* Replication-lag monitoring
* Controlled writer promotion
* Point-in-time recovery
* Post-failover validation
* Split-brain prevention
* Transaction reconciliation

## DynamoDB

DynamoDB Global Tables provide multi-region replication.

Monitoring includes:

* Replication latency
* Write conflicts
* Failed replication events
* Region health
* Data consistency validation

## ElastiCache Redis

Redis Global Datastore is used for cross-region cache replication.

Redis is treated as a cache rather than the system of record. Recovery must therefore preserve payment transaction correctness even if cache state requires reconstruction.

## Amazon MSK

Kafka workloads use cross-region replication.

Important controls:

* Consumer lag monitoring
* Replication lag monitoring
* Topic validation
* Consumer-group validation
* Offset reconciliation
* Duplicate-event protection

## Amazon S3

S3 Cross-Region Replication is used for required objects and operational artifacts.

---

# 7. DNS Failover

Amazon Route 53 is the DNS failover layer.

## Normal State

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

## Disaster State

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

The repository contains:

```text
docs/04-dns-failover/
├── dns-failover-design.md
├── health-check-config.yaml
├── route53-config.json
└── failover-timing-diagram.md
```

---

# 8. Disaster Recovery Runbooks

The project contains 12 production-oriented DR scenarios.

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

Each runbook includes:

* Detection criteria
* Severity
* Initial response
* Decision points
* Operational commands
* Containment / failover procedure
* Validation steps
* Rollback / failback
* Communication requirements
* Evidence collection
* Post-incident actions

---

# 9. Monitoring and Alerting

The project includes:

```text
configs/monitoring/
├── cloudwatch-alarms.yaml
├── prometheus-rules.yaml
└── grafana-dashboard.json
```

## Critical Thresholds

| Metric                   | Threshold        | Severity |
| ------------------------ | ---------------- | -------- |
| Aurora Replication Lag   | >500 ms          | P1       |
| DynamoDB Replication Lag | >1000 ms         | P1       |
| Redis Replication Lag    | >2000 ms         | P2       |
| MSK Replication Lag      | >10,000 messages | P2       |
| Route 53 Health          | Failure          | P1       |
| Payment Success Rate     | <99.5%           | P1       |
| Transaction P99 Latency  | >300 ms          | P2       |
| EKS Unready Nodes        | >2               | P2       |
| KMS Usage Anomaly        | >3× normal       | P1       |
| DR Composite Health      | Critical failure | P1       |

Terraform CloudWatch alarm definitions are also included under:

```text
configs/terraform/monitoring/
```

---

# 10. Security Architecture

Security controls are designed for both regions.

### Encryption

* AWS KMS
* Encryption at rest
* TLS
* Regional key strategy
* KMS key rotation

### Network Security

* VPC segmentation
* Private subnets
* Database security groups
* Kafka security groups
* Application security groups
* Restricted database access

### Application / Edge Security

* AWS WAF
* AWS Shield
* IAM least privilege
* mTLS for protected communication
* DNSSEC design
* Restricted Route 53 access

### Payment Security

* PCI CDE segmentation
* Audit logging
* Security monitoring
* Incident-response procedures
* Security-control consistency across regions

---

# 11. Terraform Infrastructure

The project includes Infrastructure as Code under:

```text
configs/terraform/
```

### Implemented areas

```text
configs/terraform/
├── modules/
│   ├── networking/
│   ├── eks/
│   ├── aurora/
│   ├── dynamodb/
│   ├── redis/
│   ├── msk/
│   └── route53/
│
├── security/
│   ├── kms.tf
│   └── security-groups.tf
│
├── replication/
│   ├── aurora-global.tf
│   ├── redis-global.tf
│   ├── msk-replicator.tf
│   └── s3-crr.tf
│
├── iam/
│   └── replication-roles.tf
│
└── monitoring/
    └── cloudwatch.tf
```

Terraform validation has been performed successfully during development.

The configuration is designed with feature flags so infrastructure components can be selectively enabled.

**Important:** This repository does not claim that production AWS infrastructure has been deployed. Terraform `apply` should only be performed after environment-specific credentials, networking, quotas, service availability, secrets and security approvals have been verified.

---

# 12. Kubernetes Deployment

Kubernetes configurations are maintained under:

```text
configs/kubernetes/
├── namespace.yaml
├── configmap.yaml
├── deployment-primary.yaml
├── deployment-dr.yaml
├── service.yaml
├── hpa.yaml
├── pdb.yaml
└── ingress.yaml
```

The manifests provide:

* Primary and DR deployments
* Health checks
* Resource requests and limits
* Horizontal Pod Autoscaling
* Pod Disruption Budget
* ALB ingress
* Security contexts
* Regional configuration

---

# 13. DR Automation

Operational scripts are provided under:

```text
scripts/
├── failover/
├── health-checks/
└── dr-drill/
```

The automation includes:

* DR health validation
* RPO/RTO checks
* Failover preparation
* DR readiness validation
* DR drill execution

Scripts are designed to support controlled operations and avoid automatically performing destructive fault injection.

---

# 14. Data Sovereignty and Compliance

The architecture keeps production payment processing and replicated production data within Indian AWS regions.

Compliance documentation:

```text
docs/07-data-sovereignty/
├── compliance-matrix.md
└── data-flow-diagrams.md
```

The assessment covers:

* RBI payment-system requirements
* RBI data-localization considerations
* PCI DSS v4.0
* NPCI / UPI operational requirements
* Encryption and key management
* Replication controls
* Evidence and auditability

**Compliance disclaimer:** These documents are architecture-assessment mappings for the project. Current regulatory text, contractual requirements and legal interpretation must be independently verified before production deployment.

---

# 15. Cost Analysis

The repository includes a planning-level cost model.

| DR Tier       | Estimated Annual Cost |
| ------------- | --------------------: |
| Cold Standby  |           ₹8.60 crore |
| Warm Standby  |          ₹11.20 crore |
| Hot Standby   |          ₹13.60 crore |
| Active-Active |          ₹16.00 crore |

The selected Hot Standby architecture is modeled at approximately:

**₹13.60 crore/year**

The model considers:

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
* DR operations and drills

Files:

```text
docs/06-cost-analysis/
├── cost-model.xlsx
├── cost-summary.md
└── roi-analysis.md
```

These are planning estimates rather than live AWS billing figures.

---

# 16. DR Drill Program

The DR program uses quarterly exercises and an annual business-continuity exercise.

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
* Monitoring
* Failback
* Evidence collection

Documentation:

```text
docs/08-dr-drill-plan/
├── annual-drill-plan.md
├── drill-success-criteria.md
└── post-drill-template.md
```

---

# 17. Repository Structure

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

# 18. Documentation Deliverables

## Current-State Architecture

```text
docs/01-current-state/
├── architecture-diagram.drawio
├── architecture-diagram.png
└── current-architecture.md
```

## Multi-Region Design

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

## Data Replication

```text
docs/03-data-replication/
├── replication-strategy.md
└── sequence-diagrams.md
```

## DNS Failover

```text
docs/04-dns-failover/
├── dns-failover-design.md
├── health-check-config.yaml
├── route53-config.json
└── failover-timing-diagram.md
```

## DR Runbooks

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

# 19. Validation Checklist

Before production deployment, validate:

* [ ] Both AWS regions are provisioned
* [ ] EKS clusters are healthy
* [ ] Aurora replication is healthy
* [ ] DynamoDB replication is validated
* [ ] Redis replication is validated
* [ ] MSK replication is validated
* [ ] S3 replication is validated
* [ ] Route 53 health checks are working
* [ ] DNS failover is tested
* [ ] Payment API health checks are working
* [ ] Monitoring alerts are configured
* [ ] P1/P2 escalation paths are tested
* [ ] IAM permissions are validated
* [ ] KMS configuration is validated
* [ ] Security controls are consistent
* [ ] Transaction reconciliation is tested
* [ ] RPO < 1 minute is demonstrated
* [ ] RTO < 5 minutes is demonstrated
* [ ] Failback is tested
* [ ] DR evidence is archived
* [ ] Runbooks are reviewed and approved

---

# 20. Engineering Principles

1. Minimize single-region dependency
2. Automate failure detection where appropriate
3. Keep recovery procedures measurable
4. Protect transaction integrity during failover
5. Prevent database split-brain
6. Maintain security consistency across regions
7. Use DNS as a controlled failover mechanism
8. Monitor replication continuously
9. Validate recovery through regular drills
10. Document operational decisions
11. Maintain audit evidence
12. Design controlled failback as well as failover

---

# 21. Project Outcome

The project provides a structured multi-region Disaster Recovery design covering:

* Current-state assessment
* Multi-region architecture
* Active-active evaluation
* Active-passive architecture
* Data replication
* DNS failover
* Health monitoring
* Security controls
* Terraform infrastructure
* Kubernetes configuration
* DR automation
* 12 disaster-recovery runbooks
* Cost modeling
* Data sovereignty
* Compliance mapping
* DR drill planning
* Recovery validation

The architecture is designed around the project targets of:

**99.99% availability**
**RPO < 1 minute**
**RTO < 5 minutes**

---

# 22. Project Status

| Area                       | Status     |
| -------------------------- | ---------- |
| Current-State Architecture | ✅ Complete |
| Multi-Region Design        | ✅ Complete |
| Active-Passive Design      | ✅ Complete |
| Active-Active Evaluation   | ✅ Complete |
| Data Replication Design    | ✅ Complete |
| DNS Failover Design        | ✅ Complete |
| 12 DR Runbooks             | ✅ Complete |
| Cost Model                 | ✅ Complete |
| Compliance Mapping         | ✅ Complete |
| DR Drill Plan              | ✅ Complete |
| Terraform Infrastructure   | ✅ Complete |
| Kubernetes Configuration   | ✅ Complete |
| Monitoring Configuration   | ✅ Complete |
| DR Automation Scripts      | ✅ Complete |
| Git Repository             | ✅ Updated  |

---

# 23. Disclaimer

This repository is an **architecture, Infrastructure-as-Code and Disaster Recovery engineering project** created for design, assessment and demonstration purposes.

AWS service availability, pricing, quotas and implementation details may change. Regulatory and compliance mappings should be validated against the applicable current RBI, NPCI, PCI DSS and contractual/legal requirements before production deployment.

No production AWS deployment should be performed without appropriate credentials, security review, cost approval, service-availability validation and operational authorization.

---

# Author

**Vanshika Khandelwal**

**Role:** DevOps & Cloud Engineering Project

**Project:** PaySecure Gateway Multi-Region Disaster Recovery Architecture
