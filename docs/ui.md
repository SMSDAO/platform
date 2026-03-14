# SMSDAO/platform — UI & UX Guidelines

> See also: [architecture.md](architecture.md) · [specs.md](specs.md)

This document defines the visual and interactive output standards for the SMSDAO/platform. "UI" in this context means the terminal output, PR comment markdown, and log formatting that humans and machines consume.

---

## 1. Terminal Output

### 1.1 Log Level Color Scheme

All terminal output is produced by `src/utils/logger.psm1`. The color scheme is fixed and must not vary by environment:

| Level | Color | Prefix | When to Use |
|---|---|---|---|
| `STEP` | Cyan | `\n[STEP] ` | Major phase boundaries and top-level actions |
| `INFO` | DarkCyan | `  i  ` | Normal informational messages |
| `WARN` | Yellow | ` (!!) ` | Non-fatal warnings (missing optional config, etc.) |
| `OK` | Green | `  OK ` | Successful operation confirmation |
| `FAIL` | Red | `  !! ` | Errors and failures |
| `DRY` | Magenta | `  >> [DRY-RUN] ` | Suppressed actions in DryRun mode |

### 1.2 Step Separators

Every phase boundary starts with a blank line and a `[STEP]` line:

```
[STEP] Phase: Build
  i  [Build] Node build (type=nextjs)
  >> [DRY-RUN] Would run: npm ci && npm run typecheck && npm run build
  OK Build succeeded in 0s
```

### 1.3 Pipeline Completion Banner

Every `Invoke-Pipeline` call ends with a green completion line:

```
SMSDAO Pipeline [Build] on [Prod] completed in 4.2s
```

Format: `SMSDAO Pipeline [<Phase>] on [<Env>] completed in <N>s`

### 1.4 Fatal Error Banner

When a phase throws and cannot be recovered:

```
[FATAL] Build failed: npm run build failed.
```

This is written to the terminal by `bin/pipeline.ps1` and causes `exit 1`.

### 1.5 DryRun Mode Header

When running in DryRun mode, the boot banner includes a mode indicator:

```
  i  SMSDAO/platform | Phase=[Build] Env=[Dev] Mode=[DRY RUN]
```

### 1.6 Secrets Masking

Any value that passes through log output and originates from `CustomArgs` containing the keys `token`, `password`, `key`, `secret`, or `credentials` (case-insensitive) must be replaced with `***`.

Example:
```
  i  Vercel | env=Dev | production=False
  >> [DRY-RUN] Would run: npx vercel deploy  --token *** --yes
```

---

## 2. PR Comment Format

### 2.1 Comment Structure

Every PR comment posted by the platform follows this Markdown structure:

```markdown
<!-- smsdao-platform-bot -->
## 🚀 SMSDAO Pipeline — <Phase> (<Env>)

| Field | Value |
|---|---|
| **Status** | ✅ pass _or_ ❌ fail |
| **Environment** | Dev / Staging / Prod |
| **Run** | [#<run_number>](<run_url>) |
| **Timestamp** | 2026-03-14T18:55:41Z |

<phase-specific details table or prose>

---
*Posted by [SMSDAO/platform](https://github.com/SMSDAO/platform)*
```

The `<!-- smsdao-platform-bot -->` HTML comment is the marker used to find and replace stale comments. It must appear on the first line.

### 2.2 Status Badges

| Status | Badge |
|---|---|
| pass | `✅ pass` |
| fail | `❌ fail` |
| warn | `⚠️ warn` |
| running | `🔄 running` |
| dry-run | `🧪 dry-run` |

### 2.3 Event-Specific Templates

#### `config_loaded` (Boot)
```markdown
<!-- smsdao-platform-bot -->
## 🚀 SMSDAO Pipeline — Boot (Dev)

| Field | Value |
|---|---|
| **Status** | 🔄 running |
| **Phase** | Build |
| **Repo Type** | nextjs |
| **Monorepo** | false |
| **Run** | [#42](https://github.com/...) |
```

#### `phase_success`
```markdown
<!-- smsdao-platform-bot -->
## 🚀 SMSDAO Pipeline — Build (Dev)

| Field | Value |
|---|---|
| **Status** | ✅ pass |
| **Duration** | 14s |
| **Environment** | Dev |
| **Run** | [#42](https://github.com/...) |
```

#### `phase_failure`
```markdown
<!-- smsdao-platform-bot -->
## 🚀 SMSDAO Pipeline — Build (Dev)

| Field | Value |
|---|---|
| **Status** | ❌ fail |
| **Error** | npm run build failed. |
| **Environment** | Dev |
| **Run** | [#42](https://github.com/...) |

> **Action required:** Review the run log and fix the build error before merging.
```

#### `heal_action` (per-step)
```markdown
<!-- smsdao-platform-bot -->
## 🩺 SMSDAO Heal — Phase3-NormalizeCI (Dev)

| Step | Status |
|---|---|
| Phase1-RemoveUnsafeWorkflows | ✅ pass |
| Phase2-DetectRepo | ✅ pass |
| Phase3-NormalizeCI | 🔄 running |
| Phase4-ValidateEnv | ⏳ pending |
| ... | ... |
```

### 2.4 Atomic Comment Replacement

The platform must never post multiple bot comments on a single PR. The replacement algorithm:

1. `GET /repos/{repo}/issues/{pr_number}/comments`
2. Find comment where `body` starts with `<!-- smsdao-platform-bot -->`
3. If found: `DELETE /repos/{repo}/issues/comments/{comment_id}`
4. `POST /repos/{repo}/issues/{pr_number}/comments` with new body

This sequence is best-effort: if step 3 or 4 fails, the pipeline continues and logs a warning.

---

## 3. Policy Report Format

### 3.1 Inline Terminal Report

```
  i  Policy: Checking workflow permissions...
  i  Policy: Scanning for unapproved Actions...
 (!!) POLICY WARNING [unapproved-action] ci.yml: Action 'codecov/codecov-action' is not on the SMSDAO approved list
  i    Remediation: Add to approved list in src/security/policy-engine.psm1 after review
  i  Policy: Scanning for hardcoded secrets...
  i  Policy: Checking deploy provider consistency...
  OK All policy checks passed.
  i  Security score: 87/100
```

### 3.2 Score Display

Security score is always displayed on one line:
```
  i  Security score: <score>/100
```

Where `<score>` is an integer 0–100 inclusive.

---

## 4. Heal Phase Progress Display

### 4.1 Per-Step Output

Each of the 9 heal steps displays:
```
[STEP] [Heal] Phase<N>-<StepName>
  ... step-specific output ...
  OK [Heal] Phase<N>-<StepName>: complete
```

On step failure:
```
  !! [Heal] Phase<N>-<StepName> failed: <error message>
  i    Continuing with next step...
```

### 4.2 Aggregate Summary

After all 9 steps, a summary table is printed:

```
[STEP] Heal Summary
  i  Phase1-RemoveUnsafeWorkflows : pass (0 files removed)
  i  Phase2-DetectRepo            : pass (type=nextjs)
  i  Phase3-NormalizeCI           : pass (ci.yml written)
  i  Phase4-ValidateEnv           : pass (.env.example created)
  i  Phase5-StabilizeBuildAndTest : pass (12 tests)
  i  Phase6-FrontendDeployRules   : pass (bundle 182 kB)
  i  Phase7-ResolveReviewThreads  : warn (2 open threads)
  i  Phase8-AutoMergePolicy       : skip (not in PR context)
  i  Phase9-SafetyGuarantees      : pass (score=91/100)
  OK Heal complete: 7 pass, 1 warn, 1 skip, 0 fail
```

---

## 5. JSON Log Mode

When `$env:SMSDAO_LOG_JSON = "true"`, all output is newline-delimited JSON objects (NDJSON):

```json
{"timestamp":"2026-03-14T18:55:41Z","level":"INFO","phase":"Build","message":"Phase: Build","data":{}}
{"timestamp":"2026-03-14T18:55:41Z","level":"INFO","phase":"Build","message":"Node build (type=nextjs)","data":{}}
{"timestamp":"2026-03-14T18:55:42Z","level":"INFO","phase":"Build","message":"OK: Build succeeded in 4s","data":{}}
```

Fields:
- `timestamp` — ISO 8601, UTC
- `level` — `DEBUG` | `INFO` | `WARN` | `ERROR`
- `phase` — phase name or empty string
- `message` — human-readable message
- `data` — additional structured data (may be empty object)

---

## 6. Progress Indicators

### 6.1 Duration Formatting

All durations are formatted as `<N>s` where N is rounded to one decimal place:
- `0s` for sub-second operations
- `4.2s`, `14.0s`, `120.3s`

### 6.2 Phase Timing

Every phase result includes a `duration` field following the pattern `"<N>s"`.

---

## 7. Error Messages

### 7.1 User-Facing Errors

Error messages must:
- State **what** failed (not just the exception type)
- Include **remediation hint** when possible
- Never include raw secret values

**Good:**
```
  !! Build failed: npm run build exited with code 1. Check the build output above.
```

**Bad:**
```
  !! Exception: System.Management.Automation.RemoteException
```

### 7.2 Config Errors

When required config values are missing:
```
  !! Deploy failed: No deploy provider configured. Set 'provider' in config.<Env>.json or pass -CustomArgs @{ provider = "k8s" }
```

### 7.3 Policy Violations

```
  !! POLICY VIOLATION [hardcoded-secret] src/config.ts: Pattern 'api-key' matched at line 12: AKIA***abcd
  i    Remediation: Move secret to GitHub Secrets and inject via CustomArgs
```

---

## 8. CI Annotations

When running in GitHub Actions context (`$env:GITHUB_ACTIONS = "true"`), errors should use GitHub Actions workflow commands for inline annotations:

```
::error file=src/phases/build.psm1,line=42::Build phase failed: npm run build exited with code 1
::warning file=config.Dev.json::Provider 'k8s' manifest directory ./k8s/Dev not found
```

This causes GitHub to surface the errors directly on the diff view in PRs.

---

## 9. Accessibility and Readability

### 9.1 Terminal Width

- All `Format-Table` output should use `-AutoSize` to adapt to terminal width.
- Log messages should be concise (under 120 characters per line) to avoid wrapping in standard terminals.

### 9.2 Color Independence

The platform must never rely on color alone to convey information. Every colored message also has a text prefix (`[STEP]`, `OK`, `!!`, etc.) that conveys the same meaning without color — ensuring accessibility in terminals that disable ANSI colors.

### 9.3 Progress for Long Operations

Any operation expected to take more than 5 seconds in non-DryRun mode must emit at least one intermediate `Write-Info` message indicating it is still in progress.

Example (kubectl rollout):
```
  i  K8s | Waiting for rollout status (timeout=300s)...
  OK K8s deploy complete: dev/app
```
