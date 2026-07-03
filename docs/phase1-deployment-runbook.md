# Phase 1 Deployment Runbook

This runbook deploys the Phase 1 smoke test:

```text
Producer Job on EKS -> Amazon MSK -> Rules Engine Deployment on EKS -> Amazon RDS PostgreSQL
```

Keep real values out of Git. Do not commit `.env`, `*.tfvars`, kubeconfigs, Terraform state, or generated secret YAML files.

## 1. Confirm Tools and AWS Identity

```powershell
aws --version
terraform version
kubectl version --client
aws sts get-caller-identity --profile anekur-admin
```

Set the shell for this session:

```powershell
$env:AWS_PROFILE="anekur-admin"
$env:AWS_REGION="us-east-1"
aws sts get-caller-identity
```

## 2. Review Terraform Before Apply

```powershell
Set-Location C:\Workspace\claims_payment_integrity_poc\infra
terraform init
terraform fmt
terraform validate
terraform plan
```

Review the plan carefully. Expect VPC, NAT Gateway, EKS, MSK, RDS, ECR, Secrets Manager, IAM, and CloudWatch resources.

## 3. Apply Terraform

Only run this when you are ready for AWS cost and have time to wait. MSK and EKS can take a while.

```powershell
terraform apply
```

After apply:

```powershell
terraform output
```

## 4. Configure kubectl

```powershell
$clusterName = terraform output -raw eks_cluster_name
aws eks update-kubeconfig --region $env:AWS_REGION --name $clusterName
kubectl get nodes
```

## 5. Capture Runtime Values

```powershell
$producerImage = "$(terraform output -raw producer_ecr_repository_url):latest"
$rulesImage = "$(terraform output -raw rules_engine_ecr_repository_url):latest"
$mskBootstrap = terraform output -raw msk_bootstrap_brokers
$rdsHost = terraform output -raw rds_address
$rdsSecretArn = terraform output -raw rds_secret_arn
$rdsSecret = aws secretsmanager get-secret-value --secret-id $rdsSecretArn --query SecretString --output text | ConvertFrom-Json
```

## 6. Build and Push Images

If Docker is not available on your laptop, use AWS CloudShell, EC2, or another build machine.

```powershell
aws ecr get-login-password --region $env:AWS_REGION | docker login --username AWS --password-stdin ($producerImage -replace "/.*$","")

Set-Location C:\Workspace\claims_payment_integrity_poc
docker build -t $producerImage .\producer
docker push $producerImage

docker build -t $rulesImage .\rules-engine
docker push $rulesImage
```

## 7. Apply Base Kubernetes Manifests

```powershell
Set-Location C:\Workspace\claims_payment_integrity_poc
kubectl apply -f k8s\namespace.yaml
kubectl apply -f k8s\configmap.yaml
```

Create the runtime secret directly from Terraform and Secrets Manager values. Do not write this secret to a tracked file.

```powershell
kubectl create secret generic claims-integrity-secrets `
  --namespace claims-integrity `
  --from-literal=MSK_BOOTSTRAP_SERVERS="$mskBootstrap" `
  --from-literal=RDS_HOST="$rdsHost" `
  --from-literal=RDS_USER="$($rdsSecret.username)" `
  --from-literal=RDS_PASSWORD="$($rdsSecret.password)" `
  --dry-run=client -o yaml | kubectl apply -f -
```

## 8. Initialize Database Schema

Apply `sql/schema.sql` from inside the cluster so the private RDS endpoint is reachable:

```powershell
Get-Content -Raw sql\schema.sql | kubectl run schema-apply `
  --rm -i `
  --restart=Never `
  --namespace claims-integrity `
  --image=postgres:16 `
  --env=PGPASSWORD="$($rdsSecret.password)" `
  -- psql -h "$rdsHost" -U "$($rdsSecret.username)" -d claims_integrity
```

## 9. Create Temporary Smoke-Test Manifests

The committed Kubernetes files keep placeholder images for public repo safety. Create untracked temporary files with the real ECR image URLs:

```powershell
$tmpDir = Join-Path $env:TEMP "claims-integrity-phase1"
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

(Get-Content -Raw k8s\rules-engine-deployment.yaml).Replace(
  "replace-with-terraform-output-rules_engine_ecr_repository_url:latest",
  $rulesImage
) | Set-Content -Path (Join-Path $tmpDir "rules-engine-deployment.yaml") -Encoding UTF8

(Get-Content -Raw k8s\producer-job.yaml).Replace(
  "replace-with-terraform-output-producer_ecr_repository_url:latest",
  $producerImage
) | Set-Content -Path (Join-Path $tmpDir "producer-job.yaml") -Encoding UTF8
```

Do not copy these temporary files back into the repo.

## 10. Deploy Rules Engine

```powershell
kubectl apply -f (Join-Path $tmpDir "rules-engine-deployment.yaml")
kubectl rollout status deployment/rules-engine -n claims-integrity
kubectl logs deployment/rules-engine -n claims-integrity --tail=50
```

## 11. Run Producer Job

If `claim-producer` already exists from a prior run, delete only that completed Job first:

```powershell
kubectl delete job claim-producer -n claims-integrity --ignore-not-found
kubectl apply -f (Join-Path $tmpDir "producer-job.yaml")
kubectl wait --for=condition=complete job/claim-producer -n claims-integrity --timeout=300s
kubectl logs job/claim-producer -n claims-integrity
```

## 12. Verify Database and Logs

Use a temporary PostgreSQL client pod to query the private RDS database:

```powershell
kubectl run psql-check `
  --rm -i `
  --restart=Never `
  --namespace claims-integrity `
  --image=postgres:16 `
  --env=PGPASSWORD="$($rdsSecret.password)" `
  -- psql -h "$rdsHost" -U "$($rdsSecret.username)" -d claims_integrity -c "select count(*) from claim_processing_audit; select count(*) from claims_report;"
```

For Phase 1, validation is complete when:

```text
claim_processing_audit has rows
claims_report has valid claim rows
rules-engine logs a controlled failure for missing triggerProcNbr
```

## 13. Useful Checks

```powershell
kubectl get pods -n claims-integrity
kubectl get jobs -n claims-integrity
kubectl logs deployment/rules-engine -n claims-integrity --tail=100
kubectl describe job claim-producer -n claims-integrity
```

## 14. Cleanup

Destroy the stack when you are done testing to control cost:

```powershell
Set-Location C:\Workspace\claims_payment_integrity_poc\infra
terraform destroy
```
