# SMSDAO/platform — Feature Specifications

> See also: [architecture.md](architecture.md) · [ui.md](ui.md) · [api-reference.md](api-reference.md)

This document defines the acceptance criteria and behavioral specifications for every feature in the SMSDAO/platform. It is the authoritative source of truth for what the platform **must** and **must not** do.

---

## 1. Repository Detection (`repo-detect.psm1`)

### 1.1 Stack Classification

**Must:**
- Return a `RepoProfile` object with `Type`, `HasLint`, `HasTypecheck`, `HasTest`, `HasBuild`, `NodeVersion`, `Frameworks`, `Scripts`, and `IsMonorepo` fields.
- Classify by probing the file system of the **current working directory**.
- Apply detection rules in strict priority order:
  1. `next.config.*` present → `nextjs`
  2. `src-tauri/` present → `tauri`
  3. `hardhat.config.*` present → `solidity`
  4. `package.json` containing `"electron"` in deps → `electron`
  5. `*.csproj` present → `dotnet`
  6. `package.json` present → `node`
  7. (fallback) → `generic`
- Extract `scripts` map from `package.json` when present and set `HasLint`, `HasTypecheck`, `HasTest`, `HasBuild` accordingly.
- Default `NodeVersion` to `"20"` when not specified in `engines.node`.
- Detect monorepos via presence of `workspaces` in `package.json` or `turbo.json` at repo root.

**Must not:**
- Make network calls.
- Modify any files.
- Throw on missing `package.json` (must gracefully fall through to `generic`).

### 1.2 Framework Detection

- Inspect `dependencies` + `devDependencies` for: `react`, `next`, `vite`, `ethers`, `hardhat`, `electron`, `@tauri-apps/api`.
- Populate `Frameworks` array with all matches.
- Never throw on malformed or missing dependency blocks.

---

## 2. Config Loading (`json-tools.psm1`)

### 2.1 Import-EnvConfig

**Must:**
- Search for `config.<Env>.json` in the current working directory.
- Silently continue if file is absent (log info message, use defaults).
- Merge file values with `CustomArgs` using the precedence: `CustomArgs > config file > default`.

**Must not:**
- Throw on missing config file.
- Store or log secret values from `CustomArgs`.

### 2.2 Get-ConfigValue

**Must:**
- Accept `-Default` fallback value.
- Accept `-CustomArgs` hashtable override.
- Return `CustomArgs` value if key present, else config-file value, else default.

---

## 3. Pipeline Orchestrator (`pipeline-core.psm1`)

### 3.1 Parameter Validation

**Must:**
- Accept `-Phase` values: `Build`, `Test`, `Deploy`, `Full`, `Heal`, `DetectRepo`, `ValidateEnv`, `Policy`.
- Reject any value outside the validated set with a terminating error.
- Accept `-Env` values: `Dev`, `Staging`, `Prod` only.
- Reject any value outside the validated set with a terminating error.
- Default `Env` to `"Dev"` when not provided.

### 3.2 Boot Sequence

Every invocation **must** execute in order:
1. `Import-EnvConfig -Env $Env`
2. `Assert-NoSecretsInConfig`
3. `Invoke-RepoDetect`
4. `Invoke-PRComment -EventType config_loaded` (only if PR context variables are set)

### 3.3 Phase Dispatch

**Must:**
- Call exactly one phase function per invocation (except `Full` and `Heal`).
- For `Full`: call `Build → Test → Deploy` in that order; register each result with `Register-PhaseResult`.
- Return a structured result object from every phase.
- Export metrics to `./pipeline-metrics.json` when `$env:GITHUB_RUN_ID` is set and not DryRun.

**Must not:**
- Catch and suppress errors silently; always re-throw after PR failure comment.
- Call `exit` directly; throw exceptions and let the caller handle exit codes.

### 3.4 DryRun Mode

When `-DryRun` is set:
- All network calls (GitHub API, cloud CLIs) must be skipped.
- All file system writes must be skipped.
- All suppressed actions must be logged via `Write-Dry`.
- All phase functions must return a valid result object with `status = "pass"`.

---

## 4. Build Phase (`build.psm1`)

### 4.1 Stack-Specific Build Logic

| Stack | Command (non-DryRun) |
|---|---|
| `nextjs`, `node`, `electron` | `npm ci && [typecheck if HasTypecheck] && npm run build` |
| `tauri` | `npm ci && npm run tauri build` |
| `solidity` | `npm ci && npx hardhat compile` |
| `dotnet` | `dotnet build --configuration Release` |
| `generic` | `npm ci && npm run build` |

**Must:**
- Run `npm ci` (not `npm install`) for all Node-based stacks.
- Run typecheck **before** build when `HasTypecheck` is true.
- Throw if any sub-command exits with non-zero code.
- Return `@{ status = "pass"; duration = "<Ns>" }` on success.

**Must not:**
- Auto-fix build errors.
- Modify source files.

---

## 5. Test Phase (`test.psm1`)

### 5.1 Test Execution

**Must:**
- Run `npm test -- --passWithNoTests` for all Node stacks.
- Run Pester for `dotnet` repos.
- Run `npm run lint` only when `HasLint = $true` (surface errors, never auto-fix).
- Return a result with `status`, `passed`, `failed`, `duration`.

**Must not:**
- Delete or weaken existing tests.
- Mock production logic without explicit opt-in.
- Auto-fix lint errors.

---

## 6. Deploy Phase (`deploy.psm1`)

### 6.1 Provider Selection

**Must:**
- Read deploy provider from `config.<Env>.json → provider` field, falling back to `CustomArgs.provider`.
- Delegate to `Invoke-Provider` with all relevant `CustomArgs`.
- Return deploy result from provider.

---

## 7. Provider Engine (`providers.psm1`)

### 7.1 Supported Providers

All providers **must**:
- Accept `IsDryRun` flag and skip all CLI calls in dry-run mode.
- Return `@{ status = "pass"; provider = $Name; env = $Env }` on success.
- Throw a descriptive error on CLI failure.
- Never log raw secret values.

#### Kubernetes (`k8s`)
- Run `kubectl apply -f <manifest> --namespace <ns>`
- Then `kubectl rollout status deployment/<deployment> --namespace <ns> --timeout=<timeout>`
- Default `namespace` = `$Env.ToLower()`, `manifest` = `./k8s/$Env`, `deployment` = `app`, `timeout` = `300s`
- Validate manifest path exists before calling kubectl

#### Azure (`azure`)
- Run `az webapp deploy --resource-group <rg> --name <app> --src-path ./publish`
- Default `resourceGroup` = `rg-$Env`, `appName` = `app-$Env`

#### AWS (`aws`)
- Run `aws ecs update-service --cluster <cluster> --service <service> --force-new-deployment`
- Then wait for `services-stable`
- Default `cluster` = `$Env-Cluster-01`, `service` = `$Env-service`, `awsRegion` = `us-east-1`

#### Vercel (`vercel`)
- Run `npx vercel deploy [--prod if Prod env] --token <token> --yes`
- `vercelToken` must be provided in `CustomArgs` (never from config file)
- Log token as `***` in all output

#### Generic (`generic`)
- Run `bash <deployScript> (DEPLOY_ENV=$Env)`
- `deployScript` path must be provided in `CustomArgs`
- Validate script exists before execution

### 7.2 Unknown Provider

- Throw: `"Unknown provider '<Name>'. Supported: k8s, azure, aws, vercel, generic."`

---

## 8. Security Policy Engine (`policy-engine.psm1`)

### 8.1 Policy Rules

| Rule | Severity | Detection |
|---|---|---|
| `unsafe-trigger` | critical | `issue_comment`, `pull_request_review_comment`, or `workflow_run` in workflow triggers |
| `workflow-auto-push` | critical | Workflow has write permissions AND contains `git push` or `gh pr merge` |
| `unapproved-action` | warn | `uses:` references an action not on the approved allowlist |
| `hardcoded-secret` | critical | Pattern scan matches a critical-severity secret pattern |
| `no-branch-protection` | critical | API returns 404 for branch protection on `main` |
| `branch-protection-reviews` | warn | `main` lacks required PR reviews |
| `branch-protection-checks` | warn | `main` lacks required status checks |
| `provider-drift` | warn | Multiple distinct providers across `config.*.json` files |

### 8.2 Security Score Calculation

```
score = round(((passes - warns×0.5) / total_rules) × 100)
score = max(0, score)
```

A repo with all rules passing scores **100**. Each warning subtracts 0.5 pass-equivalents. Critical violations result in `Passed = $false`.

### 8.3 Invoke-PolicyCheck

**Must:**
- Return a `PolicyResult` with `Passed`, `Violations`, `Warnings`, and `Score` fields.
- Set `Passed = $true` only when `Violations` array is empty.
- Run all 5 rule groups even when earlier groups find violations.

**Must not:**
- Throw on network failure for branch protection check (log warn and set score to `fail`).
- Modify any files.

---

## 9. Heal Phase (`heal.psm1`)

### 9.1 Non-Destructive Contract

**Must:**
- Run all 9 steps regardless of individual step failure (isolated `try/catch` per step).
- Post a PR comment for each step result when in PR context.
- Post aggregate summary comment after all steps complete.

**Must not:**
- Delete files without `IsDryRun = $false` check.
- Force-merge PRs without explicit user intent.
- Remove test files or weaken assertions.

---

## 10. Validate-Env Phase (`validate-env.psm1`)

**Must:**
- Create `.env.example` with safe placeholders if missing (or dry-run log the action).
- Verify `.env` is listed in `.gitignore` (warn if not).
- Scan config files for critical-severity secret patterns.
- Return `@{ status = "pass"; issues = @(); repairs = @() }` on success.

**Must not:**
- Commit or modify `.gitignore` automatically.
- Expose any detected secret values in logs.

---

## 11. Logging (`logger.psm1`)

**Must:**
- Support log levels: `DEBUG`, `INFO`, `WARN`, `ERROR`.
- Respect `$env:SMSDAO_LOG_LEVEL` environment variable (gate lower-level messages).
- Emit JSON-formatted entries when `$env:SMSDAO_LOG_JSON = "true"`.
- Maintain an in-memory buffer accessible via `Get-LogBuffer`.
- Export buffer to JSON file via `Export-LogJson`.

**Convenience functions and their output formats:**

| Function | Level | Prefix |
|---|---|---|
| `Write-Step` | INFO | `[STEP]` prefix, Cyan color |
| `Write-Info` | INFO | `  i  ` prefix |
| `Write-Warn` | WARN | ` (!!) ` prefix, Yellow |
| `Write-OK` | INFO | `  OK ` prefix, Green |
| `Write-Fail` | ERROR | `  !! ` prefix, Red |
| `Write-Dry` | DEBUG | `  >> [DRY-RUN] ` prefix, Magenta |

---

## 12. PR Comment System (`pr-comment.psm1`)

### 12.1 Comment Lifecycle

**Must:**
- Search existing PR comments for a SMSDAO bot marker before posting.
- Delete the stale comment and post a fresh one (atomic replace, no accumulation).
- Include: phase label, status, environment, run link, timestamp.
- Mask all secret values in logged metadata using `***`.

**Must not:**
- Throw if GitHub API is unreachable (log warn and continue).
- Post duplicate comments.

### 12.2 Event Types

| `EventType` | Meaning |
|---|---|
| `config_loaded` | Boot sequence complete |
| `phase_start` | Phase is beginning |
| `phase_success` | Phase completed successfully |
| `phase_failure` | Phase failed |
| `heal_action` | Heal step result |

---

## 13. CI Workflows

### 13.1 Platform Tests (`platform-test.yml`)

**Must:**
- Install Pester 5.5.0+ before running tests.
- Run unit tests first; integration tests only if unit tests pass.
- Publish NUnit XML test results as artifacts.
- Fail the workflow job if any test fails.

### 13.2 Module Lint (`module-lint.yml`)

**Must:**
- Run `PSScriptAnalyzer` with `Error` and `Warning` severity, excluding `PSAvoidUsingWriteHost` and `PSUseSingularNouns`.
- Fail the job if any `Error`-severity result is found.
- Run PowerShell syntax check using `[System.Management.Automation.Language.Parser]::ParseFile` on all `.ps1` and `.psm1` files.
- Declare `$parseErrors = $null` before passing `[ref]$parseErrors` to the parser.
- Fail the job if any file has syntax errors.

### 13.3 Security Scan (`security-scan.yml`)

**Must:**
- Run `Invoke-PolicyCheck` against the platform's own source.
- Surface critical violations as job errors.

### 13.4 Smart Pipeline (`smart-pipeline.yml`)

**Must:**
- Be callable as a reusable workflow by any SMSDAO consumer repo.
- Accept inputs: `phase`, `env`, `dry_run`, `platform_ref`.
- Accept secrets: `GH_TOKEN`, `AWS_ROLE_ARN`, `AZURE_CREDENTIALS`, `KUBECONFIG_DATA`, `VERCEL_TOKEN`.
- Auto-resolve `Env` from branch name when not explicitly provided (`main` → `Prod`, `develop` → `Staging`, else `Dev`).
- Set `permissions: contents: read` at workflow level.

---

## 14. Test Suite Specifications

### 14.1 Unit Test Requirements

Every public module function **must** have a corresponding unit test that:
- Runs entirely in `$TestDrive` (no real disk writes outside test sandbox).
- Tests DryRun mode (no network or system side-effects).
- Tests parameter validation (invalid inputs throw expected errors).
- Verifies the shape of the return object (required fields present).

### 14.2 Integration Test Requirements

Integration tests **must**:
- Simulate realistic repo structures in `$TestDrive`.
- Exercise the full call chain from `Invoke-Pipeline` down to individual phase results.
- Cover all supported providers × all supported environments.
- Run in DryRun mode.
- Complete in under 30 seconds total.

### 14.3 Test Stability Rules

- No `Start-Sleep` calls (use DryRun to avoid real timing dependencies).
- No network calls in tests (mock or skip via DryRun).
- All file operations use `$TestDrive` (Pester-provided temp directory).
- Tests must produce the same result regardless of execution order.
- Use `-PassThru` in Pester configuration to capture results programmatically.
