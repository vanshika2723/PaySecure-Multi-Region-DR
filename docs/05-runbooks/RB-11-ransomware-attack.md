# RB-11 — Ransomware Attack on Infrastructure

**Runbook ID:** RB-11
**Scenario:** Ransomware Attack on EKS Infrastructure and CI/CD Pipeline
**Severity:** Critical
**Primary Region:** `ap-south-1` — Mumbai
**DR Region:** `ap-south-2` — Hyderabad
**Target RTO:** < 5 minutes for critical service recovery where DR activation is required
**Target RPO:** < 1 minute where replicated payment data remains valid
**Primary Systems:** EKS, EC2 worker nodes, CI/CD, ECR, Aurora PostgreSQL, DynamoDB, MSK, S3, KMS, IAM, Secrets
**Incident Commander:** Security Incident Response Lead
**Supporting Teams:** Security, Platform/SRE, DevOps, Database, Network, Application, Payments Operations, Compliance

---

## 1. Scenario Description

PaySecure detects ransomware activity affecting multiple EKS worker nodes and the CI/CD pipeline.

The ransomware may encrypt critical system files on compromised infrastructure and may attempt to spread through:

* EKS worker nodes
* CI/CD runners
* Build artifacts
* Container images
* IAM credentials
* Kubernetes secrets
* Deployment pipelines
* Shared storage
* Administrative endpoints

The first objective is **containment**, not immediate restoration.

The response must prevent the attacker from moving laterally or modifying clean recovery infrastructure.

The project brief requires this scenario to address:

1. Immediate isolation
2. Blast-radius assessment
3. Rebuild versus recovery decision
4. Incident Response Team engagement
5. Restoration from clean backups
6. Post-incident hardening

---

# 2. Incident Objectives

The response team must:

1. Confirm ransomware indicators.
2. Declare a Critical Security Incident.
3. Isolate affected infrastructure.
4. Preserve forensic evidence.
5. Identify the initial attack vector where possible.
6. Determine the blast radius.
7. Protect the DR environment.
8. Rotate compromised credentials.
9. Suspend compromised CI/CD pipelines.
10. Verify integrity of container images and artifacts.
11. Validate payment-data integrity.
12. Identify clean recovery points.
13. Decide between rebuild and recovery.
14. Restore critical payment services.
15. Validate transactions and settlement processing.
16. Monitor for reinfection.
17. Complete security and compliance review.
18. Harden the environment before returning to normal operations.

---

# 3. Initial Detection

Possible indicators include:

* Files suddenly encrypted
* Unexpected ransom notes
* EKS nodes showing abnormal processes
* Unauthorized container execution
* Unexpected privileged Kubernetes activity
* CI/CD jobs modifying production infrastructure
* Unknown IAM activity
* Unexpected ECR image changes
* Encryption-related CPU spikes
* Suspicious outbound network traffic
* Disabled security agents
* Unexpected deletion or modification of logs

---

# 4. Severity Classification

Classify the incident as **Critical** when:

* Multiple production worker nodes are affected.
* Payment-processing workloads are potentially compromised.
* CI/CD production credentials may be compromised.
* Production secrets may have been exposed.
* Ransomware activity is confirmed.
* Data integrity cannot immediately be established.

Do not treat the incident as a normal infrastructure outage.

---

# 5. Immediate Response Timeline

| Activity                          |                             Target |
| --------------------------------- | ---------------------------------: |
| Detection acknowledgement         |                            < 5 min |
| Incident Commander assigned       |                            < 5 min |
| Affected nodes isolated           |                           < 10 min |
| CI/CD production pipeline blocked |                           < 10 min |
| Credential containment            |                           < 15 min |
| Blast-radius assessment started   |                           < 20 min |
| Clean recovery decision           |                  Based on evidence |
| Critical service recovery         | Based on containment and integrity |

Actual timings must be recorded during the incident.

---

# 6. Step-by-Step Response

## Step 1 — Declare Security Incident

Incident Commander declares:

> **RB-11 activated: Critical ransomware incident affecting PaySecure infrastructure.**

Record:

* Detection time
* First affected system
* Detection source
* Affected region
* Affected node IDs
* Affected workloads
* CI/CD status
* Suspected attacker activity
* Current payment impact

---

## Step 2 — Activate Incident Response Team

Immediately involve:

* Security Incident Response Lead
* Incident Commander
* Platform/SRE Lead
* DevOps Lead
* Database Lead
* Application Lead
* Network/Security Engineer
* Payments Operations
* Compliance/Legal representative

Do not allow normal deployment activity to continue while the blast radius is unknown.

---

# 7. Immediate Containment

## Step 3 — Freeze CI/CD Deployments

Immediately stop production deployments.

Disable or pause:

* Production deployment workflows
* Automated production releases
* Infrastructure deployment pipelines
* Automated image promotion
* Scheduled production jobs

Record the pipeline state before changing it.

---

## Step 4 — Identify Affected EKS Nodes

```bash id="s6i0tb"
kubectl --context paysecure-primary \
  get nodes -o wide
```

Check node conditions:

```bash id="1y7q9q"
kubectl --context paysecure-primary \
  describe nodes
```

Identify nodes showing:

* Unexpected processes
* File-system changes
* Authentication anomalies
* Unusual resource consumption
* Security-agent failures

---

## Step 5 — Isolate Compromised Nodes

Mark compromised nodes unschedulable:

```bash id="l6bd6g"
kubectl --context paysecure-primary \
  cordon <COMPROMISED_NODE>
```

Prevent new workloads from being scheduled there.

If evidence preservation is required, do **not** immediately terminate the instance.

---

## Step 6 — Remove Compromised Nodes From Service

After evidence-preservation requirements are satisfied:

```bash id="4ez2db"
kubectl --context paysecure-primary \
  drain <COMPROMISED_NODE> \
  --ignore-daemonsets \
  --delete-emptydir-data
```

Use the approved production procedure and security-team authorization before destructive actions.

---

# 8. AWS Infrastructure Isolation

## Step 7 — Identify Affected EC2 Instances

```bash id="3fymzh"
aws ec2 describe-instances \
  --region ap-south-1 \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,SubnetId,AvailabilityZone]' \
  --output table
```

Map suspicious EC2 instances to:

* EKS nodes
* Availability Zones
* Security groups
* IAM instance profiles

---

## Step 8 — Isolate Network Access

For confirmed compromised infrastructure:

* Remove unnecessary network access.
* Apply emergency isolation security-group rules.
* Block known malicious destinations.
* Restrict administrative access.
* Prevent lateral movement.
* Preserve required forensic access.

Do not modify network controls blindly if doing so could destroy evidence or interrupt containment.

---

# 9. Protect the DR Environment

## Step 9 — Check Hyderabad DR Status

```bash id="u8m2v9"
aws eks update-kubeconfig \
  --name paysecure-dr \
  --region ap-south-2 \
  --alias paysecure-dr
```

Then:

```bash id="j1p7gc"
kubectl --context paysecure-dr \
  get nodes -o wide
```

Confirm the DR environment has not been compromised.

---

## Step 10 — Restrict DR Access

Until integrity is confirmed:

* Do not allow production CI/CD to deploy automatically into DR.
* Restrict administrative access.
* Verify IAM permissions.
* Validate security-group rules.
* Verify monitoring.
* Verify logging.
* Protect clean backups.

The DR environment must not become the attacker's second target.

---

# 10. Blast-Radius Assessment

## Step 11 — Determine Affected Systems

Create an incident inventory:

| Component          | Status                 | Investigation |
| ------------------ | ---------------------- | ------------- |
| EKS worker nodes   | Unknown/Affected/Clean | Required      |
| CI/CD runners      | Unknown/Affected/Clean | Required      |
| ECR images         | Unknown/Affected/Clean | Required      |
| Aurora             | Unknown/Affected/Clean | Required      |
| DynamoDB           | Unknown/Affected/Clean | Required      |
| MSK                | Unknown/Affected/Clean | Required      |
| S3 backups         | Unknown/Affected/Clean | Required      |
| KMS                | Unknown/Affected/Clean | Required      |
| IAM                | Unknown/Affected/Clean | Required      |
| Kubernetes secrets | Unknown/Affected/Clean | Required      |

---

## Step 12 — Review IAM Activity

Review recent IAM activity for:

* Unknown users
* New access keys
* Unexpected role assumption
* Privilege escalation
* Access outside normal operating patterns

Immediately disable credentials confirmed as compromised.

---

## Step 13 — Review Kubernetes Access

```bash id="x5c1nz"
kubectl --context paysecure-primary \
  get rolebindings,clusterrolebindings -A
```

Investigate unexpected privileged bindings.

Check service accounts:

```bash id="y1w0u6"
kubectl --context paysecure-primary \
  get serviceaccounts -A
```

---

## Step 14 — Check Kubernetes Secrets

Do not print secret values.

List secret objects:

```bash id="1m4q4n"
kubectl --context paysecure-primary \
  get secrets -A
```

Determine whether compromised workloads had access to:

* Database credentials
* API keys
* Payment-service credentials
* Kafka credentials
* Cloud credentials
* Third-party credentials

---

# 11. CI/CD Investigation

## Step 15 — Freeze Production Credentials

Potentially exposed CI/CD credentials must be treated as compromised until proven otherwise.

Actions:

1. Disable affected access keys.
2. Revoke active sessions where applicable.
3. Rotate deployment credentials.
4. Review role permissions.
5. Review recent deployments.
6. Review pipeline configuration changes.

---

## Step 16 — Review Recent Deployments

Identify:

* Last known-good deployment
* First suspicious deployment
* Changed container images
* Changed infrastructure code
* Changed Kubernetes manifests
* Unexpected dependency changes

Record commit IDs and timestamps.

---

# 12. Container Image Integrity

## Step 17 — Investigate ECR

List repositories:

```bash id="9m1w8q"
aws ecr describe-repositories \
  --region ap-south-1 \
  --query 'repositories[].repositoryName' \
  --output table
```

Review recent image tags/digests.

Do not automatically trust a production image merely because its tag appears unchanged.

---

## Step 18 — Identify Last Known-Good Image

Select an image based on:

* Verified commit
* Trusted build
* Known-good digest
* Security scan results
* Deployment history

Prefer immutable image digests over mutable tags.

---

# 13. Data Integrity Assessment

## Step 19 — Check Aurora

```bash id="n0f0pr"
aws rds describe-db-clusters \
  --region ap-south-1 \
  --query 'DBClusters[?contains(DBClusterIdentifier, `paysecure`)].[DBClusterIdentifier,Status]' \
  --output table
```

Determine whether ransomware affected:

* Database host
* Credentials
* Application access
* Database records
* Backup access

---

## Step 20 — Check DynamoDB

Verify:

* Table availability
* Unexpected changes
* IAM access
* Backup status
* Point-in-time recovery status

Do not restore over current data until the incident team approves the recovery point.

---

## Step 21 — Check Kafka

Review:

* Broker health
* Topic configuration
* Consumer groups
* Unauthorized topic changes
* Unexpected producers
* Consumer offsets
* Audit events

Preserve relevant logs for investigation.

---

# 14. Backup Integrity

## Step 22 — Identify Clean Recovery Points

A backup is considered a candidate for recovery only after verifying:

* Creation timestamp
* Backup integrity
* Access history
* Encryption status
* No known ransomware activity
* Separation from compromised credentials
* Successful restore test where practical

---

## Step 23 — Verify S3 Backup Location

Review:

* Backup bucket
* Versioning
* Object timestamps
* Access logs
* Replication status
* Encryption
* Unexpected deletions

The cleanest available recovery point should be selected based on the forensic timeline.

---

# 15. Rebuild vs Recovery Decision

## Decision Point

### Option A — Rebuild

Choose the rebuild path when:

* Worker nodes are compromised.
* OS integrity cannot be trusted.
* CI/CD runners are compromised.
* Container runtime integrity is uncertain.
* Clean infrastructure definitions are available.

Process:

1. Isolate compromised nodes.
2. Create clean worker nodes.
3. Apply hardened baseline.
4. Install required agents.
5. Pull verified container images.
6. Deploy from clean infrastructure code.
7. Validate service health.
8. Restore traffic gradually.

---

### Option B — Recover

Choose recovery when:

* Data is intact.
* Infrastructure integrity is established.
* A verified clean recovery point exists.
* Rebuild would introduce unacceptable service delay.
* Security Incident Response approves restoration.

---

### Option C — Cross-Region Recovery

Use Hyderabad when:

* Mumbai infrastructure cannot be trusted.
* Production recovery cannot be safely completed within the required RTO.
* Critical payment workloads are unavailable.
* DR environment is confirmed clean.
* Data replication is valid.

---

# 16. DR Activation Decision Tree

```text id="qv4f6e"
                  RANSOMWARE DETECTED
                          |
                          v
                   ISOLATE SYSTEMS
                          |
                          v
                 Is DR environment clean?
                    /             \
                  NO               YES
                  |                 |
            Continue IR        Assess blast radius
                                    |
                                    v
                          Is payment infrastructure
                              compromised?
                            /             \
                          NO               YES
                          |                 |
                          v                 v
                    Restore normal     Can Mumbai be
                    service safely?    rebuilt safely?
                                      /            \
                                    YES             NO
                                     |               |
                                     v               v
                                  Rebuild        Activate DR
                                     |               |
                                     v               v
                              Validate clean     Validate data
                              environment        integrity
                                     |               |
                                     +-------+-------+
                                             |
                                             v
                                      Restore payment
                                         services
                                             |
                                             v
                                      Monitor for
                                      reinfection
```

---

# 17. Clean Environment Recovery

## Step 24 — Provision Clean EKS Capacity

Create or scale clean worker capacity according to the approved Terraform/Kubernetes configuration.

Validate:

```bash id="4t6n1v"
kubectl --context paysecure-primary \
  get nodes -o wide
```

Every replacement node must pass the security baseline before receiving payment workloads.

---

## Step 25 — Deploy Verified Images

Deploy only approved image digests.

Validate:

* Image source
* Image digest
* Build provenance
* Security scan
* Configuration
* Secrets access

---

## Step 26 — Restore Application Services

Deploy in dependency order:

1. Infrastructure
2. Networking
3. Secrets/KMS integration
4. Database connectivity
5. Kafka connectivity
6. Payment API
7. Fraud services
8. Settlement services
9. Webhook services
10. Monitoring

---

# 18. Credential Rotation

## Step 27 — Rotate Compromised Credentials

Rotate where compromise is possible:

* IAM access keys
* CI/CD credentials
* Database credentials
* Kubernetes secrets
* API keys
* Third-party credentials
* Kafka credentials
* Deployment tokens

Do not reuse credentials from compromised systems.

---

# 19. Payment Validation

## Step 28 — Validate Payment API

```bash id="v1p2oy"
curl -fsS https://api.paysecure.in/health
```

Expected:

```text id="6u0j91"
HTTP 200
```

---

## Step 29 — Execute Controlled Synthetic Payment Test

Validate:

* Request accepted
* Idempotency key handled correctly
* Transaction recorded
* Kafka event generated
* Database status updated
* Settlement event generated
* Webhook processed

Use a controlled non-customer-impacting test transaction.

---

## Step 30 — Verify Transaction Integrity

Compare:

* Database transaction records
* Kafka events
* Payment gateway responses
* Settlement queue
* Merchant status
* Webhook records

Look for:

* Duplicate transactions
* Missing transactions
* Incorrect transaction states
* Unprocessed settlement events

---

# 20. Monitoring During Recovery

Monitor continuously:

* Payment success rate
* HTTP 5xx
* API latency
* EKS CPU/memory
* Node health
* Aurora connections
* Database errors
* Kafka consumer lag
* Kafka broker health
* Security alerts
* IAM activity
* Network traffic
* Unexpected process activity

Increase monitoring sensitivity during the first recovery period.

---

# 21. Merchant Communication

> **Subject: PaySecure Security Incident Service Update**
>
> PaySecure is managing a security incident affecting part of its infrastructure.
>
> Our incident response and infrastructure teams have isolated affected systems and are validating the integrity of the payment environment before restoring affected services.
>
> Payment processing is being monitored continuously. Additional updates will be provided if transaction processing is materially affected.
>
> PaySecure Operations

Do not disclose attacker-specific technical details before the communication is approved by Security and Compliance.

---

# 22. Internal Engineering Notification

> **Subject: CRITICAL — RB-11 Ransomware Incident**
>
> PaySecure has activated RB-11 following confirmed/suspected ransomware activity affecting production infrastructure.
>
> Immediate actions:
>
> * Affected infrastructure isolated
> * Production deployments frozen
> * CI/CD access restricted
> * Security Incident Response Team activated
> * Blast-radius assessment in progress
> * DR environment integrity being validated
>
> Current payment status: [Healthy/Degraded/Unavailable]
>
> Incident Commander: [Name]
>
> Security Lead: [Name]
>
> Next update: [Time]

---

# 23. Security and Compliance Assessment

The Security and Compliance teams must determine:

* Whether payment/cardholder data was accessed
* Whether credentials were compromised
* Whether customer data was exposed
* Whether transaction integrity was affected
* Whether regulatory reporting obligations are triggered
* Whether payment-network partners must be informed
* Whether forensic evidence must be retained

The project brief specifies the incident-response and recovery requirements but does not provide a complete ransomware-specific regulatory notification matrix. Therefore, the final notification decision must follow PaySecure's approved compliance procedure rather than an assumed deadline.

---

# 24. RPO Validation

Record:

```text id="m9z2cb"
Last verified clean data point: __________
Incident detection time: __________
Potential data exposure window: __________
Target RPO: < 1 minute
Observed RPO: __________
Status: PASS / FAIL
```

If the clean recovery point exceeds the RPO target, escalate to the Incident Commander and Compliance Lead.

---

# 25. RTO Validation

Record:

```text id="fjc7s4"
Incident detection: __________
Containment: __________
Recovery decision: __________
Clean infrastructure available: __________
Payment API restored: __________
Synthetic transaction successful: __________
Full service restored: __________
Total recovery time: __________
Target RTO: < 5 minutes
Status: PASS / FAIL
```

For a security incident, safe recovery takes precedence over blindly restoring a compromised environment.

---

# 26. Evidence Checklist

Collect and preserve:

* EKS node status
* Kubernetes audit logs
* CloudTrail records
* IAM activity
* CI/CD logs
* Git commit history
* ECR image history
* Container image digests
* Security alerts
* Network flow logs
* Application logs
* Database logs
* Kafka logs
* S3 access logs
* Backup metadata
* Incident timeline
* Isolation actions
* Credential rotation records
* Recovery approval
* Communication records

Evidence must be preserved before destructive cleanup wherever required by the incident-response process.

---

# 27. Exit Criteria

RB-11 can be closed only when:

* Ransomware activity is contained.
* Affected systems are isolated.
* Blast radius is documented.
* Compromised credentials are rotated/revoked.
* Clean infrastructure is operational.
* Verified container images are deployed.
* Payment API is healthy.
* Database integrity is validated.
* Kafka processing is healthy.
* Settlement processing is healthy.
* No active reinfection indicators remain.
* Monitoring is stable.
* RPO/RTO are documented.
* Security Incident Response approves closure.
* Compliance review is complete.

---

# 28. Post-Incident Hardening

After recovery:

1. Rebuild compromised nodes from trusted images.
2. Enforce immutable infrastructure where possible.
3. Strengthen EKS node security.
4. Restrict Kubernetes RBAC.
5. Enforce least-privilege IAM.
6. Rotate long-lived credentials.
7. Strengthen CI/CD authentication.
8. Require protected production branches.
9. Require image-signing/integrity verification.
10. Strengthen ECR controls.
11. Increase CloudTrail monitoring.
12. Improve endpoint detection.
13. Validate backup immutability.
14. Test clean restore procedures.
15. Review network segmentation.
16. Restrict production administrative access.
17. Review KMS access policies.
18. Validate DR environment isolation.
19. Add ransomware detection to monitoring.
20. Repeat the recovery drill.

---

# 29. Preventive Controls

PaySecure should maintain:

* Immutable infrastructure definitions
* Protected CI/CD pipelines
* Least-privilege IAM
* MFA for privileged access
* Strong Kubernetes RBAC
* Network segmentation
* Centralized logging
* CloudTrail monitoring
* EKS security monitoring
* Verified container images
* Secure ECR repositories
* Protected backups
* Regular restore testing
* Cross-region DR
* Separate DR administration
* Regular credential rotation
* Security incident drills

---

# 30. Final Recovery Principle

Ransomware recovery is different from a normal infrastructure failure.

The objective is **not simply to bring servers back online**.

The recovery sequence must be:

**Contain → Preserve Evidence → Assess Blast Radius → Protect DR → Validate Clean Recovery Point → Rebuild/Recover → Validate Payment Integrity → Restore Traffic → Monitor → Harden.**

A compromised environment must never be treated as trustworthy merely because its services appear operational.
