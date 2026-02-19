#Requires -Version 7.0
<#
.SYNOPSIS
    SMSDAO Platform — Test Phase
.DESCRIPTION
    Rules: Never delete tests, never weaken assertions,
    never mock production logic improperly.
    Lint surfaces errors only — never auto-fixes in CI.
#>

using module ../utils/logger.psm1
using module ../utils/json-tools.psm1
using module ../reporting/pr-comment.psm1

function Invoke-TestPhase {
    param(
        [Parameter(Mandatory=$true)]
        [object]$RepoProfile,

        [string]$Env          = "Dev",
        [hashtable]$CustomArgs = @{},
        [bool]$IsDryRun        = $false,
        [string]$PRNumber      = $env:PR_NUMBER,
        [string]$Token         = $env:GH_TOKEN,
        [string]$Repo          = $env:GITHUB_REPOSITORY
    )

    $phase = "Test"
    $start = Get-Date
    Write-Step "Phase: $phase" -Phase $phase

    Invoke-PRComment -EventType "phase_start" -PhaseLabel $phase `
                     -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun

    try {
        $detail = ""

        switch ($RepoProfile.Type) {
            { $_ -in "nextjs","node","electron","solidity","tauri" } {
                if (-not $IsDryRun) {
                    & npm test -- --passWithNoTests
                    if ($LASTEXITCODE -ne 0) { throw "npm test failed." }

                    # Lint: surface only, no auto-fix
                    if ($RepoProfile.HasLint) {
                        & npm run lint
                        if ($LASTEXITCODE -ne 0) { throw "Lint check failed. Fix issues before merging." }
                    }
                    $detail = "Tests passed. Lint: $(if ($RepoProfile.HasLint) { 'passed' } else { 'skipped' })"
                } else {
                    Write-Dry "Would run: npm test && npm run lint" -Phase $phase
                }
            }

            "dotnet" {
                $cfg = New-PesterConfiguration
                $cfg.Run.Path         = Get-ConfigValue "testPath"     -Default "./tests" -CustomArgs $CustomArgs
                $cfg.Run.PassThru     = $true
                $cfg.Output.Verbosity = Get-ConfigValue "testVerbosity" -Default "Normal" -CustomArgs $CustomArgs

                $coveragePath = Get-ConfigValue "coveragePath" -CustomArgs $CustomArgs
                if ($coveragePath) {
                    $cfg.CodeCoverage.Enabled      = $true
                    $cfg.CodeCoverage.Path         = $coveragePath
                    $cfg.CodeCoverage.OutputFormat = "JaCoCo"
                    $cfg.CodeCoverage.OutputPath   = "./coverage/pester-coverage.xml"
                }

                if (-not $IsDryRun) {
                    $r      = Invoke-Pester -Configuration $cfg
                    $detail = "Passed: $($r.PassedCount) | Failed: $($r.FailedCount) | Skipped: $($r.SkippedCount)"
                    Write-Info $detail -Phase $phase
                    if ($r.FailedCount -gt 0) {
                        Invoke-PRComment -EventType "phase_failure" -PhaseLabel $phase `
                                         -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun `
                                         -Detail $detail
                        throw "Tests Failed: $($r.FailedCount) test(s)."
                    }
                } else {
                    Write-Dry "Would run: Invoke-Pester -Configuration <config>" -Phase $phase
                }
            }

            default { Write-Info "No recognized test runner — skipping safely." -Phase $phase }
        }

        $duration = (Get-Date) - $start
        Write-OK "Tests passed in $([math]::Round($duration.TotalSeconds,1))s" -Phase $phase

        Invoke-PRComment -EventType "phase_success" -PhaseLabel $phase `
                         -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun `
                         -Detail $detail -Metadata @{ duration = "$([math]::Round($duration.TotalSeconds,1))s" }

        return @{ status = "pass"; duration = $duration; detail = $detail }
    }
    catch {
        $duration = (Get-Date) - $start
        Invoke-PRComment -EventType "phase_failure" -PhaseLabel $phase `
                         -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun `
                         -Detail "$_"
        throw
    }
}

Export-ModuleMember -Function Invoke-TestPhase
