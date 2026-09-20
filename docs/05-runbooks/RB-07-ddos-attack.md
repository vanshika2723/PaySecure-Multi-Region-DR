# RB-07 — DDoS Attack Recovery Runbook

## 1. Runbook Metadata

| Field                   | Details                                                                                  |
| ----------------------- | ---------------------------------------------------------------------------------------- |
| Runbook ID              | RB-07                                                                                    |
| Scenario                | Distributed Denial-of-Service (DDoS) Attack                                              |
| Severity                | High / Critical                                                                          |
| Primary Components      | Route 53, CloudFront where deployed, ALB, AWS WAF, AWS Shield Advanced, EKS/API services |
| Primary Region          | `ap-south-1` — Mumbai                                                                    |
| DR Region               | `ap-south-2` — Hyderabad                                                                 |
| RTO Target              | < 5 minutes                                                                              |
| RPO Target              | < 1 minute                                                                               |
| Primary Risk            | Availability degradation and resource exhaustion                                         |
| Primary Owner           | Security / SRE                                                                           |
| Supporting Teams        | Network, Backend, Platform, Payments, Communications, Compliance                         |
| Regulatory Notification | Assess based on impact and applicable requirements                                       |

---

# 2. Scenario Description

This runbook is activated when PaySecure experiences a suspected or confirmed Distributed Denial-of-Service attack against public-facing payment APIs, ALB endpoints, DNS endpoints, or other internet-facing services.

A DDoS event may appear as:

* Sudden request-volume increase
* Abnormal traffic distribution
* High connection counts
* Increased ALB target errors
* API latency increase
* EKS resource exhaustion
* WAF rule matches
* Legitimate users being unable to access services

The objective is to distinguish malicious traffic from legitimate peak traffic, protect the payment platform, maintain availability for legitimate merchants and customers, and recover without unnecessarily blocking legitimate transactions.

---

# 3. Trigger Conditions

Initiate RB-07 when one or more of the following occur:

* Sudden sustained traffic spike.
* ALB request count increases abnormally.
* API latency increases sharply.
* HTTP 4xx/5xx rates increase.
* WAF blocked requests increase significantly.
* EKS CPU/memory reaches abnormal levels.
* Connection counts exceed established baseline.
* Multiple source networks generate abnormal traffic.
* Payment API availability drops.
* AWS Shield/WAF alerts indicate possible DDoS activity.

---

# 4. Roles and Responsibilities

| Role                     | Responsibility                                       |
| ------------------------ | ---------------------------------------------------- |
| Incident Commander       | Coordinates response and recovery                    |
| Security Lead            | Classifies attack and coordinates security response  |
| SRE/Platform             | Infrastructure protection and scaling                |
| Network Engineer         | Traffic engineering and network analysis             |
| Backend Engineer         | API/application validation                           |
| Payments Team            | Payment success and transaction-integrity validation |
| Communications Lead      | Merchant/internal communication                      |
| Compliance/Legal         | Regulatory impact assessment                         |
| AWS Support Contact      | Shield Advanced/AWS escalation where applicable      |
| Business Continuity Lead | RTO/RPO and continuity coordination                  |

---

# 5. Response Principles

During a DDoS event:

1. Protect legitimate payment traffic.
2. Do not block legitimate merchant/customer traffic without evidence.
3. Use layered controls.
4. Start with detection and classification.
5. Apply targeted WAF controls before broad blocking where practical.
6. Use AWS Shield capabilities and AWS support escalation where applicable.
7. Scale application capacity only after confirming traffic characteristics.
8. Protect downstream databases and Kafka from overload.
9. Preserve transaction integrity.
10. Document all emergency traffic rules.

---

# 6. Attack Classification

## Step 1 — Declare the Incident

**Target: 0–1 minute**

Create a High/Critical incident.

Record:

```text id="qv5y9n"
Incident ID
Detection time
Affected endpoint
Current request rate
Normal baseline
Current error rate
Current latency
Current WAF activity
Affected region
```

Example:

```text id="3m6f3u"
HIGH: Suspected DDoS Against PaySecure API
```

---

## Step 2 — Assign Incident Commander

Immediately bring together:

```text id="0m8z9a"
Incident Commander
Security
SRE
Network
Backend
Payments
Communications
Compliance
```

Create an incident timeline.

---

## Step 3 — Establish Traffic Baseline

Compare current traffic with normal production traffic.

Check:

```text id="g08k5f"
Requests/sec
Connections
Source distribution
HTTP methods
URI distribution
Response codes
Latency
WAF matches
```

Do not classify a legitimate traffic surge as DDoS without evidence.

---

## Step 4 — Classify the Attack

Determine whether traffic appears to be:

### Layer 3/4 Pattern

Examples:

```text id="f1n3jt"
Connection/packet volume
Network-level saturation
```

### Layer 7 Pattern

Examples:

```text id="9n8q5m"
HTTP request flood
API endpoint abuse
Expensive application requests
```

### Mixed Attack

Network and application-layer indicators occur simultaneously.

Record the classification.

---

# 7. Initial Traffic Analysis

## Step 5 — Check ALB Metrics

Review:

```text id="6h2d0n"
RequestCount
TargetResponseTime
HTTPCode_ELB_5XX_Count
HTTPCode_Target_5XX_Count
ActiveConnectionCount
RejectedConnectionCount
```

Compare current values against the established baseline.

---

## Step 6 — Check WAF Activity

Review AWS WAF metrics and sampled requests.

Focus on:

```text id="f7f2n7"
BlockedRequests
AllowedRequests
CountedRequests
RuleMatches
Rate-based rule matches
IP reputation matches
```

Identify whether one rule or multiple rules are detecting the traffic.

---

## Step 7 — Check EKS Resource Pressure

Run:

```bash id="y8g4m4"
kubectl --context paysecure-dr \
  -n paysecure \
  top pods
```

Use the corresponding primary context when investigating Mumbai.

Check:

```text id="q8k7h4"
CPU
Memory
Pod restarts
Pending pods
Node utilization
Autoscaling activity
```

---

## Step 8 — Check API Health

Test approved health endpoints.

Validate:

```text id="w5p5wt"
API response time
HTTP status
Database connectivity
Kafka connectivity
Authentication
Payment-service dependency health
```

The objective is to determine whether the API is overloaded or a downstream service is failing.

---

# 8. DDoS Mitigation

## Step 9 — Check AWS Shield Status

Review the AWS Shield protections configured for the public-facing infrastructure.

For Shield Advanced deployments, engage the approved AWS Shield response/support process when the event exceeds normal operational handling.

Record:

```text id="w1zj6a"
Time of escalation
AWS case/reference
Attack classification
Affected resources
Traffic characteristics
```

---

## Step 10 — Enable/Verify WAF Rate Limiting

Verify that the approved rate-based WAF controls are active.

A rate-based rule should be configured according to PaySecure's tested baseline rather than an arbitrary emergency threshold.

Conceptual configuration:

```text id="m4k0t2"
Scope:
Public payment API

Action:
Block or challenge traffic exceeding approved threshold

Evaluation:
Rolling request-rate window

Exception:
Approved merchant/service traffic where required
```

Avoid setting a threshold so low that legitimate payment traffic is blocked.

---

## Step 11 — Identify High-Volume Sources

Analyze:

```text id="d6c7z4"
IP addresses
IP ranges
ASN/provider
Geographic distribution
User agents
Request paths
HTTP methods
Request frequency
```

A single source may be blocked only when evidence supports the action.

---

## Step 12 — Apply Targeted WAF Controls

Where appropriate, create temporary controls for:

```text id="l9z3gq"
Malicious IPs
Known malicious CIDRs
Abusive URI patterns
Unexpected methods
Known attack signatures
Abnormal request rates
```

Every temporary rule must have:

```text id="b8b2p8"
Owner
Reason
Timestamp
Expiry/review time
Rollback procedure
```

---

# 9. Protect Payment Services

## Step 13 — Prioritize Critical APIs

Identify payment-critical endpoints.

Examples:

```text id="f8e7s0"
Payment authorization
Payment status
Transaction lookup
Settlement status
Merchant webhook endpoints
```

Avoid unnecessarily exposing expensive internal APIs to the public internet.

---

## Step 14 — Protect Downstream Dependencies

Monitor:

```text id="k6k6nd"
Aurora connections
Aurora CPU
DynamoDB throttling
Redis connections
Kafka producer rate
Kafka consumer lag
```

If API traffic is causing downstream overload, apply controlled request shedding.

---

## Step 15 — Enable Controlled Rate Limiting

If approved, temporarily reduce request rates for non-critical endpoints.

Priority:

```text id="k9f0mv"
Payment-critical
      ↓
Authentication
      ↓
Transaction status
      ↓
Non-critical APIs
```

The objective is to preserve the core payment path.

---

# 10. Capacity Management

## Step 16 — Evaluate Scaling

Determine whether the traffic is:

```text id="f3axz5"
Legitimate peak
Malicious traffic
Mixed
```

If legitimate traffic is significant, scale infrastructure while continuing security mitigation.

---

## Step 17 — Scale EKS Capacity

If required and approved, increase application replicas.

Example:

```bash id="j95p2s"
kubectl --context paysecure-dr \
  -n paysecure \
  scale deployment payment-api \
  --replicas=12
```

Verify:

```bash id="4n9q1h"
kubectl --context paysecure-dr \
  -n paysecure \
  get pods -o wide
```

Use the primary-region context for Mumbai when operating there.

---

## Step 18 — Monitor Autoscaling

Confirm:

```text id="0kr3jd"
Pods scale successfully
Nodes have capacity
Pending pods decrease
CPU stabilizes
Memory stabilizes
API latency improves
```

Do not scale indefinitely if the attack is consuming infrastructure resources faster than they can be added.

---

# 11. Traffic Engineering

## Step 19 — Review Regional Capacity

If Mumbai is under sustained attack and Hyderabad is healthy, assess whether DR infrastructure can safely absorb traffic.

Check:

```text id="j3x4vw"
DR capacity
Database writer
Kafka processing
WAF protection
ALB capacity
Application replicas
Network capacity
```

Do not fail over solely because traffic volume increased.

---

## Step 20 — Controlled Regional Failover Decision

### Branch A — Mumbai Stable

Conditions:

```text id="b8l2ha"
WAF/Shield mitigation effective
AND
API remains healthy
AND
downstream systems stable
```

Action:

```text id="c9j0xy"
Keep Mumbai active.
Continue mitigation and monitoring.
```

### Branch B — Mumbai Degraded, Hyderabad Healthy

Conditions:

```text id="l5a7rv"
Mumbai unavailable/degraded
AND
Hyderabad healthy
AND
DR capacity verified
AND
Incident Commander authorizes failover
```

Action:

```text id="v3t4x7"
Perform controlled regional failover.
```

### Branch C — Both Regions At Risk

Conditions:

```text id="9xj0m4"
Attack affects both regions
OR
DR capacity is insufficient
```

Action:

```text id="2t0r1k"
Continue traffic filtering,
protect critical APIs,
engage AWS support,
and activate emergency capacity controls.
```

---

# 12. Merchant Communication

## Step 21 — Assess Merchant Impact

Determine:

```text id="m0p6v2"
Payment success rate
API availability
Transaction latency
Webhook delay
Settlement delay
Affected merchant groups
```

Do not send a broad merchant communication if there is no merchant-facing impact.

---

## Step 22 — Merchant Communication Template

```text id="q7n1m5"
Subject: PaySecure Service Performance Update

Dear Merchant,

PaySecure is currently responding to elevated traffic affecting parts of our payment infrastructure.

Our security and engineering teams have activated protective measures and are monitoring payment services closely.

Some API requests or transaction notifications may experience temporary delays.

We are prioritizing payment-critical services and will provide further updates if merchant action is required.

Regards,
PaySecure Gateway Operations
```

---

# 13. Payment Validation

## Step 23 — Validate Payment Success Rate

Monitor:

```text id="8j8d8g"
Authorization success
Capture success
Payment API latency
5xx rate
Timeout rate
Transaction failures
```

Compare against the established normal baseline.

---

## Step 24 — Check Transaction Integrity

Confirm that increased traffic has not caused:

```text id="3b7c3f"
Duplicate requests
Duplicate payments
Missing events
Incorrect transaction state
Kafka backlog
Database overload
```

Verify idempotency keys are functioning.

---

## Step 25 — Validate Settlement

Check:

```text id="7x2v9p"
Settlement queue
Settlement success rate
Pending transactions
Failed settlements
Settlement latency
```

A DDoS response must not introduce financial inconsistencies.

---

## Step 26 — Validate Webhooks

Check:

```text id="m4z8p7"
Webhook delivery
Retry queue
Merchant acknowledgements
HTTP status
Webhook latency
```

Ensure the DDoS controls are not unintentionally blocking legitimate merchant webhook traffic.

---

# 14. CloudWatch Alarm Configuration

The exact threshold must be based on PaySecure's production baseline.

### ALB Request Spike

```text id="7x6t8n"
Namespace: AWS/ApplicationELB
Metric: RequestCount
Statistic: Sum
Period: 60 seconds
Evaluation Periods: 3
Threshold: Above approved baseline
Severity: High
```

### ALB 5xx

```text id="8t1s2v"
Namespace: AWS/ApplicationELB
Metric: HTTPCode_ELB_5XX_Count
Statistic: Sum
Period: 60 seconds
Evaluation Periods: 3
Threshold: Above approved baseline
Severity: Critical
```

### Target Response Time

```text id="1v5c9k"
Namespace: AWS/ApplicationELB
Metric: TargetResponseTime
Statistic: p99
Period: 60 seconds
Evaluation Periods: 3
Threshold: Above approved latency baseline
Severity: High
```

### WAF Blocked Requests

```text id="7h4q3p"
Namespace: AWS/WAFV2
Metric: BlockedRequests
Statistic: Sum
Period: 60 seconds
Evaluation Periods: 3
Threshold: Above approved attack baseline
Severity: High
```

### EKS CPU

```text id="0v8j5m"
Metric: Node/Pod CPU Utilization
Period: 60 seconds
Evaluation Periods: 5
Threshold: Above production capacity threshold
Severity: High
```

Thresholds should be calibrated from actual PaySecure traffic and load-testing results.

---

# 15. AWS WAF Emergency Change Record

Every emergency WAF rule should record:

```text id="s4h5q9"
Rule Name:
<name>

Reason:
<DDoS mitigation>

Traffic Pattern:
<pattern>

Action:
<Block/Count/Challenge>

Created:
<timestamp>

Created By:
<operator>

Review At:
<timestamp>

Rollback:
<procedure>
```

Temporary rules must be reviewed and removed when no longer required.

---

# 16. Recovery Monitoring

During active mitigation monitor continuously:

```text id="q5m2j6"
ALB request rate
ALB active connections
ALB 4xx/5xx
Target response time
WAF blocked requests
WAF allowed requests
EKS CPU
EKS memory
Pod count
Aurora connections
Aurora latency
DynamoDB throttling
Redis connections
Kafka producer errors
Kafka consumer lag
Payment success rate
Webhook failures
Settlement backlog
```

---

# 17. Attack Stabilization

## Step 27 — Confirm Traffic Reduction

Confirm:

```text id="8k4r7f"
Malicious traffic decreasing
WAF/Shield mitigation effective
Legitimate traffic recovering
ALB healthy
API latency normalizing
```

Do not remove mitigation controls immediately after traffic decreases.

---

## Step 28 — Maintain Monitoring Window

Keep enhanced monitoring active during a defined stabilization period.

Watch for:

```text id="7n0s6z"
Traffic resurgence
New source IP ranges
Changed attack patterns
Repeated API abuse
Secondary attack
```

---

## Step 29 — Remove Temporary Controls Carefully

After Security approval:

1. Remove expired emergency rules.
2. Restore normal rate limits.
3. Confirm legitimate traffic is not blocked.
4. Record rollback actions.
5. Continue monitoring.

Do not remove permanent protection controls that were part of the approved architecture.

---

# 18. Regulatory Assessment

## Step 30 — Compliance Review

Determine:

```text id="w2x7p5"
Was payment availability materially affected?
Was customer/payment data exposed?
Was there a security breach?
Was settlement affected?
Was transaction integrity affected?
Were applicable reporting thresholds triggered?
```

Compliance/Legal determines whether any regulatory or contractual notification is required.

---

# 19. Internal Engineering Communication

```text id="8s3v0j"
Subject: DDoS Incident Update — PaySecure

Incident ID: <ID>
Detection Time: <timestamp>

Attack Classification:
<L3/L4/L7/Mixed>

Affected Resources:
<ALB/API/other>

Current Traffic:
<value>

Mitigation:
<WAF/Shield/rate limiting/scaling>

Payment Impact:
<summary>

Settlement Impact:
<summary>

Regional Failover:
<yes/no>

Current Status:
<mitigated/monitoring/recovered>

RPO:
<value if applicable>

RTO:
<value>

Next Steps:
<monitoring/RCA/hardening>
```

---

# 20. Evidence Checklist

Preserve:

* [ ] Incident timeline
* [ ] ALB metrics
* [ ] WAF metrics
* [ ] WAF sampled requests where appropriate
* [ ] Shield alerts/events
* [ ] Source traffic analysis
* [ ] Request-rate measurements
* [ ] EKS resource metrics
* [ ] Application logs
* [ ] Network observations
* [ ] Emergency WAF rules
* [ ] Rule creation timestamps
* [ ] Rule rollback records
* [ ] AWS support case/reference
* [ ] Payment success metrics
* [ ] Settlement metrics
* [ ] Webhook metrics
* [ ] Kafka metrics
* [ ] Database metrics
* [ ] Merchant communications
* [ ] RPO/RTO measurements
* [ ] Compliance assessment

Do not store sensitive customer/payment data in the incident evidence repository.

---

# 21. Exit Criteria

RB-07 may be closed when:

1. Attack traffic is mitigated.
2. Legitimate traffic is flowing normally.
3. WAF/Shield controls are stable.
4. ALB health is normal.
5. API latency has returned toward baseline.
6. EKS resource utilization is stable.
7. Payment success rate is normal.
8. No duplicate transactions are detected.
9. Settlement processing is normal.
10. Webhooks are functioning normally.
11. Kafka is healthy.
12. Database performance is stable.
13. Temporary rules are reviewed.
14. Required emergency rules have rollback documentation.
15. Regulatory impact is assessed.
16. Evidence is preserved.
17. Incident Commander approves closure.

---

# 22. Decision Tree

```text id="3c8n4q"
                       DDoS ALERT
                           |
                           v
                  Analyze traffic pattern
                           |
              +------------+------------+
              |                         |
         Legitimate peak          Suspicious traffic
              |                         |
              v                         v
        Scale capacity             Classify attack
              |                         |
              |                 +-------+-------+
              |                 |               |
              |               L3/L4           L7/Mixed
              |                 |               |
              |                 v               v
              |             Shield/          WAF +
              |             network          Shield
              |             controls         controls
              |                 |               |
              +-----------------+---------------+
                                |
                                v
                       Check API health
                                |
                     +----------+----------+
                     |                     |
                   Healthy              Degraded
                     |                     |
                     v                     v
                  Monitor          Protect critical APIs
                                           |
                                           v
                                  Check DR capacity
                                           |
                                  +--------+--------+
                                  |                 |
                                Healthy          Insufficient
                                  |                 |
                                  v                 v
                           Controlled DR       Continue filtering
                              decision         + AWS escalation
                                  |
                                  v
                           Validate payments
                                  |
                                  v
                            Validate settlement
                                  |
                                  v
                            Validate webhooks
                                  |
                                  v
                             Stabilization
                                  |
                                  v
                              RCA/hardening
                                  |
                                  v
                            Close incident
```

---

# 23. RPO/RTO Validation

### RTO

For a DDoS event, record:

```text id="x7g8m0"
Incident detection
→
Effective mitigation
→
Critical payment service restoration
```

Compare the measured recovery time with:

```text id="l7s2h8"
Target RTO: < 5 minutes
```

### RPO

DDoS itself does not necessarily cause data loss.

Validate:

```text id="q9w2n1"
Kafka lag
Database transaction state
Settlement backlog
Event processing
```

If the attack caused a replication/data-processing gap, calculate actual exposure.

Target:

```text id="5j7r4v"
RPO < 1 minute
```

---

# 24. Post-Attack Actions

## Security

* Analyze attack source and techniques.
* Review WAF effectiveness.
* Review Shield response.
* Review false positives.
* Improve rate-based protections.

## Infrastructure

* Review ALB capacity.
* Review EKS autoscaling.
* Review regional capacity.
* Review network architecture.
* Review CloudWatch alarms.

## Application

* Identify expensive endpoints.
* Add caching where appropriate.
* Improve request validation.
* Review idempotency.
* Add circuit breakers.

## Payments

* Reconcile transactions.
* Verify settlement completeness.
* Verify webhook delivery.
* Confirm no duplicate transactions.

## Business Continuity

* Measure actual RTO.
* Review DR activation decision.
* Test regional traffic shifting.
* Update runbook.

---

# 25. Preventive Hardening

After the incident, evaluate:

```text id="g5r4w2"
AWS Shield Advanced
AWS WAF rate-based rules
Managed rule groups
ALB protection
API authentication
Bot controls
EKS autoscaling
CloudWatch anomaly detection
Regional capacity
DDoS testing
Incident alerting
```

Any new control must be tested against legitimate payment traffic before production rollout.

---

# 26. Final Recovery Principle

DDoS recovery is not simply about blocking traffic. The objective is to maintain the availability of legitimate payment traffic while preventing malicious traffic from exhausting the platform.

The preferred sequence is:

```text id="4n7k6d"
Detect
  ↓
Classify
  ↓
Measure traffic
  ↓
Activate WAF/Shield controls
  ↓
Protect critical payment APIs
  ↓
Scale where appropriate
  ↓
Protect downstream systems
  ↓
Validate transactions
  ↓
Validate settlement
  ↓
Stabilize
  ↓
Remove temporary controls
  ↓
Perform RCA
  ↓
Harden
```

**Runbook Status:** Production Security & Recovery Procedure
**Runbook ID:** RB-07
**Scenario:** DDoS Attack
**Owner:** PaySecure Security / SRE
**Review Frequency:** At least annually and after every significant DDoS/security incident
