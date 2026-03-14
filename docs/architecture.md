# SMSDAO/platform — Architecture

> See also: [specs.md](specs.md) · [ui.md](ui.md) · [god_swarm.md](god_swarm.md) · [developer.md](developer.md)

## Overview

```
SMSDAO/platform
│
├── bin/
│   └── pipeline.ps1              ← Thin entry point (all 109 repos call this)
│
├── src/
│   ├── orchestrator/
│   │   └── pipeline-core.psm1   ← Central dispatcher + boot sequence
│   │
│   ├── phases/                  ← One responsibility per module
│   │   ├── build.psm1
│   │   ├── test.psm1
│   │   ├── deploy.psm1
│   │   ├── heal.psm1
│   │   └── validate-env.psm1
│   │
│   ├── security/
│   │   └── policy-engine.psm1   ← DAO-level governance (no GitHub App needed)
│   │
│   ├── providers/
│   │   └── providers.psm1       ← k8s | azure | aws | vercel | generic
│   │
│   ├── reporting/
│   │   ├── pr-comment.psm1      ← Dynamic comment factory + resolver
│   │   └── summary-builder.psm1
│   │
│   └── utils/
│       ├── logger.psm1          ← Structured logging (JSON mode for CI)
│       ├── repo-detect.psm1     ← RepoProfile classifier
│       ├── json-tools.psm1      ← Config loader with precedence chain
│       └── file-scan.psm1       ← Pattern scanner used by security modules
│
├── tests/
│   ├── unit/                    ← Per-module Pester 5 tests
│   └── integration/             ← End-to-end scenario tests
│
├── config/
│   ├── templates/               ← consumer-ci.yml, config.*.json
│   └── schemas/                 ← JSON Schema files
│
├── docs/                        ← Project documentation
├── scripts/                     ← Developer tooling
└── .github/
    └── workflows/
        ├── smart-pipeline.yml   ← Reusable workflow (called by all 109 repos)
        ├── platform-test.yml    ← Self-test CI
        ├── module-lint.yml      ← PSScriptAnalyzer + syntax check
        └── security-scan.yml    ← Security scan
```

## Key Principles

### 1. DRY — One Command for Everyone
```powershell
./bin/pipeline.ps1 -Phase Build    # developer running locally
./bin/pipeline.ps1 -Phase Full     # CI running in GitHub Actions
./bin/pipeline.ps1 -Phase Heal     # bot running healing protocol
```
YAML never duplicates logic from the script. The same PowerShell function runs in all contexts.

### 2. Orchestrator Pattern
`bin/pipeline.ps1` is intentionally thin (~25 lines).  
All logic routes through `pipeline-core.psm1 → Invoke-Pipeline`.  
Phases are isolated modules with one responsibility each. The orchestrator handles:
- Boot sequence (config load, secret scan, repo detect)
- Phase dispatch via `switch ($Phase)`
- Error handling and PR comment posting on failure
- Metrics export in CI context

### 3. Config Precedence Chain
```
CustomArgs (GitHub Secrets) > config.<Env>.json > hardcoded default
```
Secrets never live in config files. Config files contain only non-secret environment-specific values like namespace, region, or resource group names.

### 4. Provider Abstraction
```powershell
Invoke-Provider -Name $provider -Env $Env -CustomArgs $args
```
Switching from k8s → AWS for one repo = change one line in `config.<Env>.json`. No phase module contains cloud-specific CLI commands; all cloud logic is encapsulated in `providers.psm1`.

### 5. Security Engine
`policy-engine.psm1` enforces DAO-level governance:
- Workflow permission audit (unsafe triggers, auto-push detection)
- Unapproved Actions allowlist enforcement
- Hardcoded secret detection (9 regex pattern categories)
- Branch protection API verification
- Deploy provider consistency across environments

### 6. Versioning Strategy
```
SMSDAO/platform tags: v1.0.0, v1.1.0, v2.0.0
Consumer repos pin:   uses: SMSDAO/platform/.github/workflows/smart-pipeline.yml@v1
```
Breaking changes only in major versions. Minor/patch = safe auto-update for all 109+ consumer repos simultaneously.

---

## Module Dependency Graph

```
bin/pipeline.ps1
    └── src/orchestrator/pipeline-core.psm1
            ├── src/utils/logger.psm1
            ├── src/utils/repo-detect.psm1
            │       └── src/utils/logger.psm1
            ├── src/utils/json-tools.psm1
            │       └── src/utils/logger.psm1
            ├── src/reporting/pr-comment.psm1
            │       └── src/utils/logger.psm1
            ├── src/reporting/summary-builder.psm1
            │       └── src/utils/logger.psm1
            ├── src/phases/build.psm1
            │       ├── src/utils/logger.psm1
            │       ├── src/utils/json-tools.psm1
            │       └── src/reporting/pr-comment.psm1
            ├── src/phases/test.psm1
            │       ├── src/utils/logger.psm1
            │       ├── src/utils/json-tools.psm1
            │       └── src/reporting/pr-comment.psm1
            ├── src/phases/deploy.psm1
            │       ├── src/utils/logger.psm1
            │       ├── src/utils/json-tools.psm1
            │       ├── src/providers/providers.psm1
            │       └── src/reporting/pr-comment.psm1
            ├── src/phases/heal.psm1
            │       ├── src/utils/logger.psm1
            │       ├── src/utils/json-tools.psm1
            │       ├── src/utils/file-scan.psm1
            │       ├── src/security/policy-engine.psm1
            │       ├── src/reporting/pr-comment.psm1
            │       ├── src/reporting/summary-builder.psm1
            │       ├── src/phases/build.psm1
            │       ├── src/phases/test.psm1
            │       └── src/phases/validate-env.psm1
            ├── src/phases/validate-env.psm1
            │       ├── src/utils/logger.psm1
            │       ├── src/utils/file-scan.psm1
            │       └── src/reporting/pr-comment.psm1
            └── src/security/policy-engine.psm1
                    ├── src/utils/logger.psm1
                    └── src/utils/file-scan.psm1
```

`src/utils/logger.psm1` has **no dependencies** and is the only module safe to import first.

---

## Boot Sequence (every run)

```
Invoke-Pipeline called
    │
    ├─1─ Import-EnvConfig        → loads config.<Env>.json (merge with defaults)
    ├─2─ Assert-NoSecretsInConfig → pattern-scans config files (fail-fast)
    ├─3─ Invoke-RepoDetect       → classifies tech stack → RepoProfile object
    ├─4─ Invoke-PRComment         → posts "boot" comment if in PR context
    └─5─ dispatch switch($Phase)  → calls the correct Invoke-*Phase function
```

Steps 1–4 execute on **every** pipeline run regardless of phase. This ensures every run has a valid config, clean secrets state, and known repo profile before any phase-specific code runs.

---

## Heal Protocol (9 phases)

| # | Phase | Action |
|---|-------|--------|
| 1 | RemoveUnsafeWorkflows | Delete dangerous auto-push/comment-trigger workflows |
| 2 | DetectRepo | Classify repo type, surface build flags |
| 3 | NormalizeCI | Write deterministic read-only CI yaml |
| 4 | ValidateEnv | Check .env.example, .gitignore, secret scan |
| 5 | StabilizeBuildAndTest | Run Build + Test; surface real failures |
| 6 | FrontendDeploymentRules | Gate Next.js deploy on .next/ existence; scan bundle |
| 7 | ResolveReviewThreads | Surface open PR review thread count |
| 8 | AutoMergePolicy | Squash-merge if CI green + branch clean |
| 9 | SafetyGuarantees | Full policy check + security score |

Each step runs in an isolated `try/catch`. Failure in one step **never** aborts remaining steps. Every step posts its own PR comment for full auditability.

---

## PR Comment System

Every pipeline event generates a structured Markdown comment via `New-CommentBody`:
- Stale bot comment is found, deleted, replaced atomically (one comment per PR, no spam)
- Secrets in `CustomArgs` are automatically masked (`***`)
- Includes: status badge, run link, timestamp, phase metadata
- Non-fatal: comment failure never stops the pipeline

---

## RepoProfile Object

```powershell
class RepoProfile {
    [string]   $Type           # nextjs | node | tauri | electron | solidity | dotnet | generic
    [bool]     $HasLint        # package.json has "lint" script
    [bool]     $HasTypecheck   # package.json has "typecheck" script
    [bool]     $HasTest        # package.json has "test" script
    [bool]     $HasBuild       # package.json has "build" script
    [string]   $NodeVersion    # from engines.node field
    [string[]] $Frameworks     # detected framework list (react, ethers, etc.)
    [hashtable]$Scripts        # full scripts map from package.json
    [bool]     $IsMonorepo     # workspaces or turbo.json detected
}
```

Detection priority: `nextjs` > `tauri` > `solidity` > `electron` > `dotnet` > `node` > `generic`

---

## Data Flow: Full Pipeline

```
GitHub event (push/PR)
    │
    ▼
smart-pipeline.yml (GitHub Actions reusable workflow)
    │
    ├── resolve job: compute Env + Phase + PR context
    │
    ├── pipeline job: run PowerShell
    │       pwsh ./bin/pipeline.ps1 -Phase Full -Env $env
    │                   │
    │                   ▼
    │           Invoke-Pipeline (pipeline-core.psm1)
    │                   │
    │               Boot sequence
    │                   │
    │            ┌──────┼──────┐
    │            ▼      ▼      ▼
    │           Build  Test   Deploy
    │            │      │      │
    │            └──────┴──────┘
    │                   │
    │          Register-PhaseResult × 3
    │                   │
    │          Export-Metrics (if GITHUB_RUN_ID set)
    │
    └── Post aggregate summary PR comment
```
