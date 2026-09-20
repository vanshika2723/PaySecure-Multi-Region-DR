# RB-12 — Cascading Microservice Failure

**Runbook ID:** RB-12
**Scenario:** Fraud Detection Microservice Failure Loop
**Severity:** Critical / P1
**Primary Region:** `ap-south-1` — Mumbai
**DR Region:** `ap-south-2` — Hyderabad
**Target RTO:** < 5 minutes
**Target RPO:** < 1 minute
**Primary Trigger:** Cascading fraud-service timeouts
**Baseline Transaction Success Rate:** 99.8%
**Scenario Success Rate:** 42% after 10 minutes
**Primary Systems:** EKS, Payment API, Fraud Detection Service, Aurora PostgreSQL, MSK Kafka, Redis, ALB, CloudWatch

---

# 1. Scenario Description

The fraud-detection microservice enters a failure loop.

Payment requests call the fraud-detection service, but the fraud service begins returning errors or timing out. Payment API requests remain waiting for fraud responses, causing:

* Increased request latency
* Connection pool exhaustion
* Thread exhaustion
* Retry amplification
* Increased CPU usage
* Kafka consumer delays
* Payment API timeouts
* Transaction failures

The transaction success rate falls from **99.8% to 42% over approximately 10 minutes**.

The required response is to:

1. Detect the cascading failure.
2. Activate the circuit breaker.
3. Prevent retry amplification.
4. Temporarily bypass fraud detection if approved.
5. Apply elevated monitoring.
6. Roll back the suspected deployment.
7. Restore normal fraud processing.
8. Analyze and improve circuit-breaker behavior.

---

# 2. Incident Objectives

The incident team must:

1. Detect the initial fraud-service failure.
2. Identify whether the failure is isolated or cascading.
3. Stop retry amplification.
4. Protect the Payment API.
5. Activate circuit-breaker protection.
6. Preserve transaction integrity.
7. Determine whether the latest deployment caused the issue.
8. Roll back the suspected deployment where appropriate.
9. Temporarily bypass fraud detection only through an authorized emergency decision.
10. Apply elevated monitoring during bypass.
11. Restore fraud detection safely.
12. Validate successful payment processing.
13. Review circuit-breaker configuration.
14. Prevent recurrence.

---

# 3. Detection Signals

Monitor:

* Payment API success rate
* Fraud service error rate
* Fraud service latency
* Payment API P99 latency
* HTTP 5xx
* EKS CPU/memory
* Pod restarts
* Request queue depth
* Database connection utilization
* Kafka consumer lag
* Redis latency
* ALB target response time

The project architecture monitoring specification identifies **Payment API success rate below 99.5% for 2 minutes** as a P1 critical application-health condition and **P99 transaction latency above 300 ms for 5 minutes** as P2.

---

# 4. CloudWatch Alarm Configuration

Create an alarm for Payment API success degradation.

Example:

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "PaySecure-PaymentAPI-SuccessRate-Critical" \
  --alarm-description "Payment API success rate below critical threshold" \
  --namespace "PaySecure/Application" \
  --metric-name "PaymentAPISuccessRate" \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 99.5 \
  --comparison-operator LessThanThreshold \
  --treat-missing-data breaching
```

For P99 latency:

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "PaySecure-PaymentAPI-P99Latency-High" \
  --alarm-description "Payment P99 latency above 300ms" \
  --namespace "PaySecure/Application" \
  --metric-name "TransactionP99Latency" \
  --extended-statistic p99 \
  --period 60 \
  --evaluation-periods 5 \
  --threshold 300 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data breaching
```

The namespace and metric names above are implementation placeholders if the application has not yet published these custom metrics.

---

# 5. Incident Timeline

| Time     | Expected Action                    |
| -------- | ---------------------------------- |
| T+0 min  | Fraud service degradation detected |
| T+1 min  | P1 incident declared               |
| T+2 min  | Dependency and retry analysis      |
| T+3 min  | Circuit breaker activated          |
| T+4 min  | Payment API stabilization check    |
| T+5 min  | Rollback decision                  |
| T+6 min  | Rollback initiated if approved     |
| T+7 min  | Payment success-rate validation    |
| T+8 min  | Fraud service health validation    |
| T+10 min | Recovery assessment                |
| T+15 min | Elevated monitoring continues      |
| T+30 min | Incident stabilization review      |

These are operational targets for the runbook simulation; actual incident timings must be recorded.

---

# 6. Step-by-Step Response

## Step 1 — Declare P1 Incident

Incident Commander declares:

> **RB-12 activated — Cascading microservice failure affecting payment transaction processing.**

Record:

* Detection time
* Payment success rate
* Fraud-service error rate
* Fraud-service latency
* Number of affected pods
* Current deployment version
* Current transaction volume
* Current Kafka lag
* Database connection utilization

---

## Step 2 — Assign Incident Roles

Assign:

**Incident Commander**

* Controls incident decisions.

**Application Lead**

* Owns Payment API and fraud-service investigation.

**Platform/SRE**

* Owns EKS, scaling and circuit-breaker infrastructure.

**Database Lead**

* Monitors Aurora/Redis connection pressure.

**Messaging Lead**

* Monitors Kafka backlog.

**Payments Operations**

* Validates transaction behavior.

---

# 7. Confirm Cascading Failure

## Step 3 — Check Payment API

```bash
curl -fsS https://api.paysecure.in/health
```

Check application logs:

```bash
kubectl --context paysecure-primary \
  -n paysecure logs deployment/payment-api \
  --tail=200
```

Look for:

* Fraud-service timeout
* HTTP 5xx
* Connection timeout
* Retry messages
* Circuit-breaker events

---

## Step 4 — Check Fraud Service

```bash
kubectl --context paysecure-primary \
  -n paysecure get deployment fraud-detection
```

Check pods:

```bash
kubectl --context paysecure-primary \
  -n paysecure get pods \
  -l app=fraud-detection \
  -o wide
```

Inspect logs:

```bash
kubectl --context paysecure-primary \
  -n paysecure logs deployment/fraud-detection \
  --tail=200
```

---

## Step 5 — Check Pod Restarts

```bash
kubectl --context paysecure-primary \
  -n paysecure get pods \
  -l app=fraud-detection \
  -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,STATUS:.status.phase
```

A rapid increase in restarts indicates service instability.

---

# 8. Identify Retry Amplification

## Step 6 — Check Payment API Retry Behavior

Search application logs for:

```text
fraud timeout
fraud retry
connection timeout
circuit open
circuit half-open
```

Determine:

* Number of retries per request
* Retry interval
* Timeout value
* Maximum retry count
* Percentage of requests affected

If retries are amplifying traffic, reduce or disable retries according to the emergency configuration.

---

# 9. Check Infrastructure Dependencies

## Step 7 — Check EKS Capacity

```bash
kubectl --context paysecure-primary \
  get nodes
```

Check resource consumption:

```bash
kubectl --context paysecure-primary \
  top pods -n paysecure
```

Determine whether fraud-service failure is caused by:

* CPU exhaustion
* Memory exhaustion
* Pod limits
* Node pressure
* Network failure
* Dependency failure

---

## Step 8 — Check Aurora Connections

```bash
aws rds describe-db-clusters \
  --region ap-south-1 \
  --query 'DBClusters[?contains(DBClusterIdentifier, `paysecure`)].[DBClusterIdentifier,Status]' \
  --output table
```

Check application connection pressure through CloudWatch/RDS monitoring.

If the fraud-service failure is causing excessive database connections, prevent additional retry traffic before scaling blindly.

---

## Step 9 — Check Redis

Validate:

* Redis availability
* Latency
* Connection count
* Error rate
* Cache hit rate

Determine whether Redis is the source or victim of the cascade.

---

## Step 10 — Check Kafka

Check consumer groups:

```bash
kafka-consumer-groups.sh \
  --bootstrap-server $PRIMARY_BOOTSTRAP \
  --group fraud-processor \
  --describe
```

Monitor:

* Consumer lag
* Consumer restarts
* Processing rate
* Failed messages
* Retry queues

---

# 10. Circuit Breaker Activation

## Step 11 — Open Fraud-Service Circuit

The Payment API must stop repeatedly calling an unhealthy fraud service.

Circuit breaker state:

```text
CLOSED
   |
   | Failure threshold reached
   v
 OPEN
   |
   | Recovery timeout
   v
 HALF-OPEN
   |
   | Successful test requests
   v
 CLOSED
```

During **OPEN** state:

* Requests should fail fast or use the approved fallback.
* No repeated calls should be sent to the unhealthy fraud service.
* Retry storms must stop.

---

# 11. Circuit Breaker Decision Point

### If fraud service is failing but Payment API is healthy:

**Action:**

* Keep circuit open.
* Monitor fraud service.
* Investigate dependency.
* Prepare rollback.

### If Payment API is also degrading:

**Action:**

* Stop retry amplification.
* Scale healthy Payment API capacity if required.
* Consider approved fraud bypass.

### If payment success rate continues falling:

**Action:**

* Activate emergency degradation procedure.
* Consider temporary fraud bypass.
* Notify Incident Commander and Payments Operations.

---

# 12. Temporary Fraud Detection Bypass

## Step 12 — Authorization

Fraud bypass must not be automatically enabled.

Incident Commander, Security/Fraud owner and Payments Operations must approve the emergency bypass.

Record:

```text
Bypass approved by: __________
Approval time: __________
Reason: __________
Expected duration: __________
Additional monitoring enabled: YES / NO
```

---

## Step 13 — Enable Controlled Bypass

The implementation depends on the application's feature-flag mechanism.

Example:

```bash
kubectl --context paysecure-primary \
  -n paysecure set env deployment/payment-api \
  FRAUD_SERVICE_DEGRADED_MODE=true
```

**Important:** Use the application's approved feature-flag mechanism if one exists rather than directly changing production environment variables.

---

# 13. Elevated Monitoring During Bypass

While fraud detection is bypassed, increase monitoring of:

* Transaction volume
* Fraud indicators
* Payment success rate
* Declined transactions
* Suspicious transaction patterns
* Merchant complaints
* Chargeback indicators
* API latency
* Payment errors

The bypass must be temporary.

---

# 14. Emergency Scaling

## Step 14 — Scale Payment API

If healthy Payment API pods are saturated:

```bash
kubectl --context paysecure-primary \
  -n paysecure scale deployment payment-api \
  --replicas=12
```

Verify:

```bash
kubectl --context paysecure-primary \
  -n paysecure get pods \
  -l app=payment-api
```

Scaling must not be used as a substitute for stopping the cascading dependency failure.

---

# 15. Deployment Investigation

## Step 15 — Identify Recent Release

Check:

* Current image
* Deployment timestamp
* Git commit
* Configuration changes
* Dependency changes
* Fraud rules
* Database migrations

```bash
kubectl --context paysecure-primary \
  -n paysecure rollout history deployment/fraud-detection
```

---

# 16. Rollback Decision

Rollback when:

* Failure started immediately after a deployment.
* Previous version is known to be healthy.
* Current version has a reproducible failure.
* Rollback does not introduce known database incompatibility.

Do not rollback blindly if the failure is caused by infrastructure or an external dependency.

---

# 17. Execute Rollback

## Step 16 — Roll Back Fraud Service

```bash
kubectl --context paysecure-primary \
  -n paysecure rollout undo deployment/fraud-detection
```

Monitor:

```bash
kubectl --context paysecure-primary \
  -n paysecure rollout status deployment/fraud-detection
```

---

## Step 17 — Verify New Pods

```bash
kubectl --context paysecure-primary \
  -n paysecure get pods \
  -l app=fraud-detection \
  -o wide
```

Check logs:

```bash
kubectl --context paysecure-primary \
  -n paysecure logs deployment/fraud-detection \
  --tail=100
```

---

# 18. Recovery Validation

## Step 18 — Validate Fraud Service

Test:

```text
Health endpoint → PASS
Fraud request → PASS
Dependency response → PASS
Latency → Within baseline
Error rate → Stable
```

---

## Step 19 — Test Payment API

Validate:

* Authorization
* Fraud decision
* Transaction creation
* Database write
* Kafka event
* Settlement event
* Webhook

Use controlled synthetic transactions.

---

## Step 20 — Check Success Rate

The target is to recover from the scenario degradation toward the normal operating baseline of approximately **99.8% transaction success**.

Record:

```text
Initial success rate: 99.8%
Incident success rate: 42%
Post-circuit-breaker: ______
Post-rollback: ______
Final stabilized rate: ______
```

---

# 19. Kafka Validation

## Step 21 — Check Consumer Lag

```bash
kafka-consumer-groups.sh \
  --bootstrap-server $PRIMARY_BOOTSTRAP \
  --group payment-processor \
  --describe
```

Confirm:

* Lag decreasing
* Consumers healthy
* No uncontrolled retry loop
* Payment events processing normally

---

# 20. Database Validation

## Step 22 — Validate Transaction Records

Check:

* No duplicate transaction IDs
* No missing transaction states
* Correct payment status
* Correct fraud decision state
* Settlement consistency

Do not manually modify transaction records without an approved reconciliation procedure.

---

# 21. Circuit Breaker Recovery

## Step 23 — Move Circuit to HALF-OPEN

After the fraud service is stable, allow a controlled number of test requests.

Monitor:

* Error rate
* Timeout rate
* P99 latency
* CPU
* Memory
* Database connections

---

## Step 24 — Close Circuit

Move from:

```text
HALF-OPEN → CLOSED
```

only after successful validation.

If failures return:

```text
HALF-OPEN → OPEN
```

and continue investigation.

---

# 22. Disable Emergency Bypass

## Step 25 — Restore Fraud Detection

Only after the fraud service is stable:

```bash
kubectl --context paysecure-primary \
  -n paysecure set env deployment/payment-api \
  FRAUD_SERVICE_DEGRADED_MODE=false
```

Verify that new transactions pass through the normal fraud workflow.

---

# 23. Monitor Stabilization

For the stabilization period monitor:

* Payment success rate
* Fraud service errors
* Fraud latency
* Payment API P99
* EKS pod restarts
* Aurora connections
* Kafka lag
* Redis latency
* ALB target response time
* Circuit-breaker state

Do not immediately close the incident after the first successful request.

---

# 24. Incident Communication

## Internal Engineering Notification

> **Subject: P1 — RB-12 Cascading Microservice Failure**
>
> PaySecure has activated RB-12 following a cascading failure involving the fraud-detection service.
>
> The payment success rate degraded from the normal baseline toward 42% during the incident.
>
> Actions taken:
>
> * Fraud-service dependency investigated
> * Circuit breaker activated
> * Retry amplification controlled
> * Payment services monitored
> * Rollback evaluated/executed
> * Emergency fraud bypass activated only if approved
> * Transaction integrity validation in progress
>
> Current status: [Investigating / Stabilizing / Recovered]
>
> Incident Commander: [Name]
>
> Next update: [Time]

---

# 25. Merchant Communication

> **Subject: PaySecure Payment Processing Service Update**
>
> PaySecure experienced temporary degradation in payment processing caused by an application-service failure.
>
> Our engineering teams have isolated the affected dependency and are actively restoring normal transaction processing.
>
> Payment processing and transaction integrity are being monitored continuously.
>
> PaySecure Operations

---

# 26. Decision Tree

```text
              FRAUD SERVICE FAILURE
                       |
                       v
              Payment success rate
                   degrading?
                  /          \
                NO            YES
                |              |
             Monitor       Declare P1
                               |
                               v
                      Cascading retries?
                         /          \
                       YES           NO
                        |             |
                 Stop retries      Continue
                        |          investigation
                        v
                 Open circuit
                        |
                        v
               Payment API stable?
                  /          \
                YES           NO
                 |             |
              Monitor       Emergency
                            degradation
                 |
                 v
        Recent deployment suspected?
             /           \
           YES            NO
            |              |
         Rollback       Investigate
            |              |
            +------+-------+
                   |
                   v
             Fraud service
                healthy?
              /          \
            NO            YES
            |              |
       Keep circuit      HALF-OPEN
          OPEN              |
                            v
                     Controlled tests
                            |
                            v
                      Stable results?
                       /          \
                     NO            YES
                     |              |
                  OPEN          CLOSE
                  circuit       circuit
                                   |
                                   v
                          Disable emergency
                              bypass
                                   |
                                   v
                              Monitor
                                   |
                                   v
                              CLOSE P1
```

---

# 27. RPO/RTO Validation

Record:

```text
Incident detected: __________
Circuit breaker activated: __________
Rollback started: __________
Payment service recovered: __________
Fraud service recovered: __________
Normal fraud processing restored: __________
Incident stabilized: __________

Target RTO: < 5 minutes
Observed RTO: __________
RTO Status: PASS / FAIL
```

Record any transaction impact and verify that transaction state remains consistent.

---

# 28. Root Cause Analysis

Investigate:

1. What caused the fraud service failure?
2. Was a deployment involved?
3. Did a dependency fail?
4. Did retries amplify the failure?
5. Did connection pools become exhausted?
6. Did Kafka backlog increase?
7. Did Redis contribute?
8. Did database connections become saturated?
9. Was the circuit breaker triggered early enough?
10. Did the circuit breaker recover correctly?
11. Was the emergency bypass required?
12. Was monitoring sufficient?

---

# 29. Post-Incident Circuit Breaker Analysis

Review:

* Failure threshold
* Timeout threshold
* Retry count
* Retry backoff
* Open-state duration
* Half-open request count
* Recovery criteria
* Dependency timeout
* Fallback behavior
* Alerting delay

Determine whether the circuit breaker:

```text
Detected failure early enough?     YES / NO
Prevented retry amplification?     YES / NO
Protected Payment API?              YES / NO
Recovered automatically?            YES / NO
Required manual intervention?       YES / NO
```

---

# 30. Preventive Improvements

Implement approved improvements such as:

* Lower dependency timeout.
* Exponential retry backoff.
* Strict retry limits.
* Circuit breaker around every critical synchronous dependency.
* Bulkhead isolation.
* Dependency-specific health checks.
* Better fraud-service autoscaling.
* Improved P99 latency monitoring.
* Synthetic transaction testing.
* Deployment canary testing.
* Automatic rollback on severe health degradation.
* Feature flags for controlled degradation.
* Regular chaos/failure testing.

---

# 31. Post-Incident Validation

Before closure confirm:

* Payment success rate restored.
* Fraud service stable.
* Circuit breaker CLOSED.
* Emergency bypass disabled.
* Kafka lag normal.
* Database connections normal.
* Redis healthy.
* No transaction duplication.
* No missing payment events.
* Settlement processing normal.
* Merchant impact documented.
* Logs preserved.
* Root cause identified or investigation transferred.
* Preventive actions assigned.

---

# 32. Exit Criteria

RB-12 can be closed when:

* Payment success rate has returned to stable operating levels.
* Fraud detection is functioning normally.
* Circuit breaker is operating correctly.
* No cascading timeouts remain.
* Emergency bypass is disabled.
* Transaction integrity is verified.
* Kafka processing is stable.
* Database and cache metrics are normal.
* No rollback-related errors remain.
* Incident timeline is documented.
* Root-cause analysis is assigned/completed.
* Preventive actions are recorded.
* Incident Commander approves closure.

---

# 33. Final Recovery Principle

For a cascading microservice failure, the priority is:

**Detect → Stop Retry Amplification → Open Circuit → Protect Payment API → Roll Back/Repair → Controlled Recovery → Restore Fraud Detection → Validate Transactions → Analyze Circuit Breaker → Harden.**

The circuit breaker should prevent a failure in one dependency from becoming a payment-platform-wide failure.
