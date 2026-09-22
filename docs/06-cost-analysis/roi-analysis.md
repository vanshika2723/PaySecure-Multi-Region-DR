# PaySecure Gateway — Disaster Recovery ROI Analysis

## 1. Purpose

This document evaluates the financial justification for investing in multi-region Disaster Recovery (DR) for PaySecure Gateway.

The analysis compares the additional annual DR investment with the potential financial exposure created by payment-service downtime, merchant compensation, regulatory exposure, and operational recovery effort.

The calculations use the figures defined in the project brief and the planning costs from `cost-model.xlsx`.

> **Important:** Regulatory amounts and financial exposure figures in this document are project-brief assumptions for the assessment. They should not be interpreted as a legal determination or an actual guaranteed regulatory penalty.

---

## 2. Business Baseline

PaySecure Gateway processes approximately:

* **3.2 million transactions/day**
* **₹500 crore transaction value/day**
* **1,200 peak TPS**
* **45,000 active merchants**

Current infrastructure operates from AWS Mumbai (`ap-south-1`).

The project brief specifies:

* Current uptime: **99.92%**
* Target uptime: **99.99%**
* Current annual infrastructure spend: **₹8 crore**
* Target RTO: **< 5 minutes**
* Target RPO: **< 1 minute**

---

## 3. Direct Downtime Exposure

The project brief provides an estimated direct revenue exposure of approximately:

**₹37.5 lakh per hour of downtime**

Therefore:

**Per-minute exposure**

```text
₹37,50,000 ÷ 60
= ₹62,500/minute
```

Illustrative exposure:

|   Downtime | Direct Revenue Exposure |
| ---------: | ----------------------: |
|   1 minute |                 ₹62,500 |
|  5 minutes |             ₹3.125 lakh |
| 10 minutes |              ₹6.25 lakh |
| 30 minutes |             ₹18.75 lakh |
|     1 hour |             ₹37.50 lakh |
|    2 hours |                ₹75 lakh |
|    4 hours |             ₹1.50 crore |
|    7 hours |            ₹2.625 crore |

These values represent direct transaction/revenue exposure only and do not include merchant compensation, regulatory impact, recovery labor, or reputational effects.

---

## 4. Merchant Compensation Exposure

A major payment outage can also result in merchant-facing SLA credits or compensation.

The actual compensation amount depends on:

* Merchant contract
* Duration of outage
* Number of affected merchants
* Transaction impact
* SLA terms
* Commercial escalation

Because the project brief does not specify a fixed merchant compensation amount, this analysis does **not** invent a single compensation value.

Instead, merchant compensation should be included as a variable in the financial model:

```text
Total Incident Cost =
Direct Downtime Exposure
+ Merchant Compensation
+ Regulatory Exposure
+ Recovery Cost
+ Other Business Impact
```

This approach allows the financial model to be updated when PaySecure's actual merchant SLA schedule is available.

---

## 5. Regulatory Exposure

The project brief identifies regulatory exposure as a significant consequence of major payment-system incidents.

For ROI modelling, the brief provides an illustrative range of:

**₹50 lakh – ₹2 crore for a P1 incident**

The document also identifies regulatory and compliance consequences involving:

* RBI payment-system requirements
* Data-localisation obligations
* PCI DSS incident-response requirements
* NPCI/UPI operational requirements

The regulatory figures should therefore be treated as **assessment assumptions**, rather than guaranteed penalties.

---

## 6. Operational Recovery Cost

The project brief estimates a major recovery effort of:

**500+ engineer-hours**

with an assumed engineering cost of:

**₹3,000/hour**

Using 500 hours for the baseline calculation:

```text
500 × ₹3,000
= ₹15,00,000
```

Therefore, the illustrative minimum recovery labor exposure is:

**₹15 lakh**

Actual costs can be higher when recovery requires:

* Extended on-call coverage
* Incident management
* Database specialists
* Security teams
* Network engineers
* Vendor support
* Management escalation
* Post-incident remediation

---

## 7. Illustrative Incident Cost

For a one-hour outage, using the project-brief figures:

```text
Direct downtime exposure       ₹37.50 lakh
Recovery labor                 ₹15.00 lakh
------------------------------------------------
Subtotal                       ₹52.50 lakh
```

This subtotal intentionally excludes:

* Merchant compensation
* Regulatory exposure
* Reputational damage
* Merchant churn
* Customer support costs
* Additional vendor costs

If an illustrative low regulatory exposure of ₹50 lakh is added:

```text
₹52.50 lakh + ₹50 lakh
= ₹1.025 crore
```

Using the upper illustrative regulatory exposure of ₹2 crore:

```text
₹52.50 lakh + ₹2 crore
= ₹2.525 crore
```

These are scenario calculations rather than predictions of an actual incident outcome.

---

## 8. DR Investment Comparison

The planning model uses the project's ₹8 crore current annual infrastructure baseline.

| DR Tier          | Planning Annual Cost | Incremental Annual Investment |
| ---------------- | -------------------: | ----------------------------: |
| Current baseline |          ₹8.00 crore |                             — |
| Cold Standby     |          ₹8.60 crore |                   ₹0.60 crore |
| Warm Standby     |         ₹11.20 crore |                   ₹3.20 crore |
| Hot Standby      |         ₹13.60 crore |                   ₹5.60 crore |
| Active-Active    |         ₹16.00 crore |                   ₹8.00 crore |

These numbers come from the planning multipliers in `cost-model.xlsx`.

They are not AWS price quotations.

---

## 9. Simple Avoided-Loss View

A simple financial comparison can be expressed as:

```text
DR Value =
Potential Incident Loss Avoided
− Incremental DR Investment
```

The actual avoided loss depends on:

* Frequency of regional failures
* Duration of incidents
* Effectiveness of automated failover
* RPO achieved
* Transaction recovery success
* Merchant compensation
* Regulatory consequences

Therefore, the model should be treated as a decision-support calculation rather than a guaranteed return.

---

## 10. Break-Even Illustration

Using only the project's direct downtime exposure of ₹37.5 lakh/hour:

### Warm Standby

Incremental annual investment:

**₹3.20 crore**

Break-even downtime avoided:

```text
₹3.20 crore ÷ ₹37.5 lakh/hour
≈ 8.53 hours
```

### Hot Standby

Incremental annual investment:

**₹5.60 crore**

Break-even downtime avoided:

```text
₹5.60 crore ÷ ₹37.5 lakh/hour
≈ 14.93 hours
```

### Active-Active

Incremental annual investment:

**₹8.00 crore**

Break-even downtime avoided:

```text
₹8.00 crore ÷ ₹37.5 lakh/hour
≈ 21.33 hours
```

This calculation considers direct downtime exposure only.

It does **not** assign a monetary value to improved compliance, merchant retention, reduced operational risk, or lower data-loss exposure.

---

## 11. Why RTO/RPO Matter Financially

A DR architecture should not be evaluated only by infrastructure cost.

For a payment gateway, a five-minute outage and a two-hour outage have substantially different consequences.

Similarly, losing several seconds or minutes of transaction data can create:

* Payment reconciliation problems
* Duplicate transaction risk
* Settlement discrepancies
* Merchant disputes
* Customer complaints
* Manual recovery effort

The project's target of:

**RTO < 5 minutes**

and

**RPO < 1 minute**

therefore provides an operational constraint for the cost analysis.

A cheaper architecture that cannot satisfy these requirements may not satisfy the project's business objective.

---

## 12. Cost Optimization

Potential DR cost-optimization measures include:

### Compute

* Right-size EKS worker nodes
* Use autoscaling
* Use Savings Plans where workloads are predictable
* Keep non-critical DR workloads at reduced capacity where RTO permits

### Database

* Monitor Aurora utilization
* Optimize storage and I/O
* Review backup retention
* Avoid unnecessary replicas

### Networking

* Minimize unnecessary cross-region traffic
* Review NAT Gateway architecture
* Monitor inter-region data transfer

### Storage

* Apply S3 lifecycle policies
* Use appropriate storage classes
* Delete obsolete backups according to retention policy

### Monitoring

* Review high-volume CloudWatch logs
* Apply appropriate log retention
* Avoid excessive metric cardinality

### Operations

* Automate DR verification
* Automate health checks
* Use repeatable Terraform deployments
* Conduct scheduled drills instead of manual ad-hoc recovery

Cost optimization must not weaken PCI DSS controls, data sovereignty, RTO/RPO objectives, or payment transaction integrity.

---

## 13. Recommended Financial Evaluation Framework

For future production planning, PaySecure should maintain the following formula:

```text
Annual DR Value
=
Expected Annual Loss Without DR
− Expected Annual Loss With DR
```

Where:

```text
Expected Annual Loss
=
Failure Frequency
×
Average Incident Cost
```

Average incident cost should include:

```text
Direct Transaction Impact
+
Merchant Compensation
+
Regulatory/Compliance Exposure
+
Recovery Labor
+
Vendor Costs
+
Customer Support
+
Reputational / Merchant Churn Impact
```

This provides a more complete Total Cost of Ownership and risk-based ROI model.

---

## 14. Conclusion

The project data demonstrates that DR investment should be evaluated against both infrastructure expenditure and the financial consequences of payment-service disruption.

The current annual infrastructure baseline is approximately **₹8 crore**.

The planning model estimates:

* Cold Standby: **₹8.60 crore/year**
* Warm Standby: **₹11.20 crore/year**
* Hot Standby: **₹13.60 crore/year**
* Active-Active: **₹16.00 crore/year**

The project target requires **99.99% availability, RTO below five minutes, and RPO below one minute**.

The final DR decision should therefore balance:

1. Annual infrastructure cost
2. RTO/RPO capability
3. Transaction consistency
4. Data-loss exposure
5. Merchant compensation
6. Regulatory exposure
7. Operational complexity
8. Engineering capacity
9. Security and compliance requirements
10. Long-term resilience requirements

The cost model provides the financial baseline for the next stages of the project, including compliance mapping and the annual DR drill programme.
