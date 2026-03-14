# SMSDAO/platform — God Swarm

> See also: [architecture.md](architecture.md) · [specs.md](specs.md) · [ui.md](ui.md)

---

## What Is God Swarm?

**God Swarm** is the SMSDAO coordination layer that sits above individual project pipelines. While `SMSDAO/platform` provides the per-repo CI/CD engine, God Swarm provides the **organization-level orchestration** — the capacity to reason about, govern, and act across all 109+ DAO repositories simultaneously.

The name reflects the design philosophy: a single authoritative "god-level" view of the entire DAO's software ecosystem, orchestrated by a swarm of specialized agents that operate independently but share a unified policy contract.

---

## Domain Model

### Repositories

Each repository in the SMSDAO organization is a **first-class entity** with:

| Property | Description |
|---|---|
| `repoType` | Stack classification (`nextjs`, `node`, `dotnet`, `solidity`, `tauri`, `electron`, `generic`) |
| `healthScore` | 0–100 composite score (CI green, security score, test coverage, dependency freshness) |
| `deployProvider` | Active cloud provider (`k8s`, `azure`, `aws`, `vercel`, `generic`) |
| `environment` | Target environment tier (`Dev`, `Staging`, `Prod`) |
| `governanceStatus` | Policy compliance state (`compliant`, `warning`, `violation`) |
| `healState` | Current heal protocol state (`healthy`, `healing`, `degraded`, `quarantined`) |

The `organization-map.json` file at the platform root contains the current snapshot of all repository metadata.

### Agents

A God Swarm agent is a named, autonomous process that:
1. Subscribes to a set of repository events
2. Applies a specific expertise domain (security, deployment, test stability, etc.)
3. Executes via `Invoke-Pipeline` or direct module calls
4. Reports outcomes as structured PR comments or issue annotations

**Current agent classes:**

| Agent | Domain | Trigger |
|---|---|---|
| `SecurityAgent` | Policy enforcement | New workflow file, dependency change |
| `HealAgent` | 9-step heal protocol | CI failure on `main`/`develop` |
| `DeployAgent` | Multi-provider deployment | Merge to `main` with passing CI |
| `AuditAgent` | Cross-org compliance sweep | Scheduled (weekly) |
| `DependencyAgent` | Outdated package detection | Weekly schedule |
| `MonitorAgent` | Health score aggregation | Continuous |

---

## God Swarm Architecture

```
                        ┌───────────────────────┐
                        │   God Swarm Control   │
                        │   (organization-map)  │
                        └──────────┬────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
              ▼                    ▼                    ▼
    ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
    │  SecurityAgent   │ │   HealAgent      │ │  DeployAgent     │
    │  (policy-engine) │ │  (heal.psm1)     │ │  (providers.psm1)│
    └────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘
             │                    │                    │
             └────────────────────┼────────────────────┘
                                  │
                    ┌─────────────▼──────────────┐
                    │   Invoke-Pipeline           │
                    │   (pipeline-core.psm1)      │
                    └─────────────┬──────────────┘
                                  │
                    ┌─────────────▼──────────────┐
                    │   Individual Repo           │
                    │   (1 of 109+)               │
                    └────────────────────────────┘
```

---

## God Swarm Process: Organization-Wide Heal

The most complex God Swarm process is the **organization-wide heal sweep**, triggered when the `AuditAgent` detects that more than 10% of repositories are in a degraded state.

### Process Steps

```
1. AuditAgent reads organization-map.json
2. Filter repos where healthScore < 60 OR governanceStatus = "violation"
3. Sort by severity (violations first, then by healthScore ascending)
4. For each degraded repo (up to 20 concurrent):
   a. Clone or check-out repo to isolated workspace
   b. Run: Invoke-Pipeline -Phase Heal -Env Dev -DryRun (preview)
   c. Post heal plan as PR comment for human review
   d. Wait for human approval signal (issue label or PR approval)
   e. On approval: Invoke-Pipeline -Phase Heal -Env Dev (execute)
   f. Update organization-map.json entry
5. AuditAgent posts aggregate report to SMSDAO/platform issues
```

### Concurrency Control

- Maximum 20 simultaneous heal jobs
- Each job has a 30-minute timeout
- If a heal job fails after 3 retries, the repo is marked `quarantined` and an issue is created
- Quarantined repos are excluded from auto-heal; require manual intervention

### Approval Gates

God Swarm never merges PRs or deploys to `Prod` without human approval. The approval mechanism uses GitHub issue labels or PR review approvals:

| Action | Required Approval |
|---|---|
| Heal (Dev/Staging) | 1 DAO Core maintainer review |
| Heal (Prod) | 2 DAO Core maintainer reviews |
| Deploy (Staging) | 1 approver |
| Deploy (Prod) | 2 approvers + CI green |
| Bulk org-wide heal | DAO governance vote (3 of 5 maintainers) |

---

## God Swarm Process: Security Response

When `SecurityAgent` detects a critical policy violation in any repo:

```
1. SecurityAgent identifies violation (via policy-engine.psm1)
2. Immediately creates a GitHub Issue in the affected repo:
   - Title: "[SECURITY] <rule> in <file>"
   - Body: violation detail, remediation steps, severity
   - Label: "security", "critical" (or "warn")
3. Blocks PR merges by setting a failing commit status check
4. Notifies DAO maintainers via PR comment
5. Tracks remediation in organization-map.json
6. When issue is closed with "resolved" label: re-runs policy check
7. If clean: removes the blocking commit status
```

### Approved Actions Governance

The `$script:ApprovedActions` allowlist in `policy-engine.psm1` is the single source of truth for which GitHub Actions can be used across all DAO repos. Adding to this list requires:

1. PR to `SMSDAO/platform`
2. Security review of the action's source code
3. Pinned version (SHA or tag) — floating `@latest` is never approved
4. Approval from 2 DAO Core maintainers

---

## God Swarm Process: Continuous Health Monitoring

`MonitorAgent` runs on a 15-minute schedule and:

1. Reads `organization-map.json`
2. For each repo, queries GitHub API for:
   - Latest CI run status
   - Open security alerts (Dependabot, code scanning)
   - Days since last successful deploy
3. Computes composite `healthScore`:
   ```
   healthScore = (ciScore × 0.4) + (securityScore × 0.3) + (deployScore × 0.2) + (testScore × 0.1)
   ```
4. Updates `organization-map.json` with new scores and timestamps
5. Triggers `HealAgent` for any repo where `healthScore` drops below 60

---

## God Swarm Configuration

Organization-level configuration lives in `organization-map.json`:

```jsonc
{
  "repo": "SMSDAO/platform",
  "purpose": "Organization-wide CI/CD Automation Platform",
  "stack": "PowerShell + GitHub Actions + Multi-Cloud",
  "status": "CRITICAL_INFRASTRUCTURE",
  "security_score": "HIGH_GOVERNANCE",
  "build_status": "PRODUCTION_READY",
  "serves_repos": "109+",
  "supported_providers": ["k8s", "azure", "aws", "vercel", "generic"],
  "supported_environments": ["Dev", "Staging", "Prod"],
  "pipeline_phases": ["Build", "Test", "Deploy", "Full", "Heal", "DetectRepo", "ValidateEnv", "Policy"]
}
```

For per-repo God Swarm overrides, individual repos can include a `.smsdao.json` file:

```jsonc
{
  "healEnabled": true,
  "autoDeployEnvs": ["Dev"],
  "securityNotifyChannels": ["#platform-alerts"],
  "customAgents": ["SecurityAgent", "HealAgent"]
}
```

---

## God Swarm and the Heal Protocol

The Heal Phase (`heal.psm1`) is the core execution primitive that God Swarm agents use. Its 9-step design aligns with the God Swarm philosophy:

| Heal Step | God Swarm Relevance |
|---|---|
| 1. RemoveUnsafeWorkflows | Eliminates attack surface before any other action |
| 2. DetectRepo | Establishes ground truth — no assumptions about repo state |
| 3. NormalizeCI | Enforces org-wide CI standard; removes custom workflow divergence |
| 4. ValidateEnv | Ensures secret hygiene across the entire org |
| 5. StabilizeBuildAndTest | Makes the repo reliably buildable before governance checks |
| 6. FrontendDeploymentRules | Enforces deployment gates for consumer-facing apps |
| 7. ResolveReviewThreads | Surfaces human-required decisions; God Swarm cannot approve PRs |
| 8. AutoMergePolicy | Automates safe merges only when all gates pass |
| 9. SafetyGuarantees | Final security score — never skipped, always last |

The ordering is **not** arbitrary. Steps 1–4 establish safety. Steps 5–6 establish quality. Steps 7–9 enforce governance. God Swarm processes must never reorder these steps.

---

## God Swarm Invariants

These rules can **never** be violated by any God Swarm agent:

1. **No blind merges** — God Swarm never merges a PR without at least one human approval.
2. **No prod deploys without green CI** — `Prod` environment is always gated on passing tests.
3. **No secret storage** — Secrets never appear in `organization-map.json` or any log output.
4. **No partial heals** — If a heal cannot complete all 9 steps, it marks the repo `healing` (not `healed`).
5. **No silent failures** — Every agent action produces a visible audit trail (PR comment, issue, or log entry).
6. **No scope creep** — Each agent operates only on its assigned repo(s); no cross-repo writes without explicit orchestration.
7. **No quarantine bypass** — Quarantined repos require manual DAO governance resolution; no agent can remove the quarantine flag.

---

## Extending God Swarm

### Adding a New Agent

1. Define the agent's domain and trigger conditions
2. Create the agent as a PowerShell module under `src/agents/<name>.psm1` (or as a GitHub Actions job)
3. Register it in `organization-map.json` under `"agents"`
4. Add unit tests in `tests/unit/<name>.Tests.ps1`
5. Ensure the agent calls `Invoke-Pipeline` for all repo-level operations (no direct module calls that bypass the boot sequence)
6. PR to `SMSDAO/platform` with agent spec documented here

### Adding a New Repository to God Swarm

1. Copy `config/templates/consumer-ci.yml` to `.github/workflows/ci.yml` in the new repo
2. Add an entry to `organization-map.json`
3. Run `Invoke-Pipeline -Phase Heal -Env Dev -DryRun` against the new repo to preview any violations
4. Address violations, then run without `-DryRun` to onboard

---

## References

- [architecture.md](architecture.md) — Platform module architecture
- [specs.md](specs.md) — Feature specifications and acceptance criteria
- [security-policies.md](security-policies.md) — DAO security governance
- [deployment.md](deployment.md) — Platform versioning and release
- [organization-map.json](../organization-map.json) — Current org-wide state
