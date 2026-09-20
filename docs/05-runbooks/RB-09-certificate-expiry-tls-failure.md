# RB-09 — Certificate Expiry / TLS Failure Recovery Runbook

## 1. Runbook Metadata

| Field                   | Details                                                      |
| ----------------------- | ------------------------------------------------------------ |
| Runbook ID              | RB-09                                                        |
| Scenario                | Certificate Expiry / TLS Failure                             |
| Severity                | High / Critical                                              |
| Primary Components      | ACM, ALB, EKS/Ingress, Route 53, TLS endpoints, Payment APIs |
| Primary Region          | `ap-south-1` — Mumbai                                        |
| DR Region               | `ap-south-2` — Hyderabad                                     |
| RTO Target              | < 5 minutes                                                  |
| RPO Target              | < 1 minute                                                   |
| Primary Risk            | Payment API unavailability and failed secure connections     |
| Primary Owner           | Platform / Security                                          |
| Supporting Teams        | SRE, Network, Backend, Payments, DNS, Compliance             |
| Regulatory Notification | Assess based on actual service/security impact               |

---

# 2. Scenario Description

This runbook is activated when an SSL/TLS certificate expires, becomes invalid, is incorrectly configured, or causes clients to reject secure connections.

A TLS failure can prevent merchants, payment clients, webhooks, internal services, or customers from securely connecting to PaySecure endpoints.

Typical symptoms include:

* Certificate expiration warnings
* TLS handshake failures
* `SSL_ERROR`
* `CERTIFICATE_EXPIRED`
* `CERTIFICATE_VERIFY_FAILED`
* `ERR_CERT_COMMON_NAME_INVALID`
* Incomplete certificate chain
* Incorrect certificate attached to ALB/Ingress
* API clients unable to establish HTTPS connections
* Payment API availability degradation

The recovery objective is to restore valid TLS connectivity while ensuring the replacement certificate is correctly configured and trusted across supported clients.

---

# 3. Trigger Conditions

Activate RB-09 when:

* Certificate expiry alert is triggered.
* ACM certificate enters an unexpected state.
* ALB HTTPS listener presents an invalid certificate.
* API clients report TLS failures.
* Merchant webhooks fail due to certificate validation.
* Browser/client certificate warnings appear.
* TLS handshake error rate increases.
* Certificate hostname does not match the requested domain.
* Intermediate certificate chain is incomplete.
* A certificate renewal or deployment fails.

---

# 4. Roles and Responsibilities

| Role                | Responsibility                   |
| ------------------- | -------------------------------- |
| Incident Commander  | Coordinates incident             |
| Platform Engineer   | ACM/ALB/EKS certificate recovery |
| Security Lead       | Certificate and trust validation |
| Network Engineer    | DNS/TLS connectivity             |
| Backend Engineer    | API validation                   |
| Payments Lead       | Payment-flow validation          |
| SRE                 | Monitoring and service recovery  |
| Communications Lead | Merchant communication           |
| Compliance          | Impact/regulatory assessment     |

---

# 5. Initial Response

## Step 1 — Declare Incident

**Target: 0–1 minute**

Create a High/Critical incident.

Record:

```text
Incident ID
Detection timestamp
Affected hostname
Affected region
Certificate ARN
Certificate expiry date
Current certificate status
Affected services
First observed failure
```

Example:

```text
HIGH: TLS Certificate Failure on PaySecure API
```

---

## Step 2 — Assign Incident Commander

Bring together:

```text
Incident Commander
Platform
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

# 6. Certificate Investigation

## Step 3 — Identify Affected Endpoint

Determine whether the failure affects:

```text
api.paysecure.example
merchant.paysecure.example
webhook.paysecure.example
internal service endpoint
```

Record every affected hostname.

---

## Step 4 — Inspect ACM Certificates

List certificates:

```bash
aws acm list-certificates \
  --region ap-south-1 \
  --certificate-statuses ISSUED EXPIRED PENDING_VALIDATION
```

Repeat for the DR region:

```bash
aws acm list-certificates \
  --region ap-south-2 \
  --certificate-statuses ISSUED EXPIRED PENDING_VALIDATION
```

---

## Step 5 — Inspect Certificate Details

For the identified certificate:

```bash
aws acm describe-certificate \
  --certificate-arn <CERTIFICATE_ARN> \
  --region ap-south-1
```

Check:

```text
Domain name
Subject Alternative Names
Status
Not Before
Not After
Renewal eligibility
Validation status
```

---

# 7. Determine Failure Type

## Step 6 — Classify Certificate Failure

### Branch A — Certificate Expired

```text
NotAfter < current time
```

Action:

```text
Emergency replacement/renewal.
```

### Branch B — Wrong Hostname

Certificate does not match requested hostname.

Action:

```text
Deploy correct certificate.
```

### Branch C — Invalid Chain

Certificate is valid but client cannot establish trust.

Action:

```text
Validate certificate chain and listener configuration.
```

### Branch D — Correct Certificate but TLS Still Fails

Investigate:

```text
ALB listener
Ingress
DNS
TLS policy
Network connectivity
Client compatibility
```

---

# 8. ALB Validation

## Step 7 — Identify ALB

List/load approved ALB information and identify the affected load balancer.

Check:

```text
ALB ARN
HTTPS listener
Listener port
Attached certificate
Target groups
Region
```

---

## Step 8 — Inspect HTTPS Listener

Example:

```bash
aws elbv2 describe-listeners \
  --load-balancer-arn <ALB_ARN> \
  --region ap-south-1
```

Confirm:

```text
HTTPS listener exists
Port = 443
Correct certificate attached
Expected TLS policy
```

---

## Step 9 — Inspect Listener Certificates

```bash
aws elbv2 describe-listener-certificates \
  --listener-arn <LISTENER_ARN> \
  --region ap-south-1
```

Verify the certificate ARN matches the intended production certificate.

---

# 9. DNS Validation

## Step 10 — Verify DNS

Confirm the affected hostname resolves to the intended endpoint.

Check:

```text
A/AAAA record
Alias target
ALB hostname
Route 53 health
Regional routing
```

For PaySecure's architecture, verify both Mumbai and Hyderabad DNS configurations.

---

## Step 11 — Check Route 53 Health

Use:

```bash
aws route53 get-health-check-status \
  --health-check-id HC123456 \
  --query 'HealthCheckObservations[*].[Region,StatusReport.Status]' \
  --output table
```

Confirm whether the TLS failure is causing the health check to fail.

---

# 10. Emergency Certificate Recovery

## Step 12 — Check Existing Valid Certificate

Before issuing a replacement, search ACM for an already-issued certificate covering the affected hostname.

Example:

```bash
aws acm list-certificates \
  --region ap-south-1 \
  --certificate-statuses ISSUED
```

If an approved valid certificate exists, prefer controlled deployment of that certificate.

---

## Step 13 — Request Replacement Certificate if Required

If no valid certificate exists, initiate the approved ACM certificate request process.

The certificate must cover the exact production hostname.

Example:

```bash
aws acm request-certificate \
  --domain-name api.paysecure.example \
  --validation-method DNS \
  --region ap-south-1
```

Use the organization's approved domain-validation process.

---

## Step 14 — Validate Certificate

Before production attachment, verify:

```text
Domain
SANs
Validity period
Status = ISSUED
Certificate chain
Validation completion
```

Do not attach a certificate that has not passed validation.

---

# 11. Certificate Deployment

## Step 15 — Attach Correct Certificate to ALB

Once the certificate is approved and issued:

```bash
aws elbv2 modify-listener \
  --listener-arn <LISTENER_ARN> \
  --certificates CertificateArn=<CERTIFICATE_ARN> \
  --region ap-south-1
```

Verify the listener afterward.

---

## Step 16 — Validate Listener

```bash
aws elbv2 describe-listeners \
  --load-balancer-arn <ALB_ARN> \
  --region ap-south-1
```

Confirm the intended certificate is active.

---

# 12. EKS / Ingress Validation

## Step 17 — Check Kubernetes Ingress

If TLS terminates at Kubernetes Ingress, inspect:

```bash
kubectl --context paysecure-primary \
  -n paysecure get ingress
```

Check:

```text
Hostname
TLS configuration
Certificate reference
Ingress controller
Load balancer endpoint
```

---

## Step 18 — Validate TLS Secret

If the architecture uses a Kubernetes TLS secret:

```bash
kubectl --context paysecure-primary \
  -n paysecure get secret
```

Identify the relevant TLS secret and verify that the deployment references the intended certificate.

Do not expose private key material in terminal output, logs, screenshots, or incident channels.

---

# 13. Trust Chain Validation

## Step 19 — Validate Certificate Chain

Confirm:

```text
Leaf certificate
       ↓
Intermediate CA
       ↓
Trusted root
```

A valid leaf certificate can still fail if the expected intermediate chain is not correctly presented.

---

## Step 20 — Validate Hostname

Confirm:

```text
Requested hostname
=
Certificate SAN/CN
```

For example:

```text
api.paysecure.example
```

must be covered by the certificate.

---

# 14. Cross-Client Testing

## Step 21 — Test HTTPS Endpoint

From an approved test environment:

```bash
curl -Iv https://api.paysecure.example/health
```

Validate:

```text
TLS handshake
Certificate validity
Hostname verification
HTTP status
Response latency
```

---

## Step 22 — Test Supported Clients

Test the endpoint using representative:

```text
Modern browser
Merchant API client
Backend service
Webhook client
Approved mobile/client environment
```

The objective is to ensure the new certificate works across supported client types.

---

# 15. Payment API Validation

## Step 23 — Validate Health Endpoint

```bash
curl -I https://api.paysecure.example/health
```

Confirm successful HTTPS connection and expected application response.

---

## Step 24 — Validate Payment API

Perform an approved non-destructive/synthetic payment API test.

Validate:

```text
TLS handshake
Authentication
API response
Transaction processing path
Latency
```

Do not perform uncontrolled real-money test transactions.

---

# 16. Webhook Validation

## Step 25 — Validate Merchant Webhooks

Check webhook delivery after certificate recovery.

Monitor:

```text
Webhook success
TLS failures
Timeouts
Retry count
HTTP status
```

A certificate issue may affect merchant webhook callbacks even if the main payment API is healthy.

---

# 17. Monitoring

## Step 26 — Monitor TLS Error Rate

Monitor application and load-balancer logs for:

```text
TLS handshake failures
Certificate errors
Connection failures
HTTP 4xx/5xx
Timeouts
```

---

## Step 27 — Monitor Payment Availability

Confirm:

```text
Payment success rate
API availability
API latency
Transaction failures
Webhook success
Merchant connectivity
```

---

# 18. Mumbai and Hyderabad Validation

## Step 28 — Validate DR Region

Repeat certificate validation in:

```text
ap-south-2
```

Check:

```text
ACM certificate
ALB listener
Ingress
DNS
Health check
HTTPS endpoint
```

The DR environment must not retain an expired certificate.

---

## Step 29 — Verify Failover Readiness

Confirm:

```text
Mumbai certificate = valid
Hyderabad certificate = valid
Route 53 = healthy
ALB = healthy
HTTPS = valid
Payment API = healthy
```

This prevents a certificate problem from becoming a secondary failure during regional failover.

---

# 19. Emergency DNS/Traffic Decision

## Step 30 — Decision Point

### Branch A — Certificate Fixed in Primary

```text
Primary HTTPS healthy
+
DR HTTPS healthy
```

Action:

```text
Continue normal operation.
```

### Branch B — Primary Certificate Failure, DR Healthy

```text
Primary TLS unavailable
+
DR TLS healthy
+
DR application healthy
```

Action:

```text
Incident Commander may authorize controlled regional failover according to the DNS failover runbook.
```

### Branch C — Both Regions Have TLS Failure

```text
Mumbai TLS failed
+
Hyderabad TLS failed
```

Action:

```text
Emergency certificate recovery is required.
Do not fail over between two unhealthy TLS endpoints.
```

---

# 20. Merchant Communication

If merchant-facing services are materially affected:

```text
Subject: PaySecure API Connectivity Update

Dear Merchant,

PaySecure has identified a temporary secure-connection issue affecting access to some payment services.

Our engineering team has activated the recovery procedure and is validating secure connectivity across production endpoints.

We are monitoring payment processing and webhook delivery closely.

Further updates will be provided if merchant action is required.

Regards,
PaySecure Gateway Operations
```

---

# 21. Internal Engineering Communication

```text
Subject: RB-09 TLS Certificate Incident

Incident ID: <ID>

Affected Hostname:
<hostname>

Certificate:
<certificate identifier>

Failure Type:
<expired/wrong hostname/chain/TLS configuration>

Primary Region:
<status>

DR Region:
<status>

Recovery Action:
<renewed/replaced/reconfigured>

API Status:
<healthy/degraded>

Payment Impact:
<summary>

Webhook Impact:
<summary>

Current Status:
<monitoring/recovered>

Next Action:
<monitoring/RCA/preventive automation>
```

---

# 22. CloudWatch / Monitoring Alerts

Recommended team-defined alarms include:

### Certificate Expiry

```text
Metric:
DaysUntilExpiry

Warning:
Within approved warning window

Critical:
Within emergency expiry window
```

The exact thresholds should be defined according to PaySecure's certificate-management policy.

### TLS Error Monitoring

```text
Metric:
TLS/handshake failure count

Period:
60 seconds

Evaluation:
3 consecutive periods

Threshold:
Above established production baseline

Severity:
High/Critical
```

### API Availability

```text
Metric:
HTTPS health-check failure

Period:
60 seconds

Evaluation:
3 consecutive periods

Threshold:
Health check unhealthy

Severity:
Critical
```

Thresholds should be calibrated against production baselines and tested before use.

---

# 23. Evidence Checklist

Preserve:

* [ ] Incident ID
* [ ] Detection timestamp
* [ ] Certificate ARN/reference
* [ ] Certificate expiry information
* [ ] ACM status
* [ ] ALB listener configuration
* [ ] Ingress configuration
* [ ] Route 53 health status
* [ ] TLS test results
* [ ] API health results
* [ ] Payment validation results
* [ ] Webhook validation
* [ ] Mumbai validation
* [ ] Hyderabad validation
* [ ] Certificate deployment timestamp
* [ ] Emergency change record
* [ ] Merchant communication
* [ ] Internal communication
* [ ] RPO/RTO measurements
* [ ] Compliance assessment

Never store private keys or sensitive certificate material in incident documentation.

---

# 24. RPO/RTO Validation

## RTO

Measure:

```text
Certificate failure detected
        ↓
Certificate identified
        ↓
Valid certificate deployed
        ↓
TLS endpoint restored
        ↓
Payment API validated
        ↓
Normal service confirmed
```

Compare the measured recovery time against:

```text
Target RTO: < 5 minutes
```

---

## RPO

A certificate failure normally should not cause transaction-data loss.

Nevertheless, validate:

```text
Payment records
Kafka events
Transaction state
Settlement records
Webhook events
```

Target:

```text
RPO < 1 minute
```

If transactions were interrupted during the outage, reconcile all affected transaction states.

---

# 25. Exit Criteria

RB-09 may be closed when:

1. Valid certificate is deployed.
2. Certificate covers the correct hostname.
3. Certificate chain is valid.
4. HTTPS handshake succeeds.
5. ALB/Ingress is healthy.
6. Route 53 health checks are healthy.
7. Mumbai endpoint is validated.
8. Hyderabad endpoint is validated.
9. Payment API is operational.
10. Webhooks are operational.
11. TLS error rate has returned toward baseline.
12. No unresolved payment failures caused by the certificate remain.
13. RPO/RTO are measured.
14. Compliance impact is assessed.
15. Evidence is preserved.
16. Incident Commander approves closure.

---

# 26. Decision Tree

```text
                  TLS ALERT
                     |
                     v
              Identify endpoint
                     |
                     v
             Inspect certificate
                     |
          +----------+----------+
          |                     |
       Valid                  Invalid
          |                     |
          v                     v
   Check ALB/Ingress       Renew/replace
          |                     |
          v                     v
    Check DNS/TLS          Validate domain
          |                     |
          v                     v
   Cross-client test       Attach certificate
          |                     |
          +----------+----------+
                     |
                     v
             Test HTTPS endpoint
                     |
                     v
              Test Payment API
                     |
                     v
             Test Webhooks
                     |
                     v
          Validate Mumbai + DR
                     |
          +----------+----------+
          |                     |
       Healthy                Unhealthy
          |                     |
          v                     v
       Monitor          Continue recovery
          |                     |
          v                     v
       Close             Escalate/DR decision
```

---

# 27. Preventive Controls

PaySecure should maintain:

```text
ACM certificate automation
Certificate expiry monitoring
Automated renewal validation
Route 53 health checks
ALB certificate monitoring
EKS/Ingress certificate monitoring
TLS synthetic monitoring
Multi-region certificate readiness
Certificate inventory
Emergency renewal procedure
Certificate ownership documentation
```

Certificate changes should be tested in a controlled environment before production deployment where practical.

---

# 28. Post-Incident Review

After recovery:

1. Determine why the certificate expired or became invalid.
2. Check whether renewal automation failed.
3. Check domain-validation configuration.
4. Review monitoring lead time.
5. Review emergency change process.
6. Verify both regions.
7. Review client compatibility.
8. Review payment impact.
9. Update certificate inventory.
10. Add preventive automation where required.

---

# 29. Final Recovery Principle

Certificate failures must be treated as availability and security incidents because secure connectivity is essential for PaySecure's payment APIs and merchant integrations.

The recovery sequence is:

```text
Detect
  ↓
Identify certificate
  ↓
Classify TLS failure
  ↓
Validate ACM/ALB/Ingress
  ↓
Renew or replace certificate
  ↓
Validate trust chain
  ↓
Validate hostname
  ↓
Test HTTPS
  ↓
Test payment APIs
  ↓
Test webhooks
  ↓
Validate Mumbai + Hyderabad
  ↓
Monitor
  ↓
Reconcile payment impact
  ↓
RCA
  ↓
Automate prevention
```

**Runbook Status:** Production TLS/Certificate Recovery Procedure
**Runbook ID:** RB-09
**Scenario:** Certificate Expiry / TLS Failure
**Owner:** PaySecure Platform / Security
**Review Frequency:** At least annually and after every significant certificate/TLS incident
