# AWS Terraform Learning Runbook

This runbook teaches the safe local flow for connecting AWS and running Terraform for this repo.

## 1. Confirm Tools

From the repo root:

```powershell
aws --version
terraform version
```

If either command is not recognized, install that tool first.

## 2. Login to AWS

For learning and local development, AWS SSO is usually the safest option:

```powershell
aws configure sso
aws sso login --profile <profile-name>
```

If you already configured profiles:

```powershell
aws configure list-profiles
aws sts get-caller-identity --profile <profile-name>
```

The identity command should return your AWS account, user or role ARN, and user ID.

## 3. Set Local Session Values

Keep local values in your PowerShell session instead of committing them:

```powershell
$env:AWS_PROFILE="<profile-name>"
$env:AWS_REGION="us-east-1"
```

Verify the active identity:

```powershell
aws sts get-caller-identity
```

## 4. Run Terraform Checks

Terraform files are in `infra`.

```powershell
Set-Location infra
terraform init
terraform fmt -check
terraform validate
terraform plan -var "aws_region=$env:AWS_REGION"
```

Read the plan before applying. The plan tells you what AWS resources Terraform wants to create, change, or destroy.

## 5. Apply Only When Ready

Only run apply after you understand the plan:

```powershell
terraform apply -var "aws_region=$env:AWS_REGION"
```

After apply:

```powershell
terraform output
```

## 6. Destroy When You Are Done Testing

Destroying deletes the Terraform-managed AWS resources:

```powershell
terraform destroy -var "aws_region=$env:AWS_REGION"
```

Review the destroy plan carefully before confirming.

## Common Fixes

| Error | What it usually means | Next command |
| --- | --- | --- |
| `No valid credential sources found` | AWS credentials are missing or expired | `aws sso login --profile <profile-name>` |
| `The config profile could not be found` | Wrong profile name | `aws configure list-profiles` |
| `AccessDenied` | AWS login works, but IAM permissions are missing | Check the role/user permissions |
| `InvalidClientTokenId` | Credentials are stale or invalid | Re-login to AWS |
| Terraform version error | Terraform is older than this repo requires | `terraform version` |

## Public Repo Safety

Do not commit:

- `.env`
- `*.tfvars`
- `.terraform/`
- `*.tfstate`
- AWS credentials or SSO cache files
- kubeconfigs
- private keys
- real AWS account IDs, ARNs, tokens, passwords, or endpoints

Before pushing:

```powershell
rg -n -i "AKIA|ASIA|secret|password|token|private key|BEGIN .* KEY|arn:aws|[0-9]{12}" .
git status --short
```
