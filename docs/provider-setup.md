# Provider Setup Guide

This guide explains how to configure each supported deployment provider for consumer repositories.

---

## Provider Selection

Set the `DEPLOY_PROVIDER` repository variable in GitHub to one of:

| Value | Provider |
|---|---|
| `k8s` | Kubernetes (default) |
| `azure` | Azure App Service / AKS |
| `aws` | AWS ECS / EKS |
| `vercel` | Vercel |
| `generic` | Generic shell deploy script |

---

## Kubernetes (k8s)

### Required Secrets
| Secret | Description |
|---|---|
| `KUBECONFIG_DATA` | Base64-encoded kubeconfig file |

### Optional Config (`config.<Env>.json`)
```json
{
  "namespace":  "my-app-prod",
  "manifest":   "./k8s/Prod",
  "deployment": "my-app",
  "imageTag":   "latest"
}
```

### Setup Steps
1. Encode your kubeconfig: `base64 -w0 ~/.kube/config`
2. Add `KUBECONFIG_DATA` as a GitHub Secret
3. Create Kubernetes manifests in `./k8s/<Env>/`
4. Set `DEPLOY_PROVIDER = k8s` as a repository variable

---

## Azure

### Required Secrets
| Secret | Description |
|---|---|
| `AZURE_CREDENTIALS` | Service principal JSON from `az ad sp create-for-rbac` |

### Optional Config
```json
{
  "azureResourceGroup": "my-rg-prod",
  "deployment": "my-app"
}
```

### Setup Steps
1. Create a service principal:
   ```bash
   az ad sp create-for-rbac --name "smsdao-deploy" \
     --role contributor \
     --scopes /subscriptions/<id>/resourceGroups/<rg> \
     --sdk-auth
   ```
2. Add the output JSON as `AZURE_CREDENTIALS` GitHub Secret
3. Set `DEPLOY_PROVIDER = azure`

---

## AWS

### Required Secrets
| Secret | Description |
|---|---|
| `AWS_ROLE_ARN` | IAM Role ARN for OIDC federation |

### Repository Variables
| Variable | Description |
|---|---|
| `AWS_REGION` | AWS region (e.g., `us-east-1`) |

### Setup Steps
1. Create an IAM role with OIDC trust for `token.actions.githubusercontent.com`
2. Add the role ARN as `AWS_ROLE_ARN` GitHub Secret
3. Set `DEPLOY_PROVIDER = aws` and `AWS_REGION` as repository variables

---

## Vercel

### Required Secrets
| Secret | Description |
|---|---|
| `VERCEL_TOKEN` | Personal access token from Vercel dashboard |

### Optional Config
```json
{
  "vercelEnv": "production",
  "project": "my-app"
}
```

### Setup Steps
1. Create a token at https://vercel.com/account/tokens
2. Add `VERCEL_TOKEN` as a GitHub Secret
3. Set `DEPLOY_PROVIDER = vercel`

---

## Generic

The `generic` provider runs `./scripts/deploy.sh` (or `./deploy.ps1` if present) with environment variables set.

```bash
# scripts/deploy.sh
#!/bin/bash
set -e
echo "Deploying to $DEPLOY_ENV..."
# custom deploy logic here
```

No secrets are required by the platform — inject your own via GitHub Secrets.
