# Security Policies

Documentation for the SMSDAO policy engine (`src/security/policy-engine.psm1`).

---

## Overview

The policy engine enforces DAO-level governance across all 109+ dependent repositories without requiring a GitHub App. It runs as part of every pipeline execution and produces structured `PolicyResult` objects.

---

## Policy Rules

### Rule 1: Workflow Permission Safety

**Severity**: Critical  
**Checks**: Each `.github/workflows/*.yml` file for dangerous trigger patterns.

Blocked triggers:
- `issue_comment` — can be triggered by external contributors with PR access
- `pull_request_review_comment` — same risk surface
- `workflow_run` — can execute in context of privileged branch

**Remediation**: Use `pull_request` trigger instead, or add an explicit `if:` condition guard.

---

### Rule 2: Unapproved GitHub Actions

**Severity**: Warn  
**Checks**: All `uses:` entries in workflow files against the approved allowlist.

**Approved Actions**:
```
actions/checkout
actions/setup-node
actions/setup-dotnet
actions/cache
actions/upload-artifact
actions/download-artifact
actions/github-script
aws-actions/configure-aws-credentials
azure/login
azure/setup-kubectl
SMSDAO/platform
```

**Remediation**: Submit a PR to add new actions to the allowlist in `policy-engine.psm1`.

---

### Rule 3: Secret Pattern Detection

**Severity**: Critical  
**Checks**: Source files for 9 categories of hardcoded secrets.

| Category | Pattern Example |
|---|---|
| `hardcoded-password` | `password = "hunter2"` |
| `openai-key` | `sk-...` |
| `aws-access-key` | `AKIA...` |
| `github-pat` | `ghp_...` |
| `slack-token` | `xoxb-...` |
| `private-key` | `-----BEGIN PRIVATE KEY` |
| `api-key` | `api_key = "..."` |
| `hardcoded-rpc` | `mainnet.infura.io` URLs |

**Remediation**: Move secrets to GitHub Secrets and inject via `CustomArgs`.

---

### Rule 4: Branch Protection

**Severity**: Warn  
**Checks**: GitHub API to verify `main` branch has protection enabled.

**Required protections**:
- Required PR reviews before merging
- Status checks must pass
- No direct pushes to `main`

---

### Rule 5: Deploy Provider Consistency

**Severity**: Warn  
**Checks**: `provider` field in `config.*.json` files matches a supported provider name.

Supported values: `k8s`, `azure`, `aws`, `vercel`, `generic`

---

## Security Score Calculation

The security score is a normalized value between 0 and 100 derived from the outcome of all evaluated policy rules.

At a high level:

- The base score reflects the ratio of passed checks relative to the total evaluated checks.
- Each warning applies a small penalty (0.5 points per warning) to the base score.
- The final score is clamped to the range 0–100.

The policy engine does **not** enforce a hard production threshold in code. Consumers (e.g., CI/CD workflows) should enforce any required threshold explicitly; as guidance, treating scores below 80 as non‑production‑ready is recommended.
---

## Secret Handling Policy

1. **Never store secrets in `config.*.json`** — the `Assert-NoSecretsInConfig` function enforces this at boot.
2. **Inject secrets via GitHub Secrets** → workflow `env:` → `CustomArgs` hashtable → module parameter.
3. **Secrets in `CustomArgs` are automatically masked** in PR comments (replaced with `***`).
4. **Audit logging**: All policy violations are logged to the structured log buffer.

---

## Adding New Policy Rules

1. Create a new function `Test-<RuleName>` in `src/security/policy-engine.psm1`
2. Add the rule to the `$score` hashtable in `Invoke-PolicyCheck`
3. Add a unit test in `tests/unit/policy-engine.Tests.ps1`
4. Document the rule in this file
