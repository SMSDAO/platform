#Requires -Version 7.0
<#
.SYNOPSIS
    SMSDAO Platform — Orchestrator Core
.DESCRIPTION
    Central command router. Imports all phase and utility modules,
    runs boot sequence (config load + repo detect), then dispatches
    to the correct phase function.
    bin/pipeline.ps1 is thin — all logic lives here.
#>

using module ../utils/logger.psm1
using module ../utils/repo-detect.psm1
using module ../utils/json-tools.psm1
using module ../reporting/pr-comment.psm1
using module ../reporting/summary-builder.psm1
using module ../phases/build.psm1
using module ../phases/test.psm1
using module ../phases/deploy.psm1
using module ../phases/heal.psm1
using module ../phases/validate-env.psm1
using module ../security/policy-engine.psm1

function Invoke-Pipeline {
    <#
    .SYNOPSIS
        Main entry point for the SMSDAO pipeline orchestrator.
    .PARAMETER Phase
        Build | Test | Deploy | Full | Heal | DetectRepo | ValidateEnv | Policy
    .PARAMETER Env
        Dev | Staging | Prod
    .PARAMETER Args
        CustomArgs hashtable — runtime overrides and secrets.
    .PARAMETER DryRun
        When set, print all actions without executing side effects.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Build","Test","Deploy","Full","Heal","DetectRepo","ValidateEnv","Policy")]
        [string]$Phase,

        [ValidateSet("Dev","Staging","Prod")]
        [string]$Env = "Dev",

        [hashtable]$Args    = @{},
        [switch]$DryRun,

        [string]$PRNumber   = $env:PR_NUMBER,
        [string]$Token      = $env:GH_TOKEN,
        [string]$Repo       = $env:GITHUB_REPOSITORY
    )

    $isDry = $DryRun.IsPresent
    Write-Info "SMSDAO/platform | Phase=[$Phase] Env=[$Env]$(if ($isDry) { ' Mode=[DRY RUN]' })"

    # ── Boot sequence ─────────────────────────────────────────────
    # 1. Load environment config (config.<Env>.json)
    Import-EnvConfig -Env $Env

    # 2. Security check: no raw secrets in config files
    Assert-NoSecretsInConfig

    # 3. Detect repo type (all phases need the profile)
    $repoProfile = Invoke-RepoDetect

    # 4. Post boot comment if in PR context
    if ($PRNumber -and $Token -and $Repo) {
        Invoke-PRComment -EventType "config_loaded" -PhaseLabel "Boot" `
                         -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $isDry `
                         -Detail "Phase=$Phase | RepoType=$($repoProfile.Type)" `
                         -Metadata @{
                             repoType  = $repoProfile.Type
                             monorepo  = $repoProfile.IsMonorepo
                             frameworks= ($repoProfile.Frameworks -join ", ")
                         }
    }

    # ── Shared params splatted to every phase ─────────────────────
    $phaseParams = @{
        RepoProfile = $repoProfile
        Env         = $Env
        CustomArgs  = $Args
        IsDryRun    = $isDry
        PRNumber    = $PRNumber
        Token       = $Token
        Repo        = $Repo
    }

    $start = Get-Date

    try {
        switch ($Phase) {
            "Build"       { $r = Invoke-BuildPhase      @phaseParams }
            "Test"        { $r = Invoke-TestPhase        @phaseParams }
            "Deploy"      { $r = Invoke-DeployPhase      @phaseParams }
            "ValidateEnv" { $r = Invoke-ValidateEnvPhase @phaseParams }
            "Heal"        { $r = Invoke-HealPhase        @phaseParams }
            "DetectRepo"  { $r = @{ type = $repoProfile.Type } }

            "Policy" {
                $result = Invoke-PolicyCheck -Env $Env -Token $Token -Repo $Repo
                $score  = Get-SecurityScore -PolicyResult $result
                Write-Info "Security score: $score/100"
                $r = @{ status = if ($result.Passed) { "pass" } else { "fail" }; score = $score }
            }

            "Full" {
                Write-Step "Full Pipeline: Build -> Test -> Deploy"
                # DRY recursive execution via $PSCommandPath in bin/pipeline.ps1
                # The orchestrator calls each phase function directly (no subprocess overhead)
                $r1 = Invoke-BuildPhase      @phaseParams
                $r2 = Invoke-TestPhase        @phaseParams
                $r3 = Invoke-DeployPhase      @phaseParams

                Register-PhaseResult -PhaseName "Build"  -Status $r1.status -Duration $r1.duration
                Register-PhaseResult -PhaseName "Test"   -Status $r2.status -Duration $r2.duration
                Register-PhaseResult -PhaseName "Deploy" -Status $r3.status -Duration $r3.duration

                $r = @{ build = $r1; test = $r2; deploy = $r3 }
            }
        }

        # ── Post aggregate summary for Full and Heal ─────────────
        if ($Phase -in @("Full","Heal") -and $PRNumber -and $Token -and $Repo) {
            $summaryBody = New-SummaryComment -Env $Env -Phase $Phase -Repo $Repo
            $headers = @{
                Authorization          = "Bearer $Token"
                Accept                 = "application/vnd.github+json"
                "X-GitHub-Api-Version" = "2022-11-28"
            }
            $listUrl = "https://api.github.com/repos/$Repo/issues/$PRNumber/comments"
            if (-not $isDry) {
                Invoke-RestMethod -Uri $listUrl -Headers $headers `
                                  -Method POST -Body (@{body=$summaryBody}|ConvertTo-Json -Depth 3) `
                                  -ContentType "application/json" | Out-Null
            } else {
                Write-Dry "Would post aggregate summary comment for $Phase"
            }
        }

        # ── Export metrics (CI mode) ──────────────────────────────
        if ($env:GITHUB_RUN_ID -and -not $isDry) {
            Export-Metrics -Path "./pipeline-metrics.json"
        }

        $totalDuration = (Get-Date) - $start
        Write-Host "`nSMSDAO Pipeline [$Phase] on [$Env] completed in $([math]::Round($totalDuration.TotalSeconds,1))s" `
                   -ForegroundColor Green
        return $r
    }
    catch {
        Write-Fail "Pipeline Failed: $_"
        if ($PRNumber -and $Token -and $Repo) {
            Invoke-PRComment -EventType "phase_failure" -PhaseLabel $Phase `
                             -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $isDry `
                             -Detail "$_"
        }
        throw
    }
}

Export-ModuleMember -Function Invoke-Pipeline
