# Public Repo Safety Checklist

This POC is designed to be safe for a public GitHub repository when only templates, examples, and source code are committed.

## Safe to Commit

- Source code
- Dockerfiles
- Kubernetes manifests with placeholders only
- Terraform modules and variables with no real values
- `.env.example`
- Architecture docs and interview notes
- SQL schema and sample queries

## Do Not Commit

- `.env`
- AWS credentials or SSO cache files
- Terraform state files
- `*.tfvars` with real values
- Kubernetes secret manifests with real secrets. Commit `*.example.yaml` only.
- kubeconfig files
- Private keys or certificates
- Real AWS account IDs, ARNs, endpoints, passwords, or tokens
- Splunk HEC tokens
- Generated claim data if it contains real or sensitive data

## Before Pushing

Run these checks from the repo root:

```powershell
rg -n -i "AKIA|ASIA|secret|password|token|private key|BEGIN .* KEY|arn:aws|[0-9]{12}" .
git status --short
```

Expected result: only placeholder/example references should appear.

## Terraform Rule

Commit Terraform source files and the provider lock file, but never commit local state or real environment values:

```text
Commit:     infra/*.tf, .terraform.lock.hcl
Do not:     *.tfstate, *.tfvars, .terraform/
```

## Kubernetes Rule

Commit manifests that reference secrets by name, not files containing real secret values.

Use placeholders or generated examples for public documentation.
