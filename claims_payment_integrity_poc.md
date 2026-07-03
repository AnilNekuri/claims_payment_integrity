# Claims Payment Integrity Monitoring & Reprocessing Platform POC

## 1. POC Name

**Claims Payment Integrity Monitoring & Reprocessing Platform**

Alternative names:

- Claims Integrity Rules Monitoring POC
- Payment Integrity Rules Engine POC
- Claims Processing Observability & DMR Simulation POC

---

## 2. Purpose

This POC simulates a PISCES-like claims processing and monitoring platform using common cloud and open-source technologies.

The goal is to demonstrate:

- Kafka-based claims ingestion
- Python rules engine processing
- Kubernetes-based deployment and job execution
- Amazon RDS PostgreSQL persistence and reconciliation
- Nightly validation using Kubernetes CronJob
- Splunk-based log analysis
- CloudWatch baseline observability for AWS and EKS
- DMR-style data correction and reprocessing workflow

This POC does **not** use Centene internal systems. It uses generic names and open-source/AWS services to simulate similar production support and monitoring patterns.

---

## 3. Internal Concept to POC Mapping

| Internal / Real-World Concept | POC Equivalent |
|---|---|
| PISCES | Claims Payment Integrity Rules Engine |
| CKPaaS | Kubernetes Platform / Amazon EKS |
| DMR | Data Correction / Reprocessing Request |
| Splunk | Log monitoring and error analysis |
| CloudWatch | AWS-native logs and baseline observability |
| Rancher | Kubernetes management UI |
| Kubernetes | Runtime for services, jobs, and cron jobs |
| Amazon MSK | Managed Kafka event streaming |
| SQL / RDS | Claim processing, reporting, and reconciliation store |

---

## 4. High-Level Architecture

```text
Claim Producer
   ->
Amazon MSK Kafka Topic: claim-events
   ->
Python Rules Engine Consumer
   ->
PostgreSQL / Amazon RDS Reporting Store
   ->
Kubernetes CronJob for Nightly Validation
   ->
DMR Requests Table
   ->
Logs to Splunk
   ->
Baseline AWS/EKS visibility in CloudWatch
```

---

## 5. AWS Architecture Option

```text
Amazon EKS
  - Python Claim Producer Job
  - Python Rules Engine Deployment
  - Nightly Validation CronJob
  - Log forwarder / monitoring agent

Amazon MSK
  - Kafka topic: claim-events

Amazon RDS PostgreSQL
  - claims_report
  - claim_processing_audit
  - job_status
  - dmr_requests

Amazon ECR
  - Docker images for Python services

AWS Secrets Manager
  - DB credentials and Kafka connection settings

Splunk
  - Error, warning, elapsed-time, and failure logs

CloudWatch
  - AWS service logs and baseline EKS/container visibility
```

---

## 6. Core Components

### 6.1 Claim Producer

The producer generates claim events and publishes them to Kafka.

Example valid claim:

```json
{
  "claimId": "CLM1001",
  "memberId": "M123",
  "procedureCode": "A0428",
  "claimStatus": "PENDING",
  "triggerProcNbr": "TP100",
  "amount": 450.75,
  "eventTime": "2026-07-01T10:30:00"
}
```

Example invalid claim:

```json
{
  "claimId": "CLM1002",
  "memberId": "M124",
  "procedureCode": "A0428",
  "claimStatus": "PENDING",
  "amount": 300.00,
  "eventTime": "2026-07-01T10:35:00"
}
```

The second event is missing `triggerProcNbr`, which should trigger a controlled rule failure.

---

### 6.2 Kafka

Kafka is used for claim event ingestion.

POC topic:

```text
claim-events
```

Interview explanation:

> Amazon MSK is used to ingest claim events through Kafka. The Python rules engine consumes events from Kafka, processes them, and stores results in Amazon RDS PostgreSQL for reporting, audit, and reconciliation.

---

### 6.3 Python Rules Engine

The Python rules engine consumes claim events and applies payment integrity rules.

Example rules:

| Rule | Logic |
|---|---|
| Required field validation | `claimId`, `procedureCode`, `claimStatus`, and `triggerProcNbr` must exist |
| High amount review | If amount is greater than 1000, mark claim for review |
| Invalid status validation | Claim status must be valid |
| Procedure code edit | Certain procedure codes trigger prepay edit |
| Missing field error | Missing required fields generate controlled rule failure |

Example rule result:

```json
{
  "claimId": "CLM1002",
  "ruleStatus": "FAILED",
  "errorType": "KeyError",
  "errorField": "triggerProcNbr",
  "message": "Missing required field triggerProcNbr",
  "processedAt": "2026-07-01T11:00:00"
}
```

Interview explanation:

> The Python rules engine evaluates incoming claims against payment integrity rules. If required fields are missing, the engine logs controlled failures such as `KeyError` and stores failure details for analysis and reporting.

---

### 6.4 PostgreSQL / Amazon RDS

PostgreSQL is used as the final reporting, processing audit, and reconciliation store. This keeps the Phase 1 AWS version simpler than running a second database.

Example tables:

```sql
CREATE TABLE claims_report (
    id SERIAL PRIMARY KEY,
    claim_id VARCHAR(50),
    member_id VARCHAR(50),
    procedure_code VARCHAR(50),
    claim_status VARCHAR(50),
    rule_status VARCHAR(50),
    edit_applied BOOLEAN,
    amount NUMERIC(12,2),
    processed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

```sql
CREATE TABLE claim_processing_audit (
    id SERIAL PRIMARY KEY,
    claim_id VARCHAR(50),
    kafka_topic VARCHAR(100),
    kafka_partition INT,
    kafka_offset BIGINT,
    rule_status VARCHAR(50),
    error_type VARCHAR(100),
    error_field VARCHAR(100),
    message TEXT,
    raw_claim JSONB,
    processed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

```sql
CREATE TABLE job_status (
    id SERIAL PRIMARY KEY,
    job_name VARCHAR(100),
    job_type VARCHAR(50),
    status VARCHAR(50),
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    error_count INT,
    warning_count INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

```sql
CREATE TABLE dmr_requests (
    id SERIAL PRIMARY KEY,
    claim_id VARCHAR(50),
    issue_type VARCHAR(100),
    source_system VARCHAR(50),
    description TEXT,
    status VARCHAR(30),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);
```

Interview explanation:

> PostgreSQL is used for reporting, audit, and reconciliation. I store processed claim results, Kafka processing metadata, job status, and DMR requests in RDS so the validation job can identify missing outputs, stale records, duplicate records, mismatches, and failed processing.

---

## 7. DMR-Style Workflow

In this POC, DMR means **Data Correction / Reprocessing Request**.

A DMR record is created when the nightly validation job finds data issues.

### DMR Scenarios

| Scenario | Example | Action |
|---|---|---|
| Missing output | Kafka audit shows a claim was consumed, but `claims_report` has no final row | Create DMR to insert/reprocess |
| Data mismatch | Audit status differs from final reporting status | Create DMR to correct impacted record |
| Stale timestamp | SQL record was not refreshed after job execution | Create DMR to reprocess/update stale record |
| Duplicate data | Same claim exists multiple times | Create DMR to remove/correct duplicate |
| Failed processing | Rule engine failure due to missing field | Create DMR after issue confirmation |
| Deployment impact | New deployment caused missing outputs | Create DMR to regenerate impacted data |

---

## 8. Nightly Validation CronJob

The nightly validation job compares PostgreSQL audit, reporting, and DMR data.

Validation checks:

- Claim exists in `claim_processing_audit` but not `claims_report`
- Rule status mismatch between audit and reporting tables
- Old/stale timestamps
- Duplicate claim records
- Failed rules engine records
- Missing output records

Example flow:

```text
Start nightly validation
   ->
Read processed claim audit rows from PostgreSQL
   ->
Read reporting rows from PostgreSQL
   ->
Compare claim count and status
   ->
Detect missing, stale, duplicate, or mismatched data
   ->
Insert DMR request
   ->
Log summary to Splunk/CloudWatch
   ->
End job
```

Kubernetes object:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: nightly-claims-validation
spec:
  schedule: "30 5 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: validation-job
              image: <account-id>.dkr.ecr.us-east-1.amazonaws.com/claims-validation:latest
          restartPolicy: OnFailure
```

---

## 9. Kubernetes / EKS Deployment

Recommended Kubernetes objects:

| Component | Kubernetes Object |
|---|---|
| Python rules engine | Deployment |
| Claim producer | Job |
| Nightly validation | CronJob |
| Rules engine access | Service |
| Application config | ConfigMap |
| Secrets | Kubernetes Secret / AWS Secrets Manager |
| Namespace | `claims-integrity` |

Common commands:

```bash
kubectl get pods -n claims-integrity
kubectl get svc -n claims-integrity
kubectl get jobs -n claims-integrity
kubectl get cronjobs -n claims-integrity
kubectl logs <pod-name> -n claims-integrity
kubectl describe pod <pod-name> -n claims-integrity
```

Interview explanation:

> I deployed the POC to Kubernetes and validated pods, services, jobs, cron jobs, logs, restart counts, and deployment status.

---

## 10. Structured Logging

All services should log in JSON format so logs can be searched easily in Splunk or CloudWatch.

Example error log:

```json
{
  "timestamp": "2026-07-01T11:05:00",
  "level": "ERROR",
  "claimId": "CLM1002",
  "jobName": "rules-engine",
  "errorType": "KeyError",
  "errorField": "triggerProcNbr",
  "environment": "dev",
  "message": "Missing required field triggerProcNbr"
}
```

Example elapsed job log:

```json
{
  "timestamp": "2026-07-01T05:45:00",
  "level": "INFO",
  "jobName": "nightly-validation",
  "eventType": "Elapsed",
  "elapsedSeconds": 145,
  "processedClaims": 500,
  "dmrCreated": 7,
  "environment": "dev"
}
```

---

## 11. Splunk Queries

### 11.1 Find Errors

```spl
index=claims_integrity "ERROR"
| fields timestamp, claimId, jobName, errorType, errorField, message
```

### 11.2 Group Errors by Field

```spl
index=claims_integrity "ERROR"
| stats count by errorField
| sort -count
```

### 11.3 Count Unique Impacted Claims

```spl
index=claims_integrity "ERROR"
| stats dc(claimId) as unique_claims by errorType, errorField
| sort -unique_claims
```

### 11.4 Find Warnings

```spl
index=claims_integrity "WARNING"
| stats count by jobName
```

### 11.5 Find Elapsed Jobs

```spl
index=claims_integrity "Elapsed"
| stats avg(elapsedSeconds), max(elapsedSeconds), count by jobName
```

### 11.6 DMR Summary

```spl
index=claims_integrity "DMR_CREATED"
| stats count by issueType
| sort -count
```

Interview explanation:

> In Splunk, I focus on grouping errors by pattern, not just raw count. For example, 360 errors may be one repeated missing-field issue rather than 360 unique failures.

---

## 12. CloudWatch / Observability

CloudWatch Container Insights can be used for baseline AWS and EKS observability:

- Application health
- Service health
- Pod/container metrics
- Failure rate
- Response time
- Dependency issues
- Restart count
- CPU and memory usage
- Kubernetes workload status

Interview explanation:

> Splunk helps identify and group application log errors. CloudWatch provides AWS-native baseline visibility for EKS, containers, service health, failure rate, restart count, and infrastructure signals.

---

## 13. Rancher

Rancher or Rancher Desktop can be used to manage Kubernetes workloads.

Use it to view:

- Namespace
- Pods
- Deployments
- Services
- Jobs
- CronJobs
- Logs
- Restart count
- Workload health

Interview explanation:

> Rancher is a Kubernetes management tool. In the POC, I use it to validate workloads visually, similar to checking pod and job health in a platform dashboard.

---

## 14. Implementation Phases

### Phase 1 - Local Code + AWS Infrastructure Foundation

Build code locally, but run the heavy infrastructure in AWS:

- Python producer
- Python rules engine
- Amazon MSK Kafka topic
- Amazon RDS PostgreSQL schema
- Amazon ECR repositories
- Basic EKS namespace and workload manifests

Goal:

- Validate claim event publishing to Kafka
- Validate rules engine consumption from Kafka
- Store processed claim data in RDS PostgreSQL
- Keep the laptop as the control/development machine only

### Phase 2 - Rules and DMR Logic

Add:

- Required field validation
- High amount rule
- Invalid status rule
- Procedure code edit rule
- `claim_processing_audit` table
- `dmr_requests` table
- Nightly validation script

Goal:

- Simulate missing, mismatched, stale, duplicate, and failed data scenarios

### Phase 3 - EKS Kubernetes Deployment

Deploy to Kubernetes:

- Rules engine Deployment
- Producer Job
- Validation CronJob
- ConfigMaps
- Secrets
- ServiceAccount / IAM integration if needed

Goal:

- Demonstrate EKS, pods, deployments, jobs, cron jobs, config, secrets, logs, and workload troubleshooting

### Phase 4 - AWS Managed Services Integration

Integrate AWS services:

- Amazon EKS
- Amazon MSK
- Amazon RDS PostgreSQL
- Amazon ECR
- AWS Secrets Manager
- CloudWatch baseline logs/metrics

Goal:

- Demonstrate AWS-native deployment and managed service integration

### Phase 5 - Splunk Monitoring

Add:

- Structured JSON logs
- Splunk log ingestion
- Splunk dashboards and saved searches
- Error grouping
- DMR reporting
- CloudWatch retained for AWS-native baseline visibility

Goal:

- Demonstrate production monitoring and troubleshooting readiness

---

## 15. Cost-Safe Build Option

To reduce AWS cost:

| Expensive Option | Cost-Safe Option |
|---|---|
| Long-running EKS cluster | Create only during build/test windows, then destroy |
| Large MSK cluster | Use the smallest practical MSK configuration for the POC |
| Multi-AZ production RDS | Use small dev RDS instance for demo only |
| Splunk Enterprise always-on | Use trial/dev Marketplace option only when testing dashboards |
| Full AWS all day | Terraform destroy when not actively using the POC |

Recommended approach:

1. Build Python code locally
2. Provision AWS infra with Terraform
3. Deploy app workloads to EKS
4. Test MSK -> rules engine -> RDS flow
5. Send structured logs to Splunk
6. Destroy non-needed AWS resources after testing

---

## 16. GitHub Repository Structure

```text
claims-integrity-poc/
  README.md
  PUBLIC_REPO_SAFETY.md
  requirements.txt
  .env.example
  producer/
    Dockerfile
    producer.py
    requirements.txt
  rules-engine/
    Dockerfile
    app.py
    rules.py
    requirements.txt
  validation-job/
    Dockerfile
    validate.py
    requirements.txt
  infra/
    main.tf
    variables.tf
    outputs.tf
    eks.tf
    msk.tf
    rds.tf
    ecr.tf
    secrets.tf
  k8s/
    namespace.yaml
    rules-engine-deployment.yaml
    producer-job.yaml
    validation-cronjob.yaml
    configmap.yaml
    secrets.example.yaml
    serviceaccount.yaml
  sql/
    schema.sql
    sample_queries.sql
  docs/
    architecture.md
    interview-notes.md
    troubleshooting.md
```

---

## 17. Interview Talking Points

### Short Summary

> I built a claims payment integrity monitoring POC that simulates a PISCES-like workflow. Claim events are ingested through Amazon MSK Kafka, processed by a Python rules engine deployed on EKS, and persisted to Amazon RDS PostgreSQL for reporting, audit, and reconciliation. I used Kubernetes Jobs, Deployments, and CronJobs for producer, rules engine, and nightly validation workloads. The validation job creates DMR-style records for missing, mismatched, stale, duplicate, or failed records. I also added structured logs for Splunk-based troubleshooting while retaining CloudWatch for AWS-native baseline visibility.

### What This Demonstrates

- Amazon MSK Kafka ingestion
- Python rules engine development
- EKS Kubernetes deployment
- Kubernetes Job, Deployment, and CronJob usage
- RDS PostgreSQL audit and reporting validation
- Production support mindset
- Splunk log analysis
- CloudWatch AWS/EKS baseline observability
- DMR-style data correction workflow
- AWS architecture understanding

---

## 18. Troubleshooting Scenarios to Demo

### Scenario 1 - Missing Field

Input claim missing `triggerProcNbr`.

Expected result:

- Rules engine logs `KeyError`
- `claim_processing_audit` stores failed rule result
- Final reporting row may not be created
- Nightly validation creates DMR

### Scenario 2 - Audit to Reporting Mismatch

`claim_processing_audit` has rule status `FAILED`, but `claims_report` has `APPROVED`.

Expected result:

- Validation job detects mismatch
- DMR created with issue type `DATA_MISMATCH`
- Error summary logged

### Scenario 3 - Stale Timestamp

SQL record has old `processed_at`.

Expected result:

- Validation job detects stale timestamp
- DMR created with issue type `STALE_TIMESTAMP`

### Scenario 4 - Duplicate Claim

Same claim appears multiple times in SQL.

Expected result:

- Validation job detects duplicate
- DMR created with issue type `DUPLICATE_RECORD`

### Scenario 5 - Job Failure

Nightly validation job fails.

Expected result:

- Kubernetes job status shows failed
- Logs show error
- Splunk query identifies failure
- CloudWatch shows baseline workload/service issue signals

---

## 19. Strong Interview Answer

Use this answer when explaining your POC:

> I designed this POC as a payment integrity claims processing platform. It uses Amazon MSK for Kafka-based claim ingestion, a Python rules engine deployed on Amazon EKS for payment integrity edits, and Amazon RDS PostgreSQL for final reporting, audit, and reconciliation. I deployed the producer as a Kubernetes Job, the rules engine as a Deployment, and nightly validation as a CronJob. The validation job compares audit and reporting tables and creates DMR-style records for missing data, mismatches, stale timestamps, duplicate records, or failed rule processing. I also added structured JSON logs so issues can be analyzed in Splunk, while CloudWatch remains available for AWS-native service and EKS baseline observability.

---

## 20. Next Improvements

Future enhancements:

- Add REST API for DMR review and closure
- Add UI dashboard for job status and DMR records
- Add automated reprocessing flow
- Add Kafka retry and dead-letter topic
- Add OpenTelemetry tracing
- Add CI/CD pipeline using GitHub Actions or GitLab CI
- Add Helm chart for Kubernetes deployment
- Add Terraform for AWS infrastructure
- Add alerting for high failure rate or stale data



