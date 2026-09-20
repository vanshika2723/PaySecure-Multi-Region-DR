# RB-06 — Key Compromise Recovery Runbook

## 1. Runbook Metadata

| Field                   | Details                                                                                         |
| ----------------------- | ----------------------------------------------------------------------------------------------- |
| Runbook ID              | RB-06                                                                                           |
| Scenario                | Key Compromise                                                                                  |
| Severity                | Critical                                                                                        |
| Primary Components      | AWS KMS, IAM, Secrets, encrypted databases, application credentials                             |
| Primary Region          | `ap-south-1` — Mumbai                                                                           |
| DR Region               | `ap-south-2` — Hyderabad                                                                        |
| RTO Target              | < 5 minutes for service protection/containment                                                  |
| RPO Target              | < 1 minute where applicable                                                                     |
| Primary Risk            | Unauthorized decryption, credential misuse, data exposure                                       |
| Primary Owner           | Security Engineering                                                                            |
| Supporting Teams        | Platform/SRE, Payments, Database, Backend, Compliance, Business Continuity                      |
| Regulatory Notification | Assess immediately; project brief requires 72-hour notification consideration for this scenario |
| Recovery Strategy       | Detect → contain → revoke/disable access → rotate keys/secrets → validate → restore             |

---

# 2. Scenario Description

This runbook is activated when PaySecure suspects that a cryptographic key, KMS key access path, IAM credential, application secret, or other security credential has been compromised.

A compromise may affect encrypted:

* Payment data
* Database storage
* Backups
* Application secrets
* Kafka data
* S3 objects
* Logs or audit data
* Credentials used by production workloads

The primary objective is to stop unauthorized access while preserving payment availability and transaction integrity.

The response must balance:

```text
Security containment
+
Payment availability
+
Data integrity
+
Evidence preservation
+
Regulatory assessment
```

Do not immediately destroy or permanently delete compromised cryptographic material before Security and Incident Response teams have preserved the required evidence and confirmed the containment plan.

---

# 3. Trigger Conditions

Initiate RB-06 when any of the following occurs:

* Unauthorized KMS API activity is detected.
* A KMS key is suspected to be exposed.
* IAM credentials associated with encryption/decryption are compromised.
* Application secrets are exposed.
* Unexpected `Decrypt`, `GenerateDataKey`, or key-management activity is observed.
* CloudTrail records suspicious KMS access.
* Production credentials appear in logs, source code, CI/CD output, or unauthorized locations.
* A developer, service account, or workload credential is suspected to be compromised.
* Security monitoring reports unauthorized access to encrypted payment-related resources.

---

# 4. Roles and Responsibilities

| Role                     | Responsibility                                 |
| ------------------------ | ---------------------------------------------- |
| Incident Commander       | Coordinates the entire incident                |
| Security Lead            | Owns compromise investigation and containment  |
| IAM Engineer             | Credential and policy containment              |
| KMS Administrator        | Key state, rotation and replacement            |
| Platform/SRE             | Production workload recovery                   |
| Database Engineer        | Database encryption and access validation      |
| Backend Engineer         | Application secret/key replacement             |
| Payments Team            | Transaction and payment-data impact assessment |
| Compliance/Legal         | Regulatory and contractual assessment          |
| Business Continuity Lead | Availability and recovery coordination         |
| Communications Lead      | Internal and external communication            |

No permanent key deletion, broad IAM changes, or production failover should occur without authorized approval.

---

# 5. Security Response Principles

During a key compromise:

1. Treat the credential/key as potentially compromised until evidence proves otherwise.
2. Preserve forensic evidence before destructive actions.
3. Revoke unauthorized access as quickly as practical.
4. Avoid exposing sensitive key material during investigation.
5. Rotate affected credentials.
6. Establish a new trusted encryption path.
7. Validate encrypted data access.
8. Verify that production payment processing remains protected.
9. Review all activity performed using the compromised identity.
10. Document every containment and recovery action.

---

# 6. Initial Response

## Step 1 — Declare Critical Security Incident

**Target: 0–1 minute**

Create a Critical incident.

Record:

```text id="9hkwr6"
Incident ID
Detection timestamp
Affected account
Affected region
Suspected key/credential
Detection source
First suspicious event
Affected service
```

Example:

```text id="7yl8kv"
CRITICAL: Suspected PaySecure Cryptographic Key Compromise
```

---

## Step 2 — Assign Incident Commander

Immediately assign:

```text id="y6u4pz"
Incident Commander
Security Lead
IAM/KMS Engineer
Platform/SRE
Payments
Database
Compliance
Business Continuity
```

Create a restricted incident channel containing only authorized personnel.

Do not copy secrets, private keys, customer data, or raw credentials into the incident channel.

---

## Step 3 — Identify the Suspected Asset

Determine whether the suspected asset is:

```text id="7p7n4s"
KMS customer-managed key
IAM access key
IAM role
Application secret
CI/CD credential
TLS/private key
Database credential
Kafka credential
Cloud provider credential
```

Record the resource ARN/identifier where appropriate.

---

# 7. Evidence Preservation

## Step 4 — Preserve CloudTrail Evidence

Before making major changes, capture the relevant CloudTrail activity.

Investigate events such as:

```text id="2u1vnr"
Decrypt
Encrypt
GenerateDataKey
GenerateDataKeyWithoutPlaintext
CreateGrant
RetireGrant
RevokeGrant
DisableKey
ScheduleKeyDeletion
PutKeyPolicy
CreateKey
```

Record:

```text id="y6r6yq"
Event time
Principal
Source IP
Region
Action
Resource
User agent
Result
```

Preserve evidence according to the organization's security-investigation procedure.

---

## Step 5 — Identify Unauthorized Activity

Determine:

```text id="jvl1m6"
Who accessed the key?
When?
From where?
Which API actions?
Which resources?
Was decryption successful?
Was data accessed?
Was the activity automated?
```

Do not assume every KMS event represents compromise.

Compare suspicious activity with expected application/service behavior.

---

## Step 6 — Determine Compromise Scope

Classify the incident:

### Level A — Credential Exposure

Credential exists outside its approved location but unauthorized use is not confirmed.

### Level B — Unauthorized Key Access

Unauthorized principal has successfully used KMS/key-management permissions.

### Level C — Confirmed Data Access

Evidence indicates encrypted data was successfully decrypted or accessed by an unauthorized party.

### Level D — Broad Security Compromise

Multiple credentials, workloads, accounts, or keys may be affected.

The Incident Commander records the selected level.

---

# 8. Immediate Containment

## Step 7 — Disable Compromised IAM Access

If an IAM access key is confirmed compromised, disable the affected access key using the approved IAM procedure.

Example:

```bash id="5h8ux1"
aws iam update-access-key \
  --access-key-id <COMPROMISED_ACCESS_KEY_ID> \
  --status Inactive \
  --user-name <USER_NAME>
```

If the identity is an assumed role, revoke/contain the role's access according to the organization's emergency IAM procedure.

Do not disable a critical production role without ensuring an approved replacement path exists.

---

## Step 8 — Restrict Unauthorized KMS Access

Review the KMS key policy and grants.

Identify:

```text id="tdrv7k"
Unexpected principals
Unexpected grants
Cross-account access
Unusual service principals
Unexpected IAM roles
```

Remove or disable unauthorized access only after evidence is preserved.

---

## Step 9 — Review KMS Key State

Check the key configuration using the approved AWS account/region.

Example:

```bash id="0k93lh"
aws kms describe-key \
  --key-id <KEY_ID> \
  --region ap-south-1
```

Record:

```text id="wq0l8q"
Key state
Key manager
Key usage
Key ARN
Origin
Enabled/disabled status
```

---

## Step 10 — Check Key Grants

Review grants associated with the suspected key.

```bash id="w9up3d"
aws kms list-grants \
  --key-id <KEY_ID> \
  --region ap-south-1
```

Look for:

```text id="7gdyx9"
Unexpected grantee
Unexpected operations
Unexpected constraints
Unexpected creation time
```

---

# 9. Determine Production Impact

## Step 11 — Identify Dependent Services

Determine which workloads use the affected key.

Potential dependencies include:

```text id="l5frd8"
Aurora
DynamoDB
S3
MSK
EKS workloads
Secrets
Application configuration
Backups
Logs
```

Create an impact map:

```text id="g9u4wh"
Compromised Key
      |
      +-- Database
      +-- S3
      +-- Kafka
      +-- Secrets
      +-- EKS
      +-- Backups
```

---

## Step 12 — Check Payment Data Exposure

Payments and Security teams determine whether sensitive payment data may have been exposed.

Assess:

```text id="5qwxgw"
Data encrypted by affected key
Data decrypted during suspicious period
Systems accessed
Transaction records affected
Card/payment data affected
Merchant data affected
```

Do not place actual payment/card data in the incident record.

---

## Step 13 — Check Database Access

Validate database activity during the suspected compromise window.

Review:

```text id="i8d1i0"
Database connections
Authentication events
Unexpected queries
Encryption/decryption errors
Administrative actions
```

If unauthorized access is suspected, escalate to the Database and Security teams.

---

## Step 14 — Check S3 Access

If the key protects S3 data, review:

```text id="n88r7f"
Object access
GetObject
PutObject
DeleteObject
KMS decrypt activity
Unexpected principals
```

Preserve relevant access evidence.

---

## Step 15 — Check Kafka Access

If Kafka credentials are potentially affected:

```text id="om9j3s"
Producer access
Consumer access
Administrative access
Topic modifications
Credential usage
```

Check for unexpected topic or ACL changes.

---

# 10. Credential Rotation

## Step 16 — Rotate Application Secrets

Identify application secrets dependent on the compromised credential.

Rotate through the approved secrets-management system.

Examples:

```text id="d3imqu"
Database credentials
API credentials
Kafka credentials
Third-party credentials
Service-to-service credentials
```

Do not store replacement secrets in Git repositories or incident messages.

---

## Step 17 — Update Production Workloads

Update affected workloads to use the replacement secret.

For Kubernetes-based services:

```bash id="u8wzqm"
kubectl --context paysecure-dr \
  -n paysecure \
  rollout restart deployment/payment-api
```

Use the corresponding approved production context when updating the primary region.

Monitor pod startup and authentication errors after rotation.

---

## Step 18 — Validate New Credentials

Confirm:

```text id="6sv9iy"
Application can authenticate
Database connection succeeds
Kafka connection succeeds
KMS encryption/decryption works
Secrets are available
No old credential usage remains
```

---

# 11. KMS Key Rotation / Replacement

## Step 19 — Determine Whether Key Rotation Is Required

Security and KMS administrators determine whether:

```text id="a1v6x8"
Existing key can be safely retained
Key material must be rotated
A replacement key is required
Affected data must be re-encrypted
```

Do not schedule deletion of a key solely because compromise is suspected until the recovery and data-access implications are understood.

---

## Step 20 — Create Replacement Key if Required

If the incident requires a replacement customer-managed KMS key, create it using the approved infrastructure process.

Example:

```bash id="e1e5qx"
aws kms create-key \
  --description "PaySecure replacement encryption key"
```

Record the new key ARN securely.

Apply the approved key policy and least-privilege access.

---

## Step 21 — Configure Key Rotation

Where applicable and supported by the selected KMS key type/configuration, enable the organization's approved rotation policy.

Example:

```bash id="f6v4aj"
aws kms enable-key-rotation \
  --key-id <NEW_KEY_ID>
```

Confirm:

```bash id="j7e1px"
aws kms get-key-rotation-status \
  --key-id <NEW_KEY_ID>
```

---

## Step 22 — Update Key References

Update affected infrastructure and workloads to reference the trusted replacement key.

Potential locations:

```text id="3dfv5u"
Terraform
Kubernetes manifests
Secrets configuration
S3 encryption
Database configuration
Kafka encryption configuration
Backup configuration
CI/CD variables
```

Use controlled deployment procedures.

---

# 12. Data Re-Encryption Assessment

## Step 23 — Identify Data Requiring Re-Encryption

Determine whether data encrypted under the affected key requires re-encryption.

Classify:

```text id="0x9x1p"
Active data
Historical data
Backups
Snapshots
Logs
S3 objects
Application secrets
```

The Security and Data teams decide the required treatment based on the compromise scope.

---

## Step 24 — Re-Encrypt Critical Data

Where required, perform controlled re-encryption using the replacement key.

Do not perform uncontrolled bulk re-encryption during a payment peak.

Monitor:

```text id="9nkw2m"
Throughput
Errors
KMS API usage
Application latency
Database load
Storage operations
```

---

## Step 25 — Validate Decryption

For representative approved test data:

```text id="y6fwwh"
Encrypt using trusted key
        ↓
Store
        ↓
Decrypt using trusted key
        ↓
Verify integrity
```

Confirm production applications can still access the required encrypted resources.

---

# 13. Security Validation

## Step 26 — Review IAM Policies

Search for excessive permissions such as:

```text id="z0q8qk"
kms:*
iam:*
*
```

Identify whether the compromise was enabled by excessive privileges.

Do not make broad emergency permission changes that could break payment services.

---

## Step 27 — Review IAM Access Analyzer / Security Findings

Check for:

```text id="zzf8at"
Cross-account access
Public exposure
Unexpected principals
Unused permissions
New trust relationships
```

Record relevant findings.

---

## Step 28 — Check for Persistence

Investigate whether the attacker or unauthorized actor created:

```text id="e3d6qf"
New IAM users
New access keys
New roles
New policies
New KMS grants
New Lambda functions
New workloads
New security groups
New credentials
```

Any confirmed malicious persistence must be escalated immediately to Security Incident Response.

---

## Step 29 — Review CI/CD

Check:

```text id="t4prk6"
Repository secrets
Build logs
Deployment variables
CI/CD service accounts
Container registry credentials
Infrastructure credentials
```

If credentials were exposed through CI/CD, rotate them before returning the pipeline to normal operation.

---

# 14. Production Availability

## Step 30 — Validate Primary Region

Check:

```text id="o5h7ja"
EKS
Aurora
DynamoDB
MSK
S3
KMS
Secrets
ALB
WAF
Monitoring
```

Confirm payment services remain available.

---

## Step 31 — Validate DR Region

Check the Hyderabad environment:

```bash id="7s5v8z"
aws eks update-kubeconfig \
  --name paysecure-dr \
  --region ap-south-2 \
  --alias paysecure-dr
```

Then:

```bash id="b9brn3"
kubectl --context paysecure-dr get nodes -o wide
```

Validate that the replacement key and credentials are also available in the DR region.

---

## Step 32 — Test Payment Flow

Run an approved controlled transaction test.

Validate:

```text id="3fpmv5"
API
 ↓
Authentication
 ↓
Database
 ↓
Kafka
 ↓
Settlement
 ↓
Webhook
 ↓
Audit
```

Do not use real sensitive card/payment information for validation unless explicitly authorized by the production test procedure.

---

# 15. Regulatory and Compliance Assessment

## Step 33 — Start Compliance Assessment

Compliance must determine:

```text id="c2bdgl"
Was protected payment data accessed?
Was data exposed?
Was data altered?
Was there unauthorized decryption?
Was customer data involved?
Was cardholder data involved?
Was payment processing disrupted?
```

The project brief specifically identifies a **72-hour notification consideration** for the key-compromise scenario. The actual notification obligation, recipient and deadline must be confirmed by PaySecure's Compliance/Legal team against the applicable current requirements and incident facts.

Do not represent the 72-hour project requirement as an independent legal conclusion.

---

## Step 34 — PCI-DSS Impact Assessment

Assess:

```text id="e4r4m8"
Cardholder data environment
Encryption controls
Key-management controls
Access controls
Logging
Monitoring
Credential management
Incident response
```

Record which controls were affected and what compensating/recovery actions were performed.

---

## Step 35 — RBI / Payment-System Impact Assessment

Compliance determines whether the incident affects:

```text id="8e1czq"
Payment processing
Settlement
Customer/payment information
Availability
Security controls
Reporting obligations
```

All regulatory communication must be handled by the authorized Compliance/Legal function.

---

# 16. Communication — Internal Security

```text id="f0w6y9"
Subject: CRITICAL — PaySecure Key Compromise Incident

Incident ID: <ID>
Detection Time: <timestamp>

Affected Asset:
<key/credential/resource>

Compromise Status:
<Suspected/Confirmed>

Impact:
<systems/data affected>

Containment:
<actions completed>

Credential Rotation:
<status>

Replacement Key:
<status>

Production Status:
<status>

Data Exposure:
<confirmed/not confirmed/under investigation>

RPO:
<value>

RTO:
<value>

Compliance Assessment:
<status>

Next Steps:
Forensic investigation, validation, reconciliation and RCA.
```

---

# 17. Merchant Communication

Use only if merchant-facing impact occurred.

```text id="xh3h1r"
Subject: PaySecure Security and Service Update

Dear Merchant,

PaySecure has identified and contained a security issue affecting part of its infrastructure.

Our security and engineering teams have implemented protective measures and are validating affected systems.

Payment processing and transaction integrity are being continuously monitored.

If any merchant-specific action is required, PaySecure will communicate directly through the approved support channel.

Regards,
PaySecure Gateway Security & Operations
```

Do not disclose technical security details that could increase operational or security risk.

---

# 18. Regulatory Communication Template

Use only after Compliance/Legal approval.

```text id="6wz6o4"
Subject: Security Incident Notification — PaySecure Gateway

Incident Reference: <ID>
Detection Time: <timestamp>

Incident Type:
Suspected/confirmed cryptographic key compromise

Affected Systems:
<systems>

Incident Window:
<start/end or under investigation>

Current Impact:
<summary>

Containment Actions:
<summary>

Data Impact:
<confirmed/under investigation>

Payment/Settlement Impact:
<summary>

Recovery Status:
<summary>

RPO:
<measured value>

RTO:
<measured value>

Further Investigation:
<status>

Point of Contact:
<authorized compliance/security contact>
```

The authorized Compliance/Legal team must verify the correct recipient, required content and applicable deadline before sending.

---

# 19. Monitoring During Recovery

Monitor:

### KMS

```text id="1y86sy"
Decrypt requests
Encrypt requests
GenerateDataKey requests
AccessDenied events
Unexpected principals
```

### IAM

```text id="pjg6t1"
Console logins
Access-key usage
AssumeRole activity
Policy changes
New credentials
```

### Application

```text id="1ytl9n"
5xx errors
Authentication failures
KMS errors
Database errors
Kafka errors
Payment success rate
```

### Security

```text id="zxz1o6"
CloudTrail
GuardDuty/Security findings
Unauthorized API activity
Suspicious network activity
```

---

# 20. Recovery Validation Checklist

Before closure:

* [ ] Compromised identity identified
* [ ] Evidence preserved
* [ ] Unauthorized access contained
* [ ] KMS policy reviewed
* [ ] KMS grants reviewed
* [ ] IAM credentials rotated/revoked
* [ ] Application secrets rotated
* [ ] Replacement key created where required
* [ ] Key policy validated
* [ ] Production workloads updated
* [ ] DR workloads updated
* [ ] Encryption/decryption tested
* [ ] Database access validated
* [ ] S3 access validated
* [ ] Kafka access validated
* [ ] CI/CD credentials reviewed
* [ ] Persistence checked
* [ ] Payment flow validated
* [ ] Settlement validated
* [ ] Audit logging validated
* [ ] Data exposure assessed
* [ ] PCI-DSS impact assessed
* [ ] RBI/compliance impact assessed
* [ ] Notification decision documented
* [ ] RPO/RTO recorded
* [ ] Evidence secured

---

# 21. Exit Criteria

RB-06 may be closed only when:

1. Compromised access has been contained.
2. Unauthorized credentials have been disabled or rotated.
3. Replacement encryption controls are operational where required.
4. KMS policies and grants are verified.
5. Production applications successfully use trusted credentials/keys.
6. DR applications have equivalent protection.
7. No unexplained unauthorized access remains active.
8. Payment transaction integrity is validated.
9. Settlement integrity is validated.
10. Audit records are preserved.
11. Data exposure assessment is complete or formally tracked.
12. Compliance assessment is complete.
13. Required notification decisions are documented.
14. RPO/RTO measurements are recorded where applicable.
15. Incident Commander and Security Lead approve closure.

---

# 22. Evidence Checklist

Preserve securely:

```text id="f8l9hv"
CloudTrail events
KMS key metadata
KMS grants
KMS policy versions
IAM activity
IAM policy changes
Access-key activity
Security findings
Application logs
Database audit logs
S3 access logs
Kafka access logs
CI/CD logs
Secret rotation records
Key replacement records
Deployment records
Payment validation
Settlement reconciliation
Incident timeline
Communication records
Compliance assessment
```

Never place plaintext secrets, private keys, card data, passwords or access tokens in the evidence repository.

---

# 23. Decision Tree

```text id="v2a7s8"
                  KEY COMPROMISE DETECTED
                           |
                           v
                   Preserve evidence
                           |
                           v
                  Identify affected asset
                           |
              +------------+------------+
              |                         |
          Credential                 KMS key
          compromise               compromise
              |                         |
              v                         v
        Disable/rotate             Review access
        credential                 and grants
              |                         |
              +------------+------------+
                           |
                           v
                    Determine scope
                           |
                 +---------+---------+
                 |                   |
              No data             Data access
              exposure            suspected
                 |                   |
                 v                   v
            Continue             Security +
            validation           Compliance
                                     |
                                     v
                              Assess affected data
                                     |
                                     v
                            Replace/rotate controls
                                     |
                                     v
                            Update applications
                                     |
                                     v
                           Validate encryption
                                     |
                                     v
                           Validate payments
                                     |
                                     v
                           Assess compliance
                                     |
                                     v
                         Notification decision
                                     |
                                     v
                            Monitor for recurrence
                                     |
                                     v
                             Close incident
```

---

# 24. Recovery Timing Target

| Activity                    |                          Target |
| --------------------------- | ------------------------------: |
| Incident declaration        |                         0–1 min |
| Security team engagement    |                         ≤ 1 min |
| Asset identification        |                         ≤ 2 min |
| Initial containment         |                         ≤ 5 min |
| Credential disable/rotation |   As quickly as safely possible |
| Replacement-key preparation |                  Based on scope |
| Application validation      | ≤ 5 min after credential update |
| Payment validation          |        Immediate after recovery |
| Compliance assessment       |        Begin during containment |
| Final investigation         |         Based on incident scope |

The `<5 minute` project RTO should be measured for the service-recovery portion of the incident. Forensic investigation, data analysis and regulatory assessment may continue after service restoration.

---

# 25. Post-Incident Actions

## Security

* Complete root-cause analysis.
* Identify initial access vector.
* Review unauthorized activity.
* Confirm no persistence remains.
* Review security monitoring coverage.

## IAM

* Apply least privilege.
* Remove unused access keys.
* Review role trust policies.
* Review cross-account access.
* Review emergency access procedures.

## KMS

* Review key policies.
* Review grants.
* Review rotation configuration.
* Review key usage.
* Review backup encryption.

## Application

* Review secret-management process.
* Remove hard-coded credentials.
* Review CI/CD secret handling.
* Review service-to-service authentication.

## Compliance

* Complete incident assessment.
* Document notification decision.
* Preserve required evidence.
* Track any outstanding regulatory actions.

## DR

* Confirm replacement controls work in Mumbai and Hyderabad.
* Validate key/secret synchronization.
* Test recovery using the replacement security controls.
* Update RB-06 based on lessons learned.

---

# 26. Final Recovery Principle

A cryptographic key compromise must be handled as both a **security incident** and a **business continuity event**.

The recovery sequence is:

```text id="mx7p6k"
Detect
  ↓
Preserve evidence
  ↓
Identify compromise
  ↓
Contain unauthorized access
  ↓
Rotate/revoke credentials
  ↓
Replace affected key where required
  ↓
Update production + DR
  ↓
Validate encryption
  ↓
Validate payments
  ↓
Assess data exposure
  ↓
Assess compliance
  ↓
Monitor
  ↓
Close
```

The priority is:

```text id="h1e4mt"
Protect sensitive data
        +
Maintain payment integrity
        +
Restore trusted access
        +
Preserve evidence
        +
Meet applicable reporting requirements
```

**Runbook Status:** Production Security & Recovery Procedure
**Runbook ID:** RB-06
**Scenario:** Key Compromise
**Owner:** PaySecure Security Engineering
**Review Frequency:** At least annually and after every key/credential security incident
