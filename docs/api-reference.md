# SMSDAO Platform — API Reference

PowerShell module function reference for `SMSDAO/platform`.

---

## `src/orchestrator/pipeline-core.psm1`

### `Invoke-Pipeline`

Main entry point. Runs the boot sequence and dispatches to phase functions.

```powershell
Invoke-Pipeline
    -Phase     <string>    # Build | Test | Deploy | Full | Heal | DetectRepo | ValidateEnv | Policy
    [-Env      <string>]   # Dev | Staging | Prod (default: Dev)
    [-Args     <hashtable>]# Runtime overrides and secrets
    [-DryRun   <switch>]   # Print actions, skip side effects
    [-PRNumber <string>]   # PR number for comment posting
    [-Token    <string>]   # GitHub token (env: GH_TOKEN)
    [-Repo     <string>]   # "org/repo" (env: GITHUB_REPOSITORY)
```

---

## `src/phases/build.psm1`

### `Invoke-BuildPhase`

Builds the consumer repo based on detected repo type.

```powershell
Invoke-BuildPhase
    -RepoProfile <RepoProfile>  # Output of Invoke-RepoDetect
    [-Env        <string>]
    [-CustomArgs <hashtable>]
    [-IsDryRun   <bool>]
    [-PRNumber   <string>]
    [-Token      <string>]
    [-Repo       <string>]
```

**Returns**: `@{ status = "pass"|"fail"; duration = <timespan> }`

---

## `src/phases/test.psm1`

### `Invoke-TestPhase`

Runs the test suite for the consumer repo.

```powershell
Invoke-TestPhase
    -RepoProfile <RepoProfile>
    [-Env        <string>]
    [-CustomArgs <hashtable>]
    [-IsDryRun   <bool>]
    [-PRNumber   <string>]
    [-Token      <string>]
    [-Repo       <string>]
```

**Returns**: `@{ status = "pass"|"fail"; duration = <timespan> }`

---

## `src/phases/deploy.psm1`

### `Invoke-DeployPhase`

Deploys to the configured provider for the target environment.

```powershell
Invoke-DeployPhase
    -RepoProfile <RepoProfile>
    [-Env        <string>]
    [-CustomArgs <hashtable>]   # provider, vercelToken injected here
    [-IsDryRun   <bool>]
    [-PRNumber   <string>]
    [-Token      <string>]
    [-Repo       <string>]
```

**Returns**: `@{ status = "pass"|"fail"; duration = <timespan> }`

---

## `src/phases/heal.psm1`

### `Invoke-HealPhase`

Runs 9-step healing protocol: removes unsafe workflows, normalizes CI, validates env, stabilizes build/test, enforces deployment rules, resolves review threads, applies auto-merge policy, and runs safety guarantees.

```powershell
Invoke-HealPhase
    -RepoProfile <RepoProfile>
    [-Env        <string>]
    [-CustomArgs <hashtable>]
    [-IsDryRun   <bool>]
    [-PRNumber   <string>]
    [-Token      <string>]
    [-Repo       <string>]
```

**Returns**: `@{ status = "pass"|"fail"; duration = <timespan>; steps = <hashtable> }`

---

## `src/phases/validate-env.psm1`

### `Invoke-ValidateEnvPhase`

Validates `.env.example`, `.gitignore`, and scans for secrets in environment files.

```powershell
Invoke-ValidateEnvPhase
    -RepoProfile <RepoProfile>
    [-Env        <string>]
    [-CustomArgs <hashtable>]
    [-IsDryRun   <bool>]
    [-PRNumber   <string>]
    [-Token      <string>]
    [-Repo       <string>]
```

---

## `src/security/policy-engine.psm1`

### `Invoke-PolicyCheck`

Runs all governance rules and returns a structured result.

```powershell
Invoke-PolicyCheck
    [-Env   <string>]
    [-Token <string>]
    [-Repo  <string>]
```

**Returns**: `PolicyResult` object with `Passed`, `Violations[]`, `Warnings[]`, `Score`.

### `Get-SecurityScore`

Converts a `PolicyResult` into a 0–100 numeric score.

```powershell
Get-SecurityScore -PolicyResult <PolicyResult>
```

**Returns**: `[int]` 0–100

---

## `src/providers/providers.psm1`

### `Invoke-Provider`

Dispatches to the correct cloud provider deploy function.

```powershell
Invoke-Provider
    -Name      <string>     # k8s | azure | aws | vercel | generic
    -Env       <string>
    [-CustomArgs <hashtable>]
    [-IsDryRun   <bool>]
```

---

## `src/utils/logger.psm1`

### Logging Functions

| Function | Level | Color |
|---|---|---|
| `Write-Step <msg>` | INFO | Cyan |
| `Write-Info <msg>` | INFO | DarkCyan |
| `Write-Warn <msg>` | WARN | Yellow |
| `Write-OK <msg>` | INFO | Green |
| `Write-Fail <msg>` | ERROR | Red |
| `Write-Dry <msg>` | DEBUG | Magenta |

**JSON mode**: Set `$env:SMSDAO_LOG_JSON = "true"` for machine-readable output.

### `Get-LogBuffer`
Returns all log entries as an array of hashtables.

### `Export-LogJson`
Writes log buffer to a JSON file.

---

## `src/utils/repo-detect.psm1`

### `Invoke-RepoDetect`

Inspects the current working directory and returns a `RepoProfile`.

```powershell
Invoke-RepoDetect
```

**Returns**: `RepoProfile` with fields:
- `Type`: `nextjs | node | electron | tauri | solidity | dotnet | generic`
- `HasLint`, `HasTypecheck`, `HasTest`, `HasBuild`: `[bool]`
- `NodeVersion`: `[string]`
- `Frameworks`: `[string[]]`
- `Scripts`: `[hashtable]`
- `IsMonorepo`: `[bool]`

---

## `src/utils/json-tools.psm1`

### `Import-EnvConfig`

Loads `config.<Env>.json` into the module-scoped config store.

```powershell
Import-EnvConfig -Env <string> [-ConfigRoot <string>]
```

### `Get-ConfigValue`

Resolves a key with precedence: `CustomArgs > config.json > Default`.

```powershell
Get-ConfigValue -Key <string> [-Default <any>] [-CustomArgs <hashtable>]
```

### `Assert-NoSecretsInConfig`

Throws if any config key appears to hold a real secret value.

---

## `src/utils/file-scan.psm1`

### `Invoke-FilePatternScan`

Scans files for regex patterns, returning `ScanResult[]`.

```powershell
Invoke-FilePatternScan
    [-Paths    <string[]>]
    [-Include  <string[]>]
    -Patterns  <hashtable[]>   # @{ regex; category; severity }
    [-Exclude  <string[]>]
```

### `Get-SecretPatterns`

Returns the canonical SMSDAO secret detection pattern set (9 patterns).
