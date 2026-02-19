#Requires -Version 7.0
<#
.SYNOPSIS
    SMSDAO Platform — Heal Phase (9-Step Protocol)
.DESCRIPTION
    Non-destructive healing orchestrator. Each of the 9 steps runs
    in an isolated try/catch. A failure in one step never aborts the
    rest. Every step posts its own PR comment for full auditability.
#>

using module ../utils/logger.psm1
using module ../utils/json-tools.psm1
using module ../utils/file-scan.psm1
using module ../security/policy-engine.psm1
using module ../reporting/pr-comment.psm1
using module ../reporting/summary-builder.psm1
using module ./build.psm1
using module ./test.psm1
using module ./validate-env.psm1

function Invoke-HealPhase {
    param(
        [Parameter(Mandatory=$true)]
        [object]$RepoProfile,

        [string]$Env          = "Dev",
        [hashtable]$CustomArgs = @{},
        [bool]$IsDryRun        = $false,
        [string]$PRNumber      = $env:PR_NUMBER,
        [string]$Token         = $env:GH_TOKEN,
        [string]$Repo          = $env:GITHUB_REPOSITORY,
        [string]$NodeVersion   = "20"
    )

    Write-Step "Smart Dynamic Healing Protocol — 9 phases" -Phase "Heal"
    Invoke-PRComment -EventType "heal_action" -PhaseLabel "Heal" `
                     -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun `
                     -Detail "Starting 9-phase healing run"

    $healSteps = [ordered]@{

        # ── Phase 1: Remove unsafe automation ───────────────────
        "Phase1-RemoveUnsafeWorkflows" = {
            $unsafe = @(
                ".github/workflows/copilot-universal-auto.yml",
                ".github/workflows/auto-fix.yml",
                ".github/workflows/bot-merge.yml"
            )
            foreach ($wf in $unsafe) {
                if (Test-Path $wf) {
                    if (-not $IsDryRun) { Remove-Item $wf -Force; Write-OK "Removed: $wf" }
                    else { Write-Dry "Would remove: $wf" }
                }
            }
            # Scan remaining workflows for dangerous patterns
            Get-ChildItem ".github/workflows" -Filter "*.yml" -ErrorAction SilentlyContinue |
            ForEach-Object {
                $content = Get-Content $_.FullName -Raw
                $unsafeTriggers = @("issue_comment","pull_request_review_comment")
                foreach ($t in $unsafeTriggers) {
                    if ($content -match $t) {
                        Write-Fail "Unsafe trigger '$t' in $($_.Name) — manual review required."
                    }
                }
                if ($content -match '(?i)permissions.*write' -and $content -match 'git push|gh pr merge') {
                    Write-Fail "$($_.Name) may auto-push — check permissions block."
                }
            }
        }

        # ── Phase 2: Detect repo type ────────────────────────────
        "Phase2-DetectRepo" = {
            Write-OK "Repo profile already loaded: type=$($RepoProfile.Type)"
            Write-Info "  Frameworks: $($RepoProfile.Frameworks -join ', ')"
            Write-Info "  Monorepo  : $($RepoProfile.IsMonorepo)"
        }

        # ── Phase 3: Normalize CI ────────────────────────────────
        "Phase3-NormalizeCI" = {
            $ciPath   = ".github/workflows/ci.yml"
            $buildCmd = switch ($RepoProfile.Type) {
                { $_ -in "nextjs","node","electron","tauri" } { "npm run build" }
                "dotnet"   { "dotnet build --configuration Release" }
                "solidity" { "npx hardhat compile" }
                default    { "npm run build" }
            }

            $ciYaml = @"
name: CI Validation

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '$NodeVersion'
          cache: 'npm'
      - run: npm ci
      - run: npm run lint       --if-present
      - run: npm run typecheck  --if-present
      - run: npm test           --if-present -- --passWithNoTests
      - run: $buildCmd
"@
            if (-not $IsDryRun) {
                New-Item -ItemType Directory -Path ".github/workflows" -Force | Out-Null
                Set-Content $ciPath $ciYaml -Encoding UTF8
                Write-OK "CI written: $ciPath"
            } else {
                Write-Dry "Would write normalized CI to $ciPath"
            }
        }

        # ── Phase 4: Validate environment safety ─────────────────
        "Phase4-ValidateEnv" = {
            Invoke-ValidateEnvPhase -RepoProfile $RepoProfile -Env $Env `
                                    -CustomArgs $CustomArgs -IsDryRun $IsDryRun `
                                    -PRNumber $PRNumber -Token $Token -Repo $Repo
        }

        # ── Phase 5: Stabilize build + tests ─────────────────────
        "Phase5-StabilizeBuildAndTest" = {
            Invoke-BuildPhase -RepoProfile $RepoProfile -Env $Env `
                              -CustomArgs $CustomArgs -IsDryRun $IsDryRun `
                              -PRNumber $PRNumber -Token $Token -Repo $Repo
            Invoke-TestPhase -RepoProfile $RepoProfile -Env $Env `
                             -CustomArgs $CustomArgs -IsDryRun $IsDryRun `
                             -PRNumber $PRNumber -Token $Token -Repo $Repo
        }

        # ── Phase 6: Frontend deployment rules ───────────────────
        "Phase6-FrontendDeploymentRules" = {
            if ($RepoProfile.Type -eq "nextjs") {
                if (-not (Test-Path "./.next") -and -not $IsDryRun) {
                    throw ".next/ missing after Build phase — deploy blocked."
                }
                # Check no server secrets in client bundle
                $clientFiles = Get-ChildItem ".next/static" -Recurse -ErrorAction SilentlyContinue
                $secretPats  = Get-SecretPatterns | Where-Object { $_.severity -eq "critical" }
                $hits = Invoke-FilePatternScan -Paths @("./.next/static") -Include @("*.js") -Patterns $secretPats
                if ($hits.Count -gt 0) {
                    throw "Secret pattern detected in client bundle! $($hits.Count) match(es). Audit immediately."
                }
                Write-OK "Next.js deployment rules satisfied. No secrets in client bundle."
            } else {
                Write-Info "Not Next.js — frontend rules skipped."
            }
        }

        # ── Phase 7: Resolve open PR review threads ──────────────
        "Phase7-ResolveReviewThreads" = {
            if (-not $PRNumber -or -not $Token -or -not $Repo) {
                Write-Info "No PR context — review thread check skipped."
                return
            }
            $headers = @{
                Authorization          = "Bearer $Token"
                Accept                 = "application/vnd.github+json"
                "X-GitHub-Api-Version" = "2022-11-28"
            }
            try {
                $comments = Invoke-RestMethod `
                    -Uri "https://api.github.com/repos/$Repo/pulls/$PRNumber/comments?per_page=100" `
                    -Headers $headers -Method GET
                $open = $comments | Where-Object { -not $_.resolved }
                Write-Info "Review threads: $($open.Count) open / $($comments.Count) total"
                Invoke-PRComment -EventType "heal_action" -PhaseLabel "ReviewThreads" `
                                 -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun `
                                 -Detail "Open threads requiring attention: $($open.Count)" `
                                 -Metadata @{ total = $comments.Count; open = $open.Count }
            }
            catch { Write-Warn "Review thread check skipped: $_" }
        }

        # ── Phase 8: Auto-merge policy gate ──────────────────────
        "Phase8-AutoMergePolicy" = {
            if (-not $PRNumber -or -not $Token -or -not $Repo) {
                Write-Info "No PR context — auto-merge skipped."
                return
            }
            $headers = @{
                Authorization          = "Bearer $Token"
                Accept                 = "application/vnd.github+json"
                "X-GitHub-Api-Version" = "2022-11-28"
            }
            try {
                $pr    = Invoke-RestMethod `
                    -Uri "https://api.github.com/repos/$Repo/pulls/$PRNumber" `
                    -Headers $headers -Method GET
                $clean = $pr.mergeable -eq $true -and $pr.mergeable_state -eq "clean"

                if ($clean -and -not $IsDryRun) {
                    $payload = @{ merge_method = "squash" } | ConvertTo-Json
                    Invoke-RestMethod `
                        -Uri "https://api.github.com/repos/$Repo/pulls/$PRNumber/merge" `
                        -Headers $headers -Method PUT -Body $payload `
                        -ContentType "application/json" | Out-Null
                    Write-OK "PR #$PRNumber auto-merged (squash)."
                } elseif ($IsDryRun) {
                    Write-Dry "Would auto-merge PR #$PRNumber if state=clean (current: $($pr.mergeable_state))"
                } else {
                    Write-Info "Auto-merge gate not met — state=$($pr.mergeable_state). Awaiting CI green."
                }
            }
            catch { Write-Warn "Auto-merge check skipped: $_" }
        }

        # ── Phase 9: Safety guarantees ───────────────────────────
        "Phase9-SafetyGuarantees" = {
            $policyResult = Invoke-PolicyCheck -Env $Env -Token $Token -Repo $Repo
            $score        = Get-SecurityScore -PolicyResult $policyResult

            Write-Info "Security score: $score/100"

            Invoke-PRComment -EventType (if ($policyResult.Passed) { "env_validated" } else { "security_alert" }) `
                             -PhaseLabel "SecurityPolicy" `
                             -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun `
                             -Detail "Score: $score/100 | Violations: $($policyResult.Violations.Count)" `
                             -Metadata ($policyResult.Score)

            if (-not $policyResult.Passed) {
                throw "Security policy violations: $($policyResult.Violations.Count). See PR comment."
            }
        }
    }

    # ── Execute each step independently ─────────────────────────
    $results = [ordered]@{}
    foreach ($name in $healSteps.Keys) {
        Write-Step "Heal: $name" -Phase "Heal"
        Invoke-PRComment -EventType "heal_action" -PhaseLabel $name `
                         -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun
        $stepStart = Get-Date
        try {
            & $healSteps[$name]
            $results[$name] = "pass"
            Register-PhaseResult -PhaseName $name -Status "pass" -Duration ((Get-Date) - $stepStart)
            Write-OK "$name complete."
        }
        catch {
            $results[$name] = "fail"
            Register-PhaseResult -PhaseName $name -Status "fail" -Duration ((Get-Date) - $stepStart) `
                                 -Data @{ error = "$_" }
            Write-Fail "$name failed: $_"
            Invoke-PRComment -EventType "phase_failure" -PhaseLabel $name `
                             -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun `
                             -Detail "$_"
            # NON-DESTRUCTIVE: continue all remaining steps
        }
    }

    # ── Final aggregate comment ──────────────────────────────────
    $allGreen    = -not ($results.Values -contains "fail")
    $summaryMeta = @{}
    $results.GetEnumerator() | ForEach-Object { $summaryMeta[$_.Key] = $_.Value }

    Invoke-PRComment `
        -EventType  (if ($allGreen) { "phase_success" } else { "phase_failure" }) `
        -PhaseLabel "Heal-Complete" `
        -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun `
        -Detail     (if ($allGreen) { "All 9 phases passed" } else { "Some phases need attention" }) `
        -Metadata   $summaryMeta

    return @{
        status  = if ($allGreen) { "pass" } else { "partial" }
        results = $results
    }
}

Export-ModuleMember -Function Invoke-HealPhase
