# Deployment Guide

How to deploy and maintain the SMSDAO/platform infrastructure.

---

## Platform Versioning

The platform uses semantic versioning with Git tags:

```
SMSDAO/platform@v1       ← major version alias (auto-updated)
SMSDAO/platform@v1.0.0   ← precise pinning
SMSDAO/platform@v1.1.0   ← minor update (safe auto-update)
SMSDAO/platform@v2.0.0   ← breaking change (manual update required)
```

Consumer repos should pin to the major version alias:
```yaml
uses: SMSDAO/platform/.github/workflows/smart-pipeline.yml@v1
```

---

## Releasing a New Version

1. Merge your changes to `main`
2. Create a tag:
   ```bash
   git tag v1.x.x
   git push origin v1.x.x
   ```
3. Update the major version alias:
   ```bash
   git tag -f v1
   git push origin v1 --force
   ```

### Breaking Changes (Major Version Bump)
1. Create a `v2` branch and make changes there
2. Update `config/templates/consumer-ci.yml` to reference `@v2`
3. Notify all 109+ consumer repos via the release notes
4. Provide migration guide in `docs/migration-guide.md`

---

## Consumer Repo Onboarding

New repos need **one file** to integrate with the platform:

1. Copy `config/templates/consumer-ci.yml` to `.github/workflows/ci.yml` in the consumer repo
2. Add required secrets to the consumer repo (see `docs/provider-setup.md`)
3. (Optional) Copy `config/templates/config.Dev.json` to the repo root for environment overrides
4. Push — the platform auto-detects repo type and configures the pipeline

---

## Environment Configuration

Consumer repos can override defaults by placing `config.<Env>.json` in their repo root:

```json
{
  "namespace": "my-custom-namespace",
  "deployment": "my-app",
  "testPath": "./src/__tests__"
}
```

Config key precedence:
```
CustomArgs (GitHub Secrets) > config.<Env>.json > hardcoded default
```

---

## Monitoring and Metrics

When running in GitHub Actions (`$env:GITHUB_RUN_ID` is set), the platform exports:
- `./pipeline-metrics.json` — phase results, durations, overall status
- PR comments — structured Markdown with phase results and run link
- Log buffer — available via `Get-LogBuffer` or `Export-LogJson`

---

## Infrastructure Requirements

| Requirement | Version |
|---|---|
| PowerShell | 7.0+ |
| GitHub Actions runner | `ubuntu-latest` |
| Pester (tests only) | 5.5.0+ |
| PSScriptAnalyzer (lint only) | 1.21.0+ |
