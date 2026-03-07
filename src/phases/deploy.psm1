#Requires -Version 7.0
<#
.SYNOPSIS
    SMSDAO Platform — Deploy Phase
.DESCRIPTION
    Routes to the Provider Engine. Never contains cloud CLI commands
    directly — all provider logic lives in providers.psm1.
    Secrets arrive via CustomArgs only, never from config files.
#>

using module ../utils/logger.psm1
using module ../utils/json-tools.psm1
using module ../reporting/pr-comment.psm1
using module ../providers/providers.psm1

function Invoke-DeployPhase {
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

    $phase = "Deploy"
    $start = Get-Date
    Write-Step "Phase: $phase -> $Env" -Phase $phase

    Invoke-PRComment -EventType "phase_start" -PhaseLabel "$phase -> $Env" `
                     -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun

    try {
        # Next.js gate: build output must exist before deploy
        if ($RepoProfile.Type -eq "nextjs" -and -not (Test-Path "./.next") -and -not $IsDryRun) {
            throw "Next.js build output (.next/) missing. Run Build phase first."
        }

        # Frontend secret safety check: no server-only secrets should be in Next.js bundles
        if ($RepoProfile.Type -eq "nextjs" -and $Env -eq "Prod") {
            $nextConfigContent = Get-Content "./next.config.*" -Raw -ErrorAction SilentlyContinue
            if ($nextConfigContent -match 'serverRuntimeConfig') {
                Write-Info "serverRuntimeConfig detected — verifying no leakage to client bundle..." -Phase $phase
            }
        }

        $provider = Get-ConfigValue "provider" -Default "k8s" -CustomArgs $CustomArgs
        Write-Info "Provider: $provider | Env: $Env" -Phase $phase

        $providerResult = Invoke-Provider -Name $provider -Env $Env `
                                          -CustomArgs $CustomArgs -IsDryRun $IsDryRun

        $duration = (Get-Date) - $start
        Write-OK "Deploy to $Env complete in $([math]::Round($duration.TotalSeconds,1))s" -Phase $phase

        Invoke-PRComment -EventType "phase_success" -PhaseLabel "$phase -> $Env" `
                         -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun `
                         -Metadata (@{ duration = "$([math]::Round($duration.TotalSeconds,1))s" } + $providerResult)

        return @{ status = "pass"; duration = $duration; provider = $providerResult }
    }
    catch {
        $duration = (Get-Date) - $start
        Invoke-PRComment -EventType "phase_failure" -PhaseLabel "$phase -> $Env" `
                         -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun `
                         -Detail "$_"
        throw
    }
}

Export-ModuleMember -Function Invoke-DeployPhase
