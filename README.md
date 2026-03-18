# SMSDAO/platform

> **Organization-wide CI/CD Automation Platform** — One pipeline, 109+ repos, zero duplication. Now with a full **Flash Glow Neo** web dashboard.

[![Platform Tests](https://github.com/SMSDAO/platform/actions/workflows/platform-test.yml/badge.svg)](https://github.com/SMSDAO/platform/actions/workflows/platform-test.yml)
[![Module Lint](https://github.com/SMSDAO/platform/actions/workflows/module-lint.yml/badge.svg)](https://github.com/SMSDAO/platform/actions/workflows/module-lint.yml)
[![Security Scan](https://github.com/SMSDAO/platform/actions/workflows/security-scan.yml/badge.svg)](https://github.com/SMSDAO/platform/actions/workflows/security-scan.yml)
[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/SMSDAO/platform&root=web)

---

## 🌟 Flash Glow Neo Web App

A full-stack, mobile-optimized web dashboard built with **Next.js 15**, **Tailwind CSS**, and a custom **Flash Glow Neo** design system — featuring glassmorphism cards, neon glow effects, and role-based access control.

### UI Screenshots

| Landing Page | Register |
|---|---|
| ![Landing Page](https://github.com/user-attachments/assets/00c0ce16-f7ef-4c40-94b4-484c846a9e3c) | ![Register](https://github.com/user-attachments/assets/6341b175-9c20-4d85-89b3-51a43a768ab1) |

| Dashboard | Admin Panel |
|---|---|
| ![Dashboard](https://github.com/user-attachments/assets/e24cc913-8673-4709-a584-6827227b5618) | ![Admin Panel](https://github.com/user-attachments/assets/3cfdb94a-0568-4b86-a10e-022cc678b8fb) |

| Developer Panel | Profile |
|---|---|
| ![Developer Panel](https://github.com/user-attachments/assets/4784249c-432b-4722-b288-c38be21f101a) | ![Profile](https://github.com/user-attachments/assets/6302b6bb-300e-4ee7-8459-079a99c04223) |

### Web App Quick Start

```bash
cd web
npm install
cp .env.example .env        # then fill in NEXTAUTH_SECRET
npm run db:push             # initialize SQLite schema
npm run db:seed             # create demo users
npm run dev                 # http://localhost:3000
```

**Demo credentials:**

| Email | Password | Role |
|---|---|---|
| `admin@admin.com` | `admin123` | Admin |
| `dev@admin.com` | `developer123` | Developer |

### One-Click Vercel Deploy

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/SMSDAO/platform&root=web)

Set these environment variables in Vercel:

| Variable | Description |
|---|---|
| `DATABASE_URL` | `file:./dev.db` (SQLite) or a Postgres connection string |
| `NEXTAUTH_SECRET` | Any long random string (e.g. `openssl rand -base64 32`) |
| `NEXTAUTH_URL` | Your Vercel deployment URL, e.g. `https://your-app.vercel.app` |

### Role-Based Access Control

| Route | User | Admin | Developer |
|---|---|---|---|
| `/` | ✅ | ✅ | ✅ |
| `/auth/login` | ✅ | ✅ | ✅ |
| `/dashboard` | ✅ | ✅ | ✅ |
| `/profile` | ✅ | ✅ | ✅ |
| `/dashboard/admin` | ❌ | ✅ | ✅ |
| `/dashboard/dev` | ❌ | ❌ | ✅ |

### Flash Glow Neo Design System

The `web/` app uses a custom Tailwind extension with neon utility classes:

| Class | Effect |
|---|---|
| `.glow-cyan` | Cyan box-shadow glow (`#00d4ff`) |
| `.glow-purple` | Purple box-shadow glow (`#a855f7`) |
| `.glow-green` | Green box-shadow glow (`#00ff88`) |
| `.text-glow-cyan` | Cyan text-shadow neon glow |
| `.glass` | Glassmorphism — `backdrop-blur` + semi-transparent bg |
| `.glass-dark` | Darker glass variant |
| `.gradient-border` | Animated gradient border (cyan → purple → green) |
| `.neon-grid` | Subtle dot-grid background pattern |

All custom tokens are declared in `web/tailwind.config.js` under `theme.extend.colors`:
- `neon-cyan`: `#00d4ff`
- `neon-purple`: `#a855f7`
- `neon-green`: `#00ff88`
- `dark-base`: `#0a0a0f`
- `dark-card`: `#0f0f1a`
- `dark-border`: `#1a1a2e`

### Web App Tech Stack

| Layer | Technology |
|---|---|
| Framework | Next.js 15 (App Router) |
| Styling | Tailwind CSS v3 + custom Flash Glow Neo utilities |
| Auth | NextAuth.js v4 (Credentials + JWT) |
| Database | Prisma ORM + SQLite (swap to Postgres for production) |
| Icons | Lucide React |
| Animations | Framer Motion |
| Password hashing | bcryptjs |

### Web App Directory Structure

```
web/
├── vercel.json                     # One-click Vercel deploy config
├── prisma/
│   ├── schema.prisma               # User model with role field
│   └── seed.ts                     # Creates admin + developer demo users
└── src/
    ├── app/
    │   ├── page.tsx                # Landing page (public)
    │   ├── auth/login/             # Login page
    │   ├── auth/register/          # Register page + POST /api/auth/register
    │   ├── dashboard/              # Main dashboard (User/Admin/Dev)
    │   ├── dashboard/admin/        # Admin panel (Admin + Dev only)
    │   ├── dashboard/dev/          # Developer panel (Dev only)
    │   ├── profile/                # Profile & permissions view
    │   └── api/auth/[...nextauth]/ # NextAuth.js handler
    ├── components/layout/
    │   └── Navbar.tsx              # Role-aware navigation
    └── lib/
        ├── auth.ts                 # NextAuth options + callbacks
        ├── prisma.ts               # Prisma client singleton
        └── rbac.ts                 # Role/permission helpers
```

---

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
