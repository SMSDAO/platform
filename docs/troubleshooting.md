# Troubleshooting Guide

Common issues and solutions for SMSDAO/platform.

---

## Pipeline Failures

### "Orchestrator not found" error

```
[FATAL] Orchestrator not found at: /path/to/src/orchestrator/pipeline-core.psm1
```

**Cause**: `bin/pipeline.ps1` is not being run from within the correct checkout of the platform.

**Fix**: Ensure the platform repo is checked out and `$PSScriptRoot` correctly points to the `bin/` directory:
```powershell
# Correct usage (from smart-pipeline.yml):
../platform/bin/pipeline.ps1 -Phase Build -Env Dev

# Correct usage (local development):
./bin/pipeline.ps1 -Phase Build -Env Dev
```

---

### Module import errors (`using module`)

```
The specified module 'X' was not loaded because no valid module file was found
```

**Cause**: PowerShell `using module` directives resolve paths relative to the `.psm1` file, not the current directory.

**Fix**: Import modules in the correct order. Bottom-level utils (`logger.psm1`) must be imported before modules that depend on them. The orchestrator (`pipeline-core.psm1`) handles this automatically.

---

### "Secret detected in config file" error

```
Secret detected in config file. Move secrets to GitHub Secrets + CustomArgs.
```

**Cause**: A `config.<Env>.json` file contains a key matching a secret pattern with a non-placeholder value.

**Fix**:
1. Remove the secret value from the config file
2. Add the secret to GitHub Secrets
3. Inject via `CustomArgs` in the workflow:
   ```yaml
   run: |
     ../platform/bin/pipeline.ps1 -Phase Deploy `
       -Args @{ myApiKey = "${{ secrets.MY_API_KEY }}" }
   ```

---

### Policy check fails with "Unapproved action"

```
[critical] uses: third-party/some-action@v1 — not in approved allowlist
```

**Fix**: Either:
- Replace with an approved action (see `docs/security-policies.md`)
- Submit a PR to add the action to the allowlist in `src/security/policy-engine.psm1`

---

## CI / GitHub Actions Issues

### Workspace cache miss

```
Error: Cache not found for key: smsdao-workspace-<sha>
```

**Cause**: The `platform` job hasn't completed, or the cache was evicted.

**Fix**: The `platform-test.yml` workflow does not use caching — this only applies to `smart-pipeline.yml`. If the cache miss is in smart-pipeline, check that the `platform` job completed before `build`/`test`/`deploy`.

---

### "Cannot find type [RepoProfile]" error

**Cause**: A module that defines the `RepoProfile` class was not loaded before the dependent module.

**Fix**: Always import modules through the orchestrator (`pipeline-core.psm1`), which handles the correct load order.

---

## Local Development Issues

### Pester not found

```
The term 'Invoke-Pester' is not recognized
```

**Fix**:
```powershell
./scripts/install-dependencies.ps1
```

---

### PSScriptAnalyzer warnings about `Write-Host`

The platform uses `Write-Host` intentionally in `logger.psm1` for colorized CI output. The `PSAvoidUsingWriteHost` rule is excluded in the lint workflow.

---

## Getting Help

1. Check `docs/` for detailed guides
2. Open an issue in this repository
3. For critical production issues, use the `heal` phase: `./bin/pipeline.ps1 -Phase Heal -Env Prod`
