# RB-08 — Third-Party NPCI/UPI Outage Recovery Runbook

## 1. Runbook Metadata

| Field                   | Details                                                                                 |
| ----------------------- | --------------------------------------------------------------------------------------- |
| Runbook ID              | RB-08                                                                                   |
| Scenario                | Third-Party NPCI/UPI Outage                                                             |
| Severity                | High / Critical                                                                         |
| Primary Components      | UPI/NPCI connectivity, Payment API, transaction queue, Kafka, settlement/reconciliation |
| Primary Region          | `ap-south-1` — Mumbai                                                                   |
| DR Region               | `ap-south-2` — Hyderabad                                                                |
| RTO Target              | < 5 minutes                                                                             |
| RPO Target              | < 1 minute                                                                              |
| Primary Risk            | UPI transaction failures, delayed responses and settlement/reconciliation backlog       |
| Primary Owner           | Payments / SRE                                                                          |
| Supporting Teams        | Backend, Platform, Network, Security, Merchant Support, Compliance                      |
| Regulatory Notification | Assess based on outage impact and applicable requirements                               |

---

# 2. Scenario Description

This runbook is activated when PaySecure detects a possible outage or severe degradation affecting the external NPCI/UPI payment ecosystem.

The first objective is to determine whether the problem originates from:

1. NPCI/UPI or another external dependency.
2. PaySecure's own infrastructure.
3. Connectivity between PaySecure and the external dependency.
4. A combination of external and internal failures.

The system must avoid repeatedly retrying failed transactions in a way that could create duplicate transactions or unnecessary load.

The outage response therefore focuses on:

* Failure classification
* Safe transaction handling
* Retry queueing
* Idempotency
* Merchant communication
* Payment-status reconciliation
* Restoration monitoring
* Settlement verification

---

# 3. Trigger Conditions

Activate RB-08 when one or more of the following occur:

* UPI transaction success rate drops unexpectedly.
* Large numbers of UPI transactions receive timeout responses.
* NPCI/UPI connectivity becomes unavailable.
* Multiple merchants report UPI transaction failures.
* Payment API remains healthy but UPI transactions fail.
* External dependency latency increases significantly.
* Transaction status responses become unavailable.
* UPI acknowledgements are delayed.
* Settlement/reconciliation data becomes delayed.
* An external NPCI/UPI outage is confirmed.

---

# 4. Roles and Responsibilities

| Role                     | Responsibility                         |
| ------------------------ | -------------------------------------- |
| Incident Commander       | Coordinates complete incident response |
| Payments Lead            | Owns payment transaction handling      |
| SRE                      | Infrastructure and monitoring          |
| Backend Engineer         | API and transaction workflow           |
| Network Engineer         | Connectivity investigation             |
| Platform Engineer        | Kafka/queue infrastructure             |
| Merchant Support         | Merchant communication                 |
| Compliance/Legal         | Regulatory assessment                  |
| Finance/Settlement Team  | Reconciliation and settlement          |
| Business Continuity Lead | RTO/RPO validation                     |

---

# 5. Initial Response

## Step 1 — Declare Incident

**Target: 0–1 minute**

Create a High/Critical incident.

Record:

```text
Incident ID
Detection time
Affected payment rail
Current success rate
Normal success rate
Current timeout rate
Affected merchants
External dependency status
Internal service status
```

Example:

```text
HIGH: Suspected NPCI/UPI Dependency Outage
```

---

## Step 2 — Assign Incident Commander

Immediately assign:

```text
Incident Commander
Payments Lead
SRE
Backend
Network
Settlement
Merchant Support
Compliance
```

Create a shared incident timeline.

---

## Step 3 — Confirm Payment Impact

Review:

```text
UPI success rate
UPI failure rate
UPI timeout rate
Payment API latency
Transaction volume
Pending transactions
```

Compare current values against the normal baseline.

---

# 6. External vs Internal Failure Classification

## Step 4 — Check Internal API Health

Verify:

```text
Payment API
Authentication
Database
Redis
Kafka
Application pods
Network connectivity
```

If internal systems are failing, activate the appropriate internal incident runbook instead of assuming NPCI is unavailable.

---

## Step 5 — Check Other Payment Methods

Compare UPI performance with other supported payment methods.

Example:

```text
UPI       → degraded
Cards     → normal
NetBanking → normal
Wallet    → normal
```

If only UPI is affected while other payment methods remain healthy, suspicion of an external UPI dependency issue increases.

This is an investigation indicator, not by itself proof of NPCI failure.

---

## Step 6 — Check External Dependency Status

Check approved NPCI/UPI operational communication channels and available status information.

Record:

```text
Status
Timestamp
Reported issue
Expected restoration
Reference/case number
```

Do not treat an unverified third-party report as confirmation.

---

## Step 7 — Check Connectivity

Test the approved PaySecure-to-UPI connectivity path.

Validate:

```text
DNS resolution
Network route
TLS connectivity
Connection establishment
Request timeout
Response timeout
```

Record timestamps for failed and successful attempts.

---

# 7. Failure Classification Decision

## Step 8 — Classify Incident

### Branch A — Internal Failure

Conditions:

```text
Internal payment APIs unhealthy
OR
database/Kafka unavailable
OR
PaySecure network path failing
```

Action:

```text
Activate relevant internal recovery runbook.
```

---

### Branch B — External UPI/NPCI Failure

Conditions:

```text
Internal services healthy
AND
other payment methods healthy
AND
UPI transactions failing
AND
external dependency issue is confirmed or strongly evidenced
```

Action:

```text
Continue with RB-08.
```

---

### Branch C — Connectivity-Specific Failure

Conditions:

```text
PaySecure infrastructure healthy
BUT
connectivity to external dependency fails
```

Action:

```text
Escalate to Network team and external provider.
```

---

# 8. Protect Transaction Integrity

## Step 9 — Stop Unsafe Blind Retries

Do not continuously retry failed payment requests without checking transaction state.

The system must avoid:

```text
Duplicate payment
Duplicate authorization
Duplicate transaction creation
Repeated external requests
```

---

## Step 10 — Check Idempotency

Verify that every retryable transaction contains the appropriate idempotency identifier.

Example:

```text
merchant_id
+
order_id
+
idempotency_key
```

The same transaction must not be treated as a new payment simply because the external response timed out.

---

## Step 11 — Classify Transaction State

Each affected transaction should be classified as:

```text
SUCCESS
FAILED
PENDING/UNKNOWN
```

Special attention is required for:

```text
PENDING/UNKNOWN
```

because the external system may have processed the transaction even though PaySecure did not receive the response.

---

# 9. Transaction Queueing

## Step 12 — Queue Eligible Retryable Transactions

For transactions that are confirmed safe to retry:

```text
Payment Request
      ↓
Validation
      ↓
Idempotency Check
      ↓
Retry Queue
      ↓
Controlled Retry
```

Do not queue transactions that require immediate final-state reconciliation first.

---

## Step 13 — Monitor Kafka

Check relevant Kafka topics and consumer groups.

Example:

```bash
kafka-consumer-groups.sh \
  --bootstrap-server $PRIMARY_BOOTSTRAP \
  --group payment-processor \
  --describe
```

Monitor:

```text
Consumer lag
Partition availability
Producer errors
Consumer errors
Retry backlog
Dead-letter queue
```

---

## Step 14 — Prevent Queue Explosion

If the external dependency remains unavailable:

```text
Do not continuously increase retry frequency.
```

Use controlled backoff.

Conceptually:

```text
Retry 1
  ↓
Wait
  ↓
Retry 2
  ↓
Longer wait
  ↓
Retry 3
  ↓
Reconciliation / manual review
```

The exact retry policy must follow the production payment implementation.

---

# 10. Merchant Communication

## Step 15 — Identify Merchant Impact

Determine:

```text
Number of affected merchants
Transaction failure rate
Transaction timeout rate
Pending transactions
Settlement impact
Estimated duration
```

---

## Step 16 — Merchant Communication Template

```text
Subject: UPI Service Availability Update

Dear Merchant,

PaySecure is currently experiencing elevated failures/timeouts affecting UPI transactions.

Our engineering and payment operations teams are actively monitoring the issue and coordinating recovery.

Transactions with uncertain status are being handled using controlled reconciliation and idempotency protections to prevent duplicate processing.

You may experience temporary delays in UPI transaction confirmation.

Other payment methods may remain available where supported.

We will provide further updates as service status changes.

Regards,
PaySecure Gateway Operations
```

---

# 11. Alternative Payment Handling

## Step 17 — Check Alternative Payment Methods

Where supported by the merchant integration, identify whether transactions can safely use:

```text
Cards
NetBanking
Wallets
Other approved payment methods
```

Do not automatically redirect a transaction to another payment method without merchant/customer authorization and application support.

---

## Step 18 — Communicate Alternative Options

Merchant-facing applications may display:

```text
UPI temporarily unavailable
Please try again later
Use another available payment method
```

The exact customer-facing message must be approved by the Payments/Product team.

---

# 12. Monitoring During Outage

## Step 19 — Monitor Payment Metrics

Continuously monitor:

```text
UPI success rate
UPI failure rate
UPI timeout rate
Payment latency
Pending transactions
Retry queue
Kafka lag
```

---

## Step 20 — Monitor Infrastructure

Check:

```text
EKS CPU
EKS memory
ALB latency
ALB 5xx
Aurora connections
Aurora latency
Redis health
Kafka health
```

The objective is to ensure that an external outage does not cause an internal cascading failure.

---

# 13. External Dependency Recovery

## Step 21 — Detect Recovery

When UPI/NPCI service appears restored, do not immediately release the entire backlog.

First confirm:

```text
Connectivity restored
Requests receive responses
Latency is stable
Success rate improves
Error rate decreases
```

---

## Step 22 — Perform Controlled Test

Send an approved test transaction or use the production-approved validation mechanism.

Confirm:

```text
Request accepted
Response received
Transaction status correct
No duplicate transaction
Status stored correctly
```

---

## Step 23 — Gradually Resume Retry Queue

Resume queued transactions gradually.

Example sequence:

```text
Small batch
   ↓
Monitor success
   ↓
Increase batch
   ↓
Monitor
   ↓
Normal processing
```

Stop the release if failure rates increase again.

---

# 14. Transaction Reconciliation

## Step 24 — Reconcile Unknown Transactions

Identify transactions with:

```text
REQUEST_SENT
NO_RESPONSE
PENDING
TIMEOUT
UNKNOWN
```

Compare PaySecure transaction records with the available external transaction/status information.

---

## Step 25 — Resolve Final States

Every affected transaction should eventually be classified as:

```text
SUCCESS
FAILED
CANCELLED/REVERSED
PENDING
```

Unknown transactions must not be marked failed solely because an external response timed out.

---

## Step 26 — Verify Duplicate Prevention

Search for duplicate transaction attempts using:

```text
Merchant ID
Order ID
Transaction ID
Idempotency Key
External Reference
Amount
Timestamp
```

Investigate any duplicate-looking records before settlement.

---

# 15. Settlement and Reconciliation

## Step 27 — Check Settlement Queue

Review:

```text
Pending settlements
Failed settlements
Delayed settlements
Reconciliation mismatches
```

---

## Step 28 — Validate Settlement Records

Confirm that:

```text
Successful transactions
=
Expected settlement records
```

Investigate mismatches.

---

## Step 29 — Handle Settlement Delay

If settlement processing is delayed:

1. Notify Settlement team.
2. Continue reconciliation.
3. Monitor external dependency.
4. Record affected transaction volume.
5. Assess whether applicable regulatory notification is required.

---

# 16. DR Assessment

## Step 30 — Determine Whether Regional Failover Is Required

An external NPCI/UPI outage does **not automatically require regional failover**.

### Branch A — Both Regions Healthy

```text
NPCI/UPI unavailable
+
Mumbai healthy
+
Hyderabad healthy
```

Action:

```text
Keep normal regional architecture active.
Focus on dependency recovery and transaction management.
```

### Branch B — External + Primary Region Failure

```text
NPCI/UPI issue
+
Mumbai infrastructure failure
+
Hyderabad healthy
```

Action:

```text
Activate appropriate regional DR procedure.
```

### Branch C — Both Regions Affected by External Dependency

```text
UPI/NPCI unavailable
+
Mumbai healthy/unhealthy
+
Hyderabad healthy/unhealthy
```

Action:

```text
Regional failover alone will not restore the external payment rail.
Continue dependency coordination and transaction protection.
```

---

# 17. Recovery Validation

## Step 31 — Validate Application

Confirm:

```text
Payment API healthy
UPI integration healthy
Database healthy
Kafka healthy
Redis healthy
No unexpected application errors
```

---

## Step 32 — Validate Payment Success

Compare current success rate with baseline.

Confirm:

```text
UPI success rate recovered
Timeouts decreasing
Failure rate normal
Transaction latency stable
```

---

## Step 33 — Validate Queue Drain

Confirm:

```text
Retry queue decreasing
Kafka lag decreasing
Pending transactions decreasing
Dead-letter queue stable
```

---

## Step 34 — Validate Merchant Experience

Confirm:

```text
Payment confirmation
Transaction status
Webhooks
Dashboard status
Settlement information
```

---

# 18. Regulatory Assessment

## Step 35 — Compliance Review

Compliance/Legal should assess:

```text
Was there material payment-service disruption?
Was customer/payment data affected?
Was transaction integrity affected?
Was settlement materially delayed?
Were applicable reporting obligations triggered?
```

The brief specifies regulatory notification for other scenarios based on their impact; for an NPCI/UPI outage, the response should therefore include an explicit impact-based regulatory assessment rather than automatically assuming notification.

---

# 19. Internal Engineering Communication

```text
Subject: NPCI/UPI Outage Incident Update

Incident ID: <ID>
Detection Time: <timestamp>

Issue:
Suspected/confirmed NPCI/UPI dependency outage

Internal Platform Status:
<healthy/degraded>

UPI Status:
<degraded/recovered>

Current Success Rate:
<value>

Timeout Rate:
<value>

Pending Transactions:
<value>

Retry Queue:
<value>

Settlement Impact:
<none/delayed/under investigation>

Merchant Impact:
<summary>

Current Action:
<monitoring/queueing/reconciliation/recovery>

Next Update:
<timestamp>
```

---

# 20. Evidence Checklist

Preserve:

* [ ] Incident timeline
* [ ] UPI success/failure metrics
* [ ] Timeout metrics
* [ ] API metrics
* [ ] External dependency status evidence
* [ ] Network connectivity results
* [ ] Kafka consumer lag
* [ ] Retry queue metrics
* [ ] Transaction reconciliation records
* [ ] Settlement records
* [ ] Merchant communication
* [ ] Internal communication
* [ ] External provider communication/reference
* [ ] Regulatory assessment
* [ ] RPO/RTO measurements
* [ ] Recovery validation results

Do not place sensitive payment/customer information into general incident channels.

---

# 21. RPO/RTO Validation

## RTO

Record:

```text
Incident detection
        ↓
Failure classification
        ↓
Safe transaction handling
        ↓
External dependency recovery
        ↓
Controlled queue processing
        ↓
Normal payment processing
```

Compare measured recovery time with:

```text
Target RTO: < 5 minutes
```

For an external dependency outage, distinguish:

```text
PaySecure recovery time
```

from:

```text
External dependency recovery time
```

The latter may not be directly controlled by PaySecure.

---

## RPO

Validate:

```text
Transaction records
Kafka events
Payment status
Settlement records
Reconciliation records
```

Target:

```text
RPO < 1 minute
```

Any transaction-state gap must be identified and reconciled.

---

# 22. Exit Criteria

RB-08 may be closed when:

1. NPCI/UPI service is confirmed recovered or the incident has transitioned to external-provider monitoring.
2. PaySecure internal systems are healthy.
3. UPI success rate has returned toward baseline.
4. Timeout rate is stable.
5. Retry queue is under control.
6. Kafka consumer lag is normal.
7. Pending transactions are reconciled.
8. Unknown transaction states are resolved or formally tracked.
9. No duplicate payments are identified.
10. Settlement processing is validated.
11. Webhooks are functioning.
12. Merchant impact is communicated.
13. Regulatory assessment is complete.
14. Evidence has been preserved.
15. Incident Commander approves closure.

---

# 23. Decision Tree

```text
                  UPI/NPCI ALERT
                         |
                         v
                 Check PaySecure
                    internal health
                         |
              +----------+----------+
              |                     |
           Healthy                Unhealthy
              |                     |
              v                     v
       Check other rails       Internal incident
              |
              v
       Check UPI connectivity
              |
       +------+------+
       |             |
    Working        Failed
       |             |
       v             v
  Investigate    Check external
  transaction    dependency status
       |             |
       |       +-----+------+
       |       |            |
       |    Confirmed     Unknown
       |       |            |
       |       v            v
       |   RB-08 flow   Network/API
       |                    investigation
       |
       v
  Protect transaction
       integrity
       |
       v
  Queue safe retries
       |
       v
  Monitor external
  dependency recovery
       |
       v
  Controlled queue release
       |
       v
  Reconcile transactions
       |
       v
  Validate settlement
       |
       v
  Merchant validation
       |
       v
  Compliance assessment
       |
       v
  Close incident
```

---

# 24. Post-Incident Actions

## Payments

* Reconcile all affected transactions.
* Review pending/unknown states.
* Verify idempotency.
* Verify settlement completeness.
* Review retry behavior.

## Engineering

* Review timeout handling.
* Review retry/backoff strategy.
* Improve dependency health checks.
* Improve external dependency monitoring.
* Review circuit breakers.

## Operations

* Review merchant communication.
* Measure actual recovery time.
* Update incident timeline.
* Review escalation contacts.

## Business Continuity

* Evaluate whether DR architecture helped maintain service.
* Review regional failover decision.
* Update dependency-failure scenarios in DR drills.

---

# 25. Preventive Improvements

Recommended controls include:

```text
External dependency health monitoring
Circuit breakers
Controlled retry queues
Exponential backoff
Idempotency enforcement
Transaction state reconciliation
Dependency-specific alerts
Merchant status communication
Settlement reconciliation automation
Synthetic payment monitoring
```

All changes must be tested before production deployment.

---

# 26. Final Recovery Principle

An NPCI/UPI outage must be treated differently from an internal PaySecure infrastructure failure.

The key recovery sequence is:

```text
Detect
  ↓
Classify external vs internal failure
  ↓
Protect transaction integrity
  ↓
Stop unsafe retries
  ↓
Queue eligible transactions
  ↓
Monitor dependency recovery
  ↓
Controlled retry
  ↓
Reconcile unknown transactions
  ↓
Validate settlement
  ↓
Validate merchant experience
  ↓
Assess regulatory impact
  ↓
Document evidence
  ↓
Perform RCA
  ↓
Improve dependency resilience
```

**Runbook Status:** Production Payment Dependency Recovery Procedure
**Runbook ID:** RB-08
**Scenario:** Third-Party NPCI/UPI Outage
**Owner:** PaySecure Payments / SRE
**Review Frequency:** At least annually and after every significant external payment-dependency incident
