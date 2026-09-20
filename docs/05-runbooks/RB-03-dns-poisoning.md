# RB-03 — DNS Poisoning Recovery Runbook

**Document ID:** RB-03
**Scenario:** DNS Poisoning / DNS Routing Compromise
**Severity:** SEV-1
**Primary Region:** AWS Mumbai (`ap-south-1`)
**DR Region:** AWS Hyderabad (`ap-south-2`)
**Primary Components:** Route 53, DNS records, ALB, application endpoints
**RTO Target:** < 5 minutes
**Regulatory Assessment:** CERT-In mandatory assessment; RBI/NPCI assessment based on payment impact

---

## 1. Purpose

This runbook defines the procedure for detecting, containing, investigating, and recovering from a suspected DNS poisoning or DNS routing compromise affecting PaySecure payment endpoints.

A DNS incident can redirect legitimate merchant or customer traffic toward an incorrect, unavailable, or malicious endpoint. Because PaySecure processes payment traffic, DNS integrity must be treated as a security-critical control.

The recovery objectives are:

1. Detect abnormal DNS behaviour.
2. Prevent unauthorized DNS changes.
3. Preserve evidence.
4. Restore the authoritative DNS configuration.
5. Validate Route 53 health checks and routing.
6. Confirm ALB and application endpoints.
7. Validate payment traffic before full restoration.
8. Assess CERT-In, RBI, NPCI, and security notification requirements.

---

# 2. Trigger Conditions

Activate this runbook when one or more of the following occurs:

* Unexpected DNS record modification is detected.
* Route 53 records point to an unknown endpoint.
* DNS resolution differs from the approved configuration.
* Customers report certificate warnings or unexpected endpoints.
* DNS queries resolve to an unauthorized IP/address.
* Route 53 health checks show unexpected behaviour.
* CloudTrail records an unauthorized Route 53 change.
* DNSSEC validation fails, if DNSSEC is enabled.
* Payment traffic suddenly shifts to an unexpected destination.
* Security monitoring identifies suspicious DNS activity.

---

# 3. Roles and Responsibilities

| Role                  | Responsibility                      |
| --------------------- | ----------------------------------- |
| Incident Commander    | Owns incident and recovery decision |
| Security Engineer     | DNS compromise investigation        |
| DevOps/Cloud Engineer | Route 53 and AWS recovery           |
| Network Engineer      | DNS/network validation              |
| Application Engineer  | Endpoint validation                 |
| SRE                   | Monitoring and traffic validation   |
| Compliance/BCP Lead   | Regulatory assessment               |
| Merchant Operations   | Merchant communication              |
| Business Owner        | Recovery approval                   |

---

# 4. Immediate Response

## Step 1 — Declare SEV-1

Declare a security incident when DNS integrity is suspected.

Record:

```text
Incident ID:
Detection Time:
Detection Source:
Affected Domain:
Affected DNS Record:
Incident Commander:
```

**Target:** 2 minutes

---

## Step 2 — Freeze DNS Changes

Immediately stop non-essential:

* Route 53 modifications
* Terraform applies
* DNS migrations
* Domain configuration changes
* CI/CD infrastructure deployments

Only the Incident Commander and authorized DNS/security personnel may approve emergency changes.

---

## Step 3 — Restrict Route 53 Access

Review IAM permissions for users and roles capable of modifying DNS.

```bash
aws iam list-attached-user-policies \
  --user-name <USER>
```

Review recent Route 53 activity through CloudTrail:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=route53.amazonaws.com \
  --max-results 50
```

Identify:

* Who made the change
* Which record was changed
* When it was changed
* Source IP
* AWS role/user
* API operation

---

# 5. Preserve Evidence

## Step 4 — Capture Current DNS State

Export the current Route 53 records.

```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id <HOSTED_ZONE_ID> \
  --output json > route53-records-current.json
```

Do not overwrite the evidence file.

---

## Step 5 — Compare With Approved Configuration

Compare the current state with the approved Git configuration:

```text
Approved configuration
        |
        v
Terraform / Git repository
        |
        v
Current Route 53 configuration
```

Look for:

* Unexpected IP addresses
* Unexpected ALB DNS names
* Modified TTL
* Modified routing policy
* Modified health-check ID
* Deleted records
* Unauthorized records
* Changed aliases

---

# 6. Validate Route 53 Health Checks

## Step 6 — List Health Checks

```bash
aws route53 list-health-checks \
  --query 'HealthChecks[*].[Id,HealthCheckConfig.FullyQualifiedDomainName,HealthCheckConfig.ResourcePath]' \
  --output table
```

---

## Step 7 — Check Health Status

```bash
aws route53 get-health-check-status \
  --health-check-id <HEALTH_CHECK_ID> \
  --query 'HealthCheckObservations[*].[Region,StatusReport.Status]' \
  --output table
```

Determine whether the health-check failure is:

* Genuine application failure
* Network failure
* False failure
* Deliberately manipulated configuration

---

# 7. Validate DNS Resolution

## Step 8 — Query Authoritative DNS

From an approved diagnostic host:

```bash
dig api.paysecure.in
```

Also query:

```bash
dig +short api.paysecure.in
```

Record the result.

---

## Step 9 — Compare DNS Results

Compare:

```text
Expected endpoint:
Actual endpoint:
Expected IP/ALB:
Actual IP/ALB:
TTL:
Record type:
Routing policy:
```

Any unexplained difference must be treated as suspicious.

---

# 8. Check DNS Propagation

## Step 10 — Check Multiple Resolvers

Test resolution through approved external/public resolvers.

Example:

```bash
nslookup api.paysecure.in
```

Repeat from multiple networks or approved monitoring locations.

Determine whether:

* Only one resolver has stale information.
* Multiple resolvers show the malicious/incorrect endpoint.
* Authoritative DNS itself is incorrect.

---

# 9. Validate DNSSEC

## Step 11 — Check DNSSEC Configuration

If DNSSEC is enabled, validate the DNSSEC chain through approved DNS diagnostic tooling.

Check:

```text
DNSKEY
DS
RRSIG
Chain of trust
```

If DNSSEC validation fails, escalate to the Security Engineer immediately.

**Do not disable DNSSEC as a first response.**

---

# 10. Validate AWS Endpoints

## Step 12 — Validate ALB

Check the expected ALB:

```bash
aws elbv2 describe-load-balancers \
  --region ap-south-1 \
  --query 'LoadBalancers[*].[LoadBalancerName,DNSName,State.Code]'
```

---

## Step 13 — Validate DR ALB

```bash
aws elbv2 describe-load-balancers \
  --region ap-south-2 \
  --query 'LoadBalancers[*].[LoadBalancerName,DNSName,State.Code]'
```

Confirm that the approved Route 53 configuration points only to the intended ALB.

---

# 11. Determine Attack Scope

## Step 14 — Identify Affected Endpoints

Check:

```text
api.paysecure.in
payments.paysecure.in
merchant.paysecure.in
webhook.paysecure.in
other production endpoints
```

Use the actual production endpoint inventory during execution.

---

## Step 15 — Check Certificate Mismatch

If users report certificate warnings, inspect the endpoint certificate.

Verify:

```text
Certificate subject
Certificate SAN
Issuer
Validity
Expiry
TLS version
Certificate chain
```

A certificate mismatch may indicate that traffic has reached an unauthorized endpoint.

---

# 12. Containment Decision

### Decision Point A — Is Route 53 Configuration Compromised?

```text
                 DNS anomaly detected
                         |
                         v
               Inspect Route 53 state
                         |
             +-----------+-----------+
             |                       |
          Correct                  Incorrect
             |                       |
             v                       v
      Investigate resolver      Freeze changes
      / cache issue             preserve evidence
                                     |
                                     v
                             Restore approved DNS
```

---

## Step 16 — If Route 53 Is Correct

Investigate:

* Resolver cache
* Local DNS poisoning
* ISP resolver behaviour
* Client-side compromise
* Network interception
* Stale TTL

Do not modify authoritative records unnecessarily.

---

## Step 17 — If Route 53 Is Incorrect

Immediately:

1. Freeze further DNS changes.
2. Preserve current configuration.
3. Identify unauthorized actor.
4. Revoke compromised credentials.
5. Restore the approved record.
6. Validate health checks.
7. Validate endpoint certificates.
8. Monitor traffic.

---

# 13. Credential Containment

## Step 18 — Revoke Suspected Credentials

If an IAM user, role, or access key was used without authorization:

* Disable/revoke compromised credentials.
* Review CloudTrail.
* Review related AWS API activity.
* Rotate affected secrets.
* Check whether other AWS services were modified.

Do not delete forensic evidence.

---

# 14. Restore Route 53 Configuration

## Step 19 — Restore Approved DNS Record

Use the approved infrastructure configuration.

Example command from the project brief:

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id <HOSTED_ZONE_ID> \
  --change-batch file://approved-dns-change.json
```

The exact hosted zone, record, ALB, and routing configuration must be taken from the production configuration repository.

---

## Step 20 — Verify Record

```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id <HOSTED_ZONE_ID> \
  --query "ResourceRecordSets[?Name=='api.paysecure.in.']"
```

Confirm:

* Record name
* Record type
* Alias
* Routing policy
* Health check
* TTL

---

# 15. Validate Application Endpoints

## Step 21 — Test Primary Endpoint

```bash
curl -I https://api.paysecure.in/health
```

Expected result:

```text
HTTP 200
```

---

## Step 22 — Test DR Endpoint

```bash
curl -I https://<DR-ENDPOINT>/health
```

Confirm the DR endpoint is healthy and ready for controlled failover if required.

---

## Step 23 — Validate Application Readiness

For Kubernetes:

```bash
kubectl -n paysecure get pods
```

Then:

```bash
kubectl -n paysecure get deployment
```

Check:

```text
READY
UP-TO-DATE
AVAILABLE
```

---

# 16. Payment Validation

## Step 24 — Execute Controlled Test Transaction

After DNS integrity is restored, execute an approved test payment.

Validate:

```text
DNS resolution
      ↓
ALB
      ↓
EKS
      ↓
Payment API
      ↓
Aurora
      ↓
Kafka
      ↓
Settlement/event processing
```

Confirm the transaction is processed exactly once.

---

# 17. Monitor Traffic

Monitor:

* Request count
* HTTP 4xx
* HTTP 5xx
* TLS errors
* Payment failure rate
* API latency
* ALB target health
* DNS resolution
* Route 53 health checks
* Kafka processing
* Database connections

Example:

```bash
aws cloudwatch describe-alarms \
  --region ap-south-1 \
  --state-value ALARM
```

---

# 18. DNS Failover Decision

If the primary region itself is healthy but DNS was compromised:

**Restore the approved primary DNS configuration.**

If the primary region is also unavailable:

**Follow the approved regional failover procedure and route traffic to the Hyderabad DR environment.**

Do not combine a DNS security incident with a regional failover without validating both conditions.

---

# 19. Regulatory Assessment

The project brief classifies DNS Poisoning as:

* Security: High complexity
* Affected components: Route 53, ALB, all endpoints
* Regulatory notification: CERT-In mandatory

The Compliance/BCP Lead must assess the actual incident and determine the required notification process.

Also assess whether:

* Payment transactions were affected.
* Customer information was exposed.
* Cardholder data was exposed.
* Unauthorized traffic reached a malicious endpoint.
* Merchant credentials were exposed.
* NPCI/UPI traffic was affected.

RBI/NPCI notification requirements should be evaluated based on the actual payment-system impact and applicable obligations.

---

# 20. Communication

## Internal Engineering Notification

> **SEV-1 DNS Security Incident**
>
> PaySecure has detected a suspected DNS integrity issue affecting one or more production endpoints.
>
> DNS changes have been frozen while Security and Cloud Engineering investigate Route 53 configuration and recent AWS activity.
>
> Teams must pause non-essential infrastructure changes until the Incident Commander authorizes further action.
>
> Incident ID: `<INCIDENT-ID>`
>
> Incident Commander: `<NAME>`
>
> Next Update: `<TIME>`

---

## Merchant Communication

> **Service Security Incident Update**
>
> PaySecure is investigating an issue affecting the routing of one or more service endpoints.
>
> Our engineering and security teams have activated the incident response process and are validating service availability and transaction integrity.
>
> Merchants should avoid repeated submission of the same payment request while transaction status is being confirmed.
>
> Further updates will be provided through the established merchant communication channel.

---

## Regulatory Notification Assessment

> **Preliminary DNS Security Incident Assessment**
>
> PaySecure has detected a suspected DNS integrity incident affecting production service routing.
>
> The response team has initiated containment, evidence preservation, DNS validation, credential review, and endpoint verification.
>
> The compliance team is assessing applicable CERT-In, RBI, NPCI, PCI-DSS, contractual, and other notification requirements based on the confirmed impact.
>
> Incident ID: `<INCIDENT-ID>`
>
> Detection Time: `<TIME>`
>
> Affected Endpoint(s): `<ENDPOINTS>`
>
> Confirmed Impact: `<IMPACT>`

---

# 21. Recovery Timing

| Activity                       |     Target |
| ------------------------------ | ---------: |
| Incident declaration           |    0–2 min |
| Freeze DNS changes             |    0–3 min |
| CloudTrail investigation       |    2–8 min |
| DNS configuration validation   |    3–8 min |
| Restore approved configuration |   5–12 min |
| Endpoint validation            |   8–15 min |
| Payment validation             |  10–20 min |
| Monitoring/stabilization       | Continuous |

The project RTO target is **<5 minutes**. Actual DNS recovery time depends on detection, decision, DNS caching/propagation, endpoint readiness, and security validation. DR drills must measure the real achieved timing.

---

# 22. Decision Tree

```text
                 DNS Poisoning Suspected
                           |
                           v
                 Declare SEV-1 incident
                           |
                           v
                  Freeze DNS changes
                           |
                           v
                 Preserve DNS evidence
                           |
                           v
               Is Route 53 compromised?
                    /              \
                  NO                YES
                  |                  |
                  v                  v
          Check resolver/cache   Revoke suspected
          and local network      credentials
                  |                  |
                  |                  v
                  |           Restore approved
                  |           Route 53 records
                  |                  |
                  +--------+---------+
                           |
                           v
                  Validate DNS resolution
                           |
                           v
                    Validate ALB
                           |
                           v
                 Validate TLS certificate
                           |
                           v
                 Validate application
                           |
                           v
                  Test payment transaction
                           |
                           v
                    Monitor traffic
                           |
                           v
                Regulatory assessment
                           |
                           v
                    Incident closure
```

---

# 23. Evidence Checklist

* [ ] Incident ID
* [ ] Route 53 record export before recovery
* [ ] Approved DNS configuration
* [ ] CloudTrail Route 53 events
* [ ] IAM activity
* [ ] Source IP information
* [ ] DNS query results
* [ ] DNSSEC validation results
* [ ] ALB configuration
* [ ] Certificate information
* [ ] Application logs
* [ ] CloudWatch alarms
* [ ] Payment test results
* [ ] Credential rotation evidence
* [ ] Communication records
* [ ] Regulatory assessment
* [ ] Timeline of actions

---

# 24. Exit Criteria

The incident can be closed only after:

* Route 53 configuration matches the approved state.
* Unauthorized DNS changes are understood.
* Compromised credentials are contained.
* DNS resolution is correct.
* ALB endpoints are healthy.
* TLS certificates are valid.
* Application health checks are passing.
* Payment test transaction succeeds.
* No unexplained payment routing remains.
* Monitoring is stable.
* Security investigation is complete.
* Compliance assessment is complete.
* Evidence has been preserved.
* Incident Commander approves closure.

---

# 25. Post-Incident Actions

1. Identify root cause.
2. Identify compromised credentials, if any.
3. Review all Route 53 CloudTrail activity.
4. Review IAM permissions.
5. Implement least-privilege DNS administration.
6. Review DNSSEC configuration.
7. Add Route 53 configuration drift detection.
8. Add CloudTrail alerts for DNS changes.
9. Require approval for production DNS changes.
10. Validate Terraform state against AWS.
11. Review endpoint certificate monitoring.
12. Test DNS failover during the next DR drill.
13. Measure actual DNS detection and recovery time.
14. Update this runbook.
15. Track corrective actions to completion.

---

## Recovery Principle

**DNS is part of the payment security boundary.**

A DNS record must never be considered trustworthy merely because the application behind it is available. Route 53 configuration, IAM activity, DNS resolution, TLS identity, ALB health, and application behaviour must all be validated before normal payment traffic is considered fully recovered.
