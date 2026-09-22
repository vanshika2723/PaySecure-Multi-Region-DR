# PaySecure Gateway — DR Cost Summary

## 1. Overview

PaySecure Gateway currently operates its production infrastructure in a single AWS Mumbai region (`ap-south-1`). The project brief specifies an annual infrastructure spend of approximately **₹8 crore**, with a current uptime of **99.92%** and a target uptime of **99.99%**.

The disaster recovery cost analysis compares four DR tiers:

1. Cold Standby
2. Warm Standby
3. Hot Standby
4. Active-Active

The purpose of this comparison is to understand the relationship between additional infrastructure investment, recovery objectives, and operational resilience.

> **Note:** The service-level amounts in `cost-model.xlsx` are planning estimates based on the project brief's ₹8 crore annual baseline. They should be validated against current AWS pricing before production procurement.

---

## 2. Current Infrastructure Baseline

The current annual infrastructure spend is approximately:

**₹8 crore/year**

The cost model distributes this baseline across major infrastructure and operational categories:

| Category   | Included Services                            |
| ---------- | -------------------------------------------- |
| Compute    | Amazon EKS / compute capacity                |
| Database   | Aurora PostgreSQL                            |
| NoSQL      | DynamoDB                                     |
| Cache      | ElastiCache Redis                            |
| Messaging  | Amazon MSK / Kafka                           |
| Networking | NAT Gateway, inter-region transfer, Route 53 |
| Storage    | Amazon S3                                    |
| Security   | KMS, WAF, AWS Shield                         |
| Monitoring | CloudWatch, Prometheus/Grafana               |
| Operations | PagerDuty/on-call, DR drills and training    |

This provides a consistent baseline for comparing the DR tiers.

---

## 3. DR Tier Comparison

### Cold Standby

Cold Standby keeps infrastructure defined through Infrastructure as Code but does not maintain a fully provisioned DR environment.

**Typical RTO:** 4–24 hours
**Typical RPO:** Hours to days
**Planning multiplier:** 1.075x

Advantages:

* Lowest additional infrastructure requirement
* Suitable for lower-criticality workloads
* Infrastructure can be recreated through Terraform
* Lower continuous operating cost

Limitations:

* Recovery requires infrastructure provisioning
* Database and application recovery takes significant time
* Does not meet the project's `<5 minute` RTO objective
* Backup-based recovery can result in higher RPO

For PaySecure's payment-processing workload, Cold Standby is therefore useful primarily as a cost/reference tier rather than the target production DR model.

---

## 4. Warm Standby

Warm Standby maintains core infrastructure in the secondary region at reduced capacity.

**Typical RTO:** 15–60 minutes
**Typical RPO:** Minutes
**Planning multiplier:** 1.40x

The DR region maintains:

* Replicating databases
* Minimal compute capacity
* Networking
* Monitoring
* Security controls
* Required application dependencies

During a regional failure, application capacity is increased and traffic is redirected to the DR region.

Warm Standby provides a substantial resilience improvement over Cold Standby, but its typical RTO remains above the project's `<5 minute` requirement.

---

## 5. Hot Standby

Hot Standby maintains the complete DR infrastructure in a running state.

**Typical RTO:** 1–5 minutes
**Typical RPO:** Seconds to approximately 1 minute
**Planning multiplier:** 1.70x

The architecture maintains:

* EKS infrastructure in both regions
* Aurora Global Database replication
* DynamoDB Global Tables
* ElastiCache Global Datastore
* MSK replication
* Route 53 health checks
* Security controls
* Monitoring and alerting

When the Mumbai region becomes unavailable, traffic can be redirected to Hyderabad while the DR application stack is already running.

This model provides the operational characteristics required by the project target of:

* **RTO < 5 minutes**
* **RPO < 1 minute**
* **99.99% target availability**

---

## 6. Active-Active

Active-Active allows both regions to serve production traffic simultaneously.

**Typical RTO:** Near-zero
**Typical RPO:** Near-zero to seconds
**Planning multiplier:** 2.00x

Benefits include:

* Both regions continuously serve traffic
* Higher utilization of DR infrastructure
* Very low regional failover time
* Reduced dependency on cold recovery activities

However, the design introduces additional distributed-systems complexity.

Important considerations include:

* Transaction ordering
* Idempotency
* Duplicate transaction prevention
* Cross-region consistency
* Split-brain protection
* Conflict resolution
* Settlement reconciliation
* Increased operational complexity

For a payment platform, these concerns must be carefully controlled before enabling simultaneous production writes.

---

## 7. Cost Comparison

The cost model uses the project's current **₹8 crore/year** infrastructure baseline.

| DR Tier       | Planning Multiplier | Approx. Annual Cost | Typical RTO | Typical RPO       |
| ------------- | ------------------: | ------------------: | ----------- | ----------------- |
| Cold Standby  |              1.075x |         ₹8.60 crore | 4–24 hours  | Hours to days     |
| Warm Standby  |               1.40x |        ₹11.20 crore | 15–60 min   | Minutes           |
| Hot Standby   |               1.70x |        ₹13.60 crore | 1–5 min     | Seconds–1 min     |
| Active-Active |               2.00x |        ₹16.00 crore | Near-zero   | Near-zero–seconds |

These figures are planning estimates generated from the project's baseline and specified tier multipliers. They are not AWS quotations.

---

## 8. Incremental Investment

Compared with the current ₹8 crore annual baseline:

### Cold Standby

Additional planning cost:

**₹0.60 crore/year**

### Warm Standby

Additional planning cost:

**₹3.20 crore/year**

### Hot Standby

Additional planning cost:

**₹5.60 crore/year**

### Active-Active

Additional planning cost:

**₹8.00 crore/year**

The incremental investment primarily represents additional regional infrastructure, replication, networking, monitoring, security, and operational requirements.

---

## 9. Cost Drivers

The largest cost drivers are expected to be:

### Compute

Running EKS/application capacity in the DR region increases compute expenditure. Hot and Active-Active tiers require significantly more continuously available capacity than Cold or Warm Standby.

### Database

Aurora PostgreSQL replication and secondary-region database capacity contribute substantially to DR expenditure.

### DynamoDB

Global Tables introduce multi-region replication requirements and corresponding read/write and replication costs.

### Cache

ElastiCache Global Datastore requires additional regional cache infrastructure and replication.

### Kafka

MSK infrastructure and cross-region replication create both infrastructure and data-transfer costs.

### Networking

Inter-region data transfer and NAT Gateway usage become important cost components in a multi-region architecture.

### Security

KMS, WAF, Shield, certificates, and security monitoring must be maintained consistently across both regions.

### Monitoring and Operations

Multi-region infrastructure increases monitoring volume, alerting requirements, on-call complexity, and DR drill requirements.

---

## 10. Recommended Planning Direction

The project requires an RTO below five minutes and an RPO below one minute.

Cold Standby and Warm Standby have typical recovery characteristics that are above the target RTO.

The cost model therefore focuses detailed engineering planning on **Hot Standby** and **Active-Active** configurations.

The Hot Standby design maintains a fully provisioned DR environment while avoiding some of the transaction-consistency complexity associated with simultaneously processing production traffic in both regions.

The Active-Active model remains an important architectural option and provides near-zero recovery characteristics, but requires stronger controls for distributed transaction processing, idempotency, conflict resolution, and settlement consistency.

---

## 11. Cost Optimization Opportunities

Potential optimization areas include:

* Right-size DR compute capacity
* Use autoscaling for non-critical workloads
* Use Savings Plans or Reserved Instances where utilization is predictable
* Reduce unnecessary cross-region data transfer
* Apply lifecycle policies to S3 data
* Separate critical and non-critical monitoring
* Use lower-cost capacity for non-production DR validation
* Automate DR drills and verification
* Review NAT Gateway architecture
* Continuously monitor unused resources

Any optimization must preserve the project's RTO, RPO, security, and compliance requirements.

---

## 12. Conclusion

The cost analysis demonstrates the fundamental trade-off between DR investment and recovery capability.

Cold Standby minimizes additional infrastructure expenditure but has recovery characteristics measured in hours.

Warm Standby improves recovery capability but remains above the project's five-minute RTO target.

Hot Standby provides a continuously available secondary environment capable of supporting a regional failover within the project's target range.

Active-Active provides the lowest theoretical recovery time but introduces substantially greater distributed-system and operational complexity.

The final architecture should therefore be evaluated not only on infrastructure cost but also on transaction integrity, operational complexity, regulatory requirements, RTO/RPO compliance, and the financial impact of payment-service downtime.
