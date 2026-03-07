# Migration Guide

Upgrading between SMSDAO/platform versions.

---

## v1.x → v2.x (Hypothetical Future)

> This section documents the upgrade path for when a v2 breaking change is released.

### Breaking Changes (v2)
_None yet. This section will be populated when v2 is planned._

### Migration Steps
1. Update the workflow reference in `.github/workflows/ci.yml`:
   ```yaml
   # Before:
   uses: SMSDAO/platform/.github/workflows/smart-pipeline.yml@v1
   # After:
   uses: SMSDAO/platform/.github/workflows/smart-pipeline.yml@v2
   ```
2. Apply any config changes from the v2 release notes
3. Test with `dry_run: true` first

---

## v1.0.0 — Initial Release (Current)

### Structure Standardization

In v1.0.0, all PowerShell modules were moved from the repository root to a standardized structure:

| Old Location | New Location |
|---|---|
| `pipeline.ps1` | `bin/pipeline.ps1` |
| `pipeline-core.psm1` | `src/orchestrator/pipeline-core.psm1` |
| `build.psm1` | `src/phases/build.psm1` |
| `test.psm1` | `src/phases/test.psm1` |
| `deploy.psm1` | `src/phases/deploy.psm1` |
| `heal.psm1` | `src/phases/heal.psm1` |
| `validate-env.psm1` | `src/phases/validate-env.psm1` |
| `policy-engine.psm1` | `src/security/policy-engine.psm1` |
| `providers.psm1` | `src/providers/providers.psm1` |
| `pr-comment.psm1` | `src/reporting/pr-comment.psm1` |
| `summary-builder.psm1` | `src/reporting/summary-builder.psm1` |
| `logger.psm1` | `src/utils/logger.psm1` |
| `repo-detect.psm1` | `src/utils/repo-detect.psm1` |
| `json-tools.psm1` | `src/utils/json-tools.psm1` |
| `file-scan.psm1` | `src/utils/file-scan.psm1` |
| `smart-pipeline.yml` | `.github/workflows/smart-pipeline.yml` |
| `consumer-ci.yml` | `config/templates/consumer-ci.yml` |
| `architecture.md` | `docs/architecture.md` |

**Consumer repos are not affected** — they reference the reusable workflow via:
```yaml
uses: SMSDAO/platform/.github/workflows/smart-pipeline.yml@v1
```
This path has not changed.

### New in v1.0.0
- `organization-map.json` — machine-readable platform metadata
- `config/templates/config.{Dev,Staging,Prod}.json` — environment config templates
- `config/schemas/config-schema.json` — JSON Schema for config validation
- `tests/unit/` and `tests/integration/` — comprehensive test suite
- `.devcontainer/devcontainer.json` — GitHub Codespaces support
- `.github/workflows/platform-test.yml` — platform CI
- `.github/workflows/module-lint.yml` — PowerShell linting
- `.github/workflows/security-scan.yml` — automated security checks
- Complete documentation suite in `docs/`
