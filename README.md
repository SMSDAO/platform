# SMSDAO/platform

> **Organization-wide CI/CD Automation Platform** — One pipeline, 109+ repos, zero duplication.

[![Platform Tests](https://github.com/SMSDAO/platform/actions/workflows/platform-test.yml/badge.svg)](https://github.com/SMSDAO/platform/actions/workflows/platform-test.yml)
[![Module Lint](https://github.com/SMSDAO/platform/actions/workflows/module-lint.yml/badge.svg)](https://github.com/SMSDAO/platform/actions/workflows/module-lint.yml)
[![Security Scan](https://github.com/SMSDAO/platform/actions/workflows/security-scan.yml/badge.svg)](https://github.com/SMSDAO/platform/actions/workflows/security-scan.yml)

---

## What Is This?

`SMSDAO/platform` is the central CI/CD backbone for the entire SMSDAO organization. Every DAO project repository — from Next.js frontends and Solidity contracts to .NET services and Tauri desktop apps — calls a single reusable GitHub Actions workflow defined here. Pipeline logic lives in one place; consumer repos hold only a thin `ci.yml` that delegates everything to this platform.

### Key Capabilities

| Capability | Description |
|---|---|
| **Multi-stack detection** | Auto-classifies repos as `nextjs`, `node`, `electron`, `dotnet`, `solidity`, `tauri`, or `generic` |
| **Multi-cloud deploy** | Supports `k8s`, `azure`, `aws`, `vercel`, and `generic` script providers |
| **DAO governance** | Policy engine enforces workflow permissions, approved Actions allowlist, secret detection, and branch protection |
| **Heal protocol** | 9-step non-destructive healing pipeline for repos in degraded state |
| **Structured logging** | JSON-mode logging for CI; human-readable mode for local development |
| **PR comment system** | Automatic, atomic PR comment updates for every pipeline event |

---

## Quick Start

### For Consumer Repos (DAO Projects)

Copy one file into your repository:

```yaml
# .github/workflows/ci.yml  (the ONLY workflow file you need)
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
    types: [opened, synchronize, reopened]
  workflow_dispatch:

jobs:
  pipeline:
    uses: SMSDAO/platform/.github/workflows/smart-pipeline.yml@v1
    secrets: inherit
```

That's it. The platform auto-detects your repo type and runs the appropriate Build → Test → Deploy chain.

### For Platform Development

**Prerequisites:** PowerShell 7.0+, Git

```bash
# 1. Clone
git clone https://github.com/SMSDAO/platform.git
cd platform

# 2. Install dependencies (Pester, PSScriptAnalyzer, powershell-yaml)
pwsh ./scripts/install-dependencies.ps1

# 3. Run all tests
pwsh -Command "Invoke-Pester ./tests/ -Output Normal"

# 4. Run a pipeline phase locally (dry-run)
pwsh ./bin/pipeline.ps1 -Phase Build -Env Dev -DryRun
```

---

## Repository Structure

```
SMSDAO/platform
├── bin/
│   └── pipeline.ps1              ← Thin consumer-facing entry point
├── src/
│   ├── orchestrator/
│   │   └── pipeline-core.psm1   ← Central dispatcher + boot sequence
│   ├── phases/
│   │   ├── build.psm1           ← Build logic (all repo types)
│   │   ├── test.psm1            ← Test + lint runner
│   │   ├── deploy.psm1          ← Deploy phase coordinator
│   │   ├── heal.psm1            ← 9-step healing protocol
│   │   └── validate-env.psm1    ← Environment safety checks
│   ├── security/
│   │   └── policy-engine.psm1   ← DAO governance enforcement
│   ├── providers/
│   │   └── providers.psm1       ← k8s | azure | aws | vercel | generic
│   ├── reporting/
│   │   ├── pr-comment.psm1      ← Atomic PR comment factory
│   │   └── summary-builder.psm1 ← Aggregate summary generator
│   └── utils/
│       ├── logger.psm1          ← Structured logging
│       ├── repo-detect.psm1     ← Stack classifier → RepoProfile
│       ├── json-tools.psm1      ← Config loader (precedence chain)
│       └── file-scan.psm1       ← Regex pattern scanner
├── tests/
│   ├── unit/                    ← Per-module unit tests (Pester 5)
│   └── integration/             ← End-to-end scenario tests
├── config/
│   ├── templates/               ← consumer-ci.yml, config.*.json
│   └── schemas/                 ← JSON Schema for config validation
├── docs/                        ← Project documentation
├── scripts/
│   └── install-dependencies.ps1 ← Developer bootstrap script
└── .github/
    └── workflows/
        ├── smart-pipeline.yml   ← Reusable workflow (called by 109+ repos)
        ├── platform-test.yml    ← Platform self-test CI
        ├── module-lint.yml      ← PSScriptAnalyzer + syntax check
        └── security-scan.yml    ← Security policy scan
```

---

## Running Tests

```powershell
# All tests (unit + integration)
Invoke-Pester ./tests/ -Output Normal

# Unit tests only
Invoke-Pester ./tests/unit/ -Output Normal

# Integration tests only
Invoke-Pester ./tests/integration/ -Output Normal

# With JUnit XML output (for CI)
$cfg = New-PesterConfiguration
$cfg.Run.Path = "./tests"
$cfg.TestResult.Enabled = $true
$cfg.TestResult.OutputPath = "./TestResults/all.xml"
$cfg.TestResult.OutputFormat = "NUnitXml"
Invoke-Pester -Configuration $cfg
```

All tests run in **DryRun** mode — no network calls, no file system side effects outside `$TestDrive`.

---

## Pipeline Commands

```powershell
# Detect repo type
./bin/pipeline.ps1 -Phase DetectRepo -Env Dev

# Validate environment safety
./bin/pipeline.ps1 -Phase ValidateEnv -Env Dev

# Run DAO governance policy check
./bin/pipeline.ps1 -Phase Policy -Env Dev

# Build
./bin/pipeline.ps1 -Phase Build -Env Dev
./bin/pipeline.ps1 -Phase Build -Env Prod

# Test
./bin/pipeline.ps1 -Phase Test -Env Dev

# Deploy (requires provider config)
./bin/pipeline.ps1 -Phase Deploy -Env Staging

# Full pipeline (Build → Test → Deploy)
./bin/pipeline.ps1 -Phase Full -Env Prod

# 9-step heal protocol
./bin/pipeline.ps1 -Phase Heal -Env Dev

# Any command with DryRun (prints actions without executing)
./bin/pipeline.ps1 -Phase Full -Env Prod -DryRun
```

---

## Configuration

Environment-specific config files live in the consumer repo root (not in platform):

```jsonc
// config.Dev.json
{
  "environment": "Dev",
  "logLevel": "Debug",
  "testPath": "./tests",
  "namespace": "dev",
  "manifest": "./k8s/Dev",
  "awsRegion": "us-east-1"
}
```

**Config precedence** (highest → lowest):
1. `CustomArgs` (GitHub Secrets injected at runtime)
2. `config.<Env>.json` in repo root
3. Hardcoded platform defaults

Secrets are **never** stored in config files. Use GitHub Repository Secrets and pass them via `CustomArgs`.

---

## Supported Stacks

| Stack | Detection Signal | Build Command |
|---|---|---|
| `nextjs` | `next.config.*` present | `npm ci && npm run build` |
| `node` | `package.json` present | `npm ci && npm run build` |
| `electron` | `package.json` with `"electron"` dep | `npm ci && npm run build` |
| `tauri` | `src-tauri/` directory present | `npm ci && npm run tauri build` |
| `solidity` | `hardhat.config.*` present | `npm ci && npx hardhat compile` |
| `dotnet` | `*.csproj` present | `dotnet build --configuration Release` |
| `generic` | catch-all | `npm ci && npm run build` |

---

## Supported Deploy Providers

| Provider | Config Key | Required Args |
|---|---|---|
| `k8s` | `"provider": "k8s"` | `namespace`, `manifest`, `deployment` |
| `azure` | `"provider": "azure"` | `resourceGroup`, `appName` |
| `aws` | `"provider": "aws"` | `awsRegion`, `cluster`, `service` |
| `vercel` | `"provider": "vercel"` | `vercelToken` (via Secret) |
| `generic` | `"provider": "generic"` | `deployScript` path |

---

## Documentation

| Document | Description |
|---|---|
| [architecture.md](docs/architecture.md) | System design, module relationships, boot sequence |
| [specs.md](docs/specs.md) | Feature specifications and acceptance criteria |
| [ui.md](docs/ui.md) | PR comment UI, log output formats, UX guidelines |
| [god_swarm.md](docs/god_swarm.md) | God Swarm orchestration pattern and domain model |
| [developer.md](docs/developer.md) | Contributing guide, adding phases and providers |
| [deployment.md](docs/deployment.md) | Platform versioning and release process |
| [security-policies.md](docs/security-policies.md) | DAO security governance details |
| [provider-setup.md](docs/provider-setup.md) | Cloud provider configuration reference |
| [troubleshooting.md](docs/troubleshooting.md) | Common issues and diagnostics |
| [api-reference.md](docs/api-reference.md) | Public function reference for all modules |

---

## Contributing

See [docs/developer.md](docs/developer.md) for the full contributing guide. In brief:

1. Fork and create a feature branch
2. Add or update tests in `tests/unit/` or `tests/integration/`
3. Run `Invoke-Pester ./tests/ -Output Normal` — all tests must pass
4. Run `Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning` — zero errors
5. Open a PR against `main`

---

## License

MIT — see [LICENSE](LICENSE) for details.
