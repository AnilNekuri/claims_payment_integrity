# Claims Payment Integrity Monitoring POC

Cloud-native POC for claims payment integrity monitoring. Phase 1 builds the local application code and public-safe AWS foundation for a Kafka -> Python rules engine -> PostgreSQL flow.

## Tech Stack

- Python 3.11
- Kafka / Amazon MSK
- PostgreSQL / Amazon RDS
- Docker
- Kubernetes / Amazon EKS
- Amazon ECR
- AWS Secrets Manager
- Terraform
- Splunk-ready JSON logs
- CloudWatch-ready container logs

## Phase 1 Scope

- Generate sample claim events with a Python producer.
- Publish events to Kafka topic `claim-events`.
- Consume events with a Python rules engine.
- Apply basic claim validation and rule status logic.
- Store processed records in PostgreSQL tables.
- Provide Dockerfiles, Kubernetes manifests, SQL schema, and Terraform starter files.

## Local Setup

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
```

Update `.env` with local or AWS dev values. Do not commit `.env`.

## Run Locally

The producer and rules engine expect Kafka and PostgreSQL to be available.

```powershell
python producer\producer.py
python rules-engine\app.py
```

## Database

Apply the PostgreSQL schema before running the rules engine:

```powershell
psql -h <host> -U <user> -d claims_integrity -f sql\schema.sql
```

## Public Repo Safety

This repo should only contain placeholder values, templates, source code, and sample data. Real AWS endpoints, credentials, Splunk tokens, kubeconfigs, Terraform state, and `.env` files must stay out of Git.
