# SMSDAO/platform — Architecture

## Overview

```
SMSDAO/platform
│
├── bin/pipeline.ps1              ← Thin entry point (all 109 repos call this)
│
├── src/
│   ├── orchestrator/
│   │   └── pipeline-core.psm1  ← Central dispatcher + boot sequence
│   │
│   ├── phases/                 ← One responsibility per module
│   │   ├── build.psm1
│   │   ├── test.psm1
│   │   ├── deploy.psm1
│   │   ├── heal.psm1
│   │   └── validate-env.psm1
│   │
│   ├── security/
│   │   └── policy-engine.psm1  ← DAO-level governance (no GitHub App needed)
│   │
│   ├── providers/
│   │   └── providers.psm1      ← k8s | azure | aws | vercel | generic
│   │
│   ├── reporting/
│   │   ├── pr-comment.psm1     ← Dynamic comment factory + resolver
│   │   └── summary-builder.psm1
│   │
│   └── utils/
│       ├── logger.psm1         ← Structured logging (JSON mode for CI)
│       ├── repo-detect.psm1    ← RepoProfile classifier
│       ├── json-tools.psm1     ← Config loader with precedence chain
│       └── file-scan.psm1      ← Pattern scanner used by security modules
│
├── .github/workflows/
│   └── smart-pipeline.yml      ← Reusable workflow (called by all 109 repos)
│
└── templates/
    ├── consumer-ci.yml         ← Only file needed in consumer repos
    └── config.{Dev,Staging,Prod}.json
```

## Key Principles

### 1. DRY — One Command for Everyone
```powershell
./bin/pipeline.ps1 -Phase Build    # developer running locally
./bin/pipeline.ps1 -Phase Full     # CI running in GitHub Actions
./bin/pipeline.ps1 -Phase Heal     # bot running healing protocol
```
YAML never duplicates logic from the script.

### 2. Orchestrator Pattern
`bin/pipeline.ps1` is intentionally thin (20 lines).  
All logic routes through `pipeline-core.psm1 → Invoke-Pipeline`.  
Phases are isolated modules with one responsibility each.

### 3. Config Precedence Chain
```
CustomArgs (GitHub Secrets) > config.<Env>.json > hardcoded default
```
Secrets never live in config files. Config files contain only non-secret values.

### 4. Provider Abstraction
```powershell
Invoke-Provider -Name $provider -Env $Env -CustomArgs $args
```
Switching from k8s → AWS for one repo = change one line in `config.<Env>.json`.

### 5. Security Engine
`policy-engine.psm1` enforces DAO-level governance:
- Workflow permission audit
- Unapproved Actions allowlist
- Hardcoded secret detection (8 pattern categories)
- Branch protection API check
- Deploy provider consistency

### 6. Versioning Strategy
```
SMSDAO/platform tags: v1.0.0, v1.1.0, v2.0.0
Consumer repos pin:   uses: SMSDAO/platform/.github/workflows/smart-pipeline.yml@v1
```
Breaking changes only in major versions. Minor/patch = safe auto-update.

## Boot Sequence (every run)
1. Load `config.<Env>.json`
2. Assert no secrets in config (pattern scan)
3. Detect repo type → `RepoProfile`
4. Post boot PR comment (if PR context available)
5. Dispatch to phase function

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

Each step is isolated — failure does not abort remaining steps.

## PR Comment System
Every pipeline event generates a structured Markdown comment via `New-CommentBody`:
- Stale bot comment is found, deleted, replaced atomically
- Secrets in CustomArgs are automatically masked
- Includes: status badge, run link, timestamp, phase metadata
- Non-fatal: comment failure never stops the pipeline
