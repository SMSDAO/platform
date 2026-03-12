# Developer Guide

Contributing to the SMSDAO/platform codebase.

---

## Getting Started

### Prerequisites
- PowerShell 7.0+
- Git

### Setup

```bash
git clone https://github.com/SMSDAO/platform.git
cd platform
pwsh ./scripts/install-dependencies.ps1
```

This installs:
- **Pester 5.5.0+** — test framework
- **PSScriptAnalyzer** — linting
- **powershell-yaml** — YAML parsing utilities

### GitHub Codespaces

Open the repo in Codespaces — the `.devcontainer/devcontainer.json` configuration installs all dependencies automatically.

---

## Repository Structure

```
bin/pipeline.ps1                ← Consumer-facing entry point (thin wrapper)
src/
├── orchestrator/               ← Central dispatcher
├── phases/                     ← One module per pipeline phase
├── security/                   ← Policy engine
├── providers/                  ← Cloud provider adapters
├── reporting/                  ← PR comment and summary generation
└── utils/                      ← Shared utilities
tests/
├── unit/                       ← Per-module unit tests
└── integration/                ← End-to-end scenario tests
config/
├── templates/                  ← consumer-ci.yml, config.*.json
└── schemas/                    ← JSON Schema for validation
docs/                           ← All documentation
.github/workflows/              ← CI for the platform itself + smart-pipeline.yml
scripts/                        ← Developer tooling
.devcontainer/                  ← Codespaces configuration
```

---

## Adding a New Phase

1. Create `src/phases/my-phase.psm1` following the existing pattern:
   ```powershell
   #Requires -Version 7.0
   using module ../utils/logger.psm1
   using module ../utils/json-tools.psm1
   using module ../reporting/pr-comment.psm1

   function Invoke-MyPhase {
       param(
           [Parameter(Mandatory=$true)][object]$RepoProfile,
           [string]$Env = "Dev",
           [hashtable]$CustomArgs = @{},
           [bool]$IsDryRun = $false,
           [string]$PRNumber, [string]$Token, [string]$Repo
       )
       # ... implementation ...
   }
   Export-ModuleMember -Function Invoke-MyPhase
   ```

2. Add `using module ../phases/my-phase.psm1` to `src/orchestrator/pipeline-core.psm1`
3. Add a `case` to the `switch ($Phase)` block in `Invoke-Pipeline`
4. Add `"MyPhase"` to the `ValidateSet` in both `pipeline-core.psm1` and `bin/pipeline.ps1`
5. Write tests in `tests/unit/my-phase.Tests.ps1`

---

## Adding a New Provider

1. Add a function `Invoke-<ProviderName>Deploy` to `src/providers/providers.psm1`
2. Add the provider name to the `ValidateSet` on `Invoke-Provider`
3. Add a case to the `switch ($Name)` block
4. Add to the approved providers list in `docs/provider-setup.md`
5. Add to `organization-map.json` → `supported_providers`
6. Write tests in `tests/unit/providers.Tests.ps1`

---

## Running Tests

```powershell
# All unit tests
Invoke-Pester ./tests/unit/

# Specific test file
Invoke-Pester ./tests/unit/build.Tests.ps1

# Integration tests
Invoke-Pester ./tests/integration/

# With coverage
$cfg = New-PesterConfiguration
$cfg.Run.Path = "./tests"
$cfg.CodeCoverage.Enabled = $true
$cfg.CodeCoverage.Path = "./src/**/*.psm1"
Invoke-Pester -Configuration $cfg
```

---

## Code Style

- **Strict mode**: Entry scripts set `Set-StrictMode -Version Latest`; new or updated modules should do the same
- **Error handling**: `$ErrorActionPreference = "Stop"` in entry points
- **Logging**: Use `Write-Info`, `Write-OK`, `Write-Fail` — never `Write-Host` directly in phase modules
- **DryRun**: Every side effect must be guarded by `if (-not $IsDryRun)` with a `Write-Dry` counterpart
- **Comments**: Modules start with `.SYNOPSIS` and `.DESCRIPTION` blocks
- **Exports**: Always explicit: `Export-ModuleMember -Function <list>`

---

## Pull Request Checklist

- [ ] New or updated tests for all changes
- [ ] PSScriptAnalyzer reports no errors (`Invoke-ScriptAnalyzer -Severity Error`)
- [ ] DryRun mode works for all new side effects
- [ ] `docs/api-reference.md` updated if public API changed
- [ ] No secrets or credentials committed
