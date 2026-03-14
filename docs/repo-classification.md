# Repository Classification: SMSDAO/platform

## Classification: DEV_TOOLING (Infrastructure Platform)

| Field | Value |
|---|---|
| **Category** | DevOps Infrastructure Platform |
| **Core Function** | Multi-repository CI/CD orchestration |
| **Technology** | PowerShell automation platform |
| **Governance** | DAO-level policy engine |
| **Runtime** | PowerShell 7.0+ |
| **Execution Context** | GitHub Actions (ubuntu-latest) |

---

## Technology Stack

| Layer | Technology |
|---|---|
| Scripting | PowerShell 7.0+ |
| CI/CD | GitHub Actions (reusable workflows) |
| Infrastructure | Kubernetes, Azure, AWS, Vercel |
| Security | Custom policy engine (no GitHub App required) |
| Reporting | GitHub PR comment API |

---

## Supported Repository Types

| Type | Detection Heuristic | Build Tool |
|---|---|---|
| `nextjs` | `next` in `package.json` dependencies | `npm run build` |
| `node` | `package.json` present | `npm run build` |
| `electron` | `electron` in dependencies | `npm run build` |
| `dotnet` | `*.csproj` or `*.sln` present | `dotnet build` |
| `solidity` | `hardhat.config.*` or `*.sol` files | `hardhat compile` |
| `tauri` | `src-tauri/` directory | `npm run tauri build` |
| `generic` | fallback | `npm run build` |

---

## Supported Deployment Providers

| Provider | Config Key | Required Secrets |
|---|---|---|
| Kubernetes | `k8s` | `KUBECONFIG_DATA` |
| Azure | `azure` | `AZURE_CREDENTIALS` |
| AWS | `aws` | `AWS_ROLE_ARN` |
| Vercel | `vercel` | `VERCEL_TOKEN` |
| Generic | `generic` | — |

---

## Environment Tiers

| Tier | Branch | Purpose |
|---|---|---|
| `Dev` | `*` (all others) | Development + PR validation |
| `Staging` | `develop` | Pre-production integration |
| `Prod` | `main` | Production deployment |

---

## Security Classification

- **Threat Detection**: 9 secret patterns across 8 categories (hardcoded-password, openai-key, aws-access-key, github-pat, slack-token, private-key, api-key, hardcoded-rpc × 2)
- **Governance**: DAO-level policy enforcement via `policy-engine.psm1`
- **Secret Handling**: Secrets injected via GitHub Secrets → `CustomArgs`, never stored in config files
- **Workflow Auditing**: Validates workflow permissions, unapproved Actions, branch protections
- **Compliance**: PRODUCTION_READY with HIGH_GOVERNANCE security posture

---

## Module Dependency Graph

```
bin/pipeline.ps1
└── src/orchestrator/pipeline-core.psm1
    ├── src/utils/logger.psm1
    ├── src/utils/repo-detect.psm1
    ├── src/utils/json-tools.psm1
    ├── src/reporting/pr-comment.psm1
    ├── src/reporting/summary-builder.psm1
    ├── src/phases/build.psm1
    ├── src/phases/test.psm1
    ├── src/phases/deploy.psm1
    ├── src/phases/heal.psm1
    ├── src/phases/validate-env.psm1
    └── src/security/policy-engine.psm1
        └── src/utils/file-scan.psm1
```

---

## Consumer Integration

Consumer repositories need **only one file**: `config/templates/consumer-ci.yml`

```yaml
jobs:
  pipeline:
    uses: SMSDAO/platform/.github/workflows/smart-pipeline.yml@v1
    secrets: inherit
```

No other platform files are required in consumer repositories.
