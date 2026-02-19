#Requires -Version 7.0
<#
.SYNOPSIS
    SMSDAO Platform — Build Phase
.DESCRIPTION
    Single source of truth for build logic across all repo types.
    YAML workflows call pipeline.ps1 which calls this module.
    Local devs run the same script. Nothing is duplicated in YAML.
#>

using module ../utils/logger.psm1
using module ../utils/json-tools.psm1
using module ../reporting/pr-comment.psm1

function Invoke-BuildPhase {
    param(
        [Parameter(Mandatory=$true)]
        [object]$RepoProfile,       # RepoProfile from repo-detect.psm1

        [string]$Env          = "Dev",
        [hashtable]$CustomArgs = @{},
        [bool]$IsDryRun        = $false,
        [string]$PRNumber      = $env:PR_NUMBER,
        [string]$Token         = $env:GH_TOKEN,
        [string]$Repo          = $env:GITHUB_REPOSITORY
    )

    $phase = "Build"
    $start = Get-Date
    Write-Step "Phase: $phase" -Phase $phase

    Invoke-PRComment -EventType "phase_start" -PhaseLabel $phase `
                     -Env $Env -Token $Token -Repo $Repo -PR $PRNumber `
                     -IsDryRun $IsDryRun

    try {
        switch ($RepoProfile.Type) {
            { $_ -in "nextjs","node","electron" } {
                Write-Info "Node build (type=$($RepoProfile.Type))" -Phase $phase

                if (-not $IsDryRun) {
                    # npm ci — deterministic install, never npm install
                    & npm ci
                    if ($LASTEXITCODE -ne 0) { throw "npm ci failed." }

                    # Typecheck before build to catch type errors early
                    if ($RepoProfile.HasTypecheck) {
                        & npm run typecheck
                        if ($LASTEXITCODE -ne 0) { throw "typecheck failed." }
                    }

                    & npm run build
                    if ($LASTEXITCODE -ne 0) { throw "npm run build failed." }
                } else {
                    Write-Dry "Would run: npm ci && npm run typecheck && npm run build" -Phase $phase
                }
            }

            "dotnet" {
                $buildArgs = @("build","--configuration","Release")
                $proj    = Get-ConfigValue "project"   -CustomArgs $CustomArgs
                $verbose = Get-ConfigValue "verbosity" -CustomArgs $CustomArgs
                $output  = Get-ConfigValue "output"    -CustomArgs $CustomArgs
                if ($proj)    { $buildArgs += $proj }
                if ($verbose) { $buildArgs += "--verbosity", $verbose }
                if ($output)  { $buildArgs += "--output",    $output }

                Write-Info "dotnet $($buildArgs -join ' ')" -Phase $phase

                if (-not $IsDryRun) {
                    & dotnet @buildArgs
                    if ($LASTEXITCODE -ne 0) { throw "dotnet build failed (exit $LASTEXITCODE)." }
                } else {
                    Write-Dry "Would run: dotnet $($buildArgs -join ' ')" -Phase $phase
                }
            }

            "solidity" {
                if (-not $IsDryRun) {
                    & npm ci
                    if ($LASTEXITCODE -ne 0) { throw "npm ci failed." }
                    & npx hardhat compile
                    if ($LASTEXITCODE -ne 0) { throw "Hardhat compile failed." }
                } else {
                    Write-Dry "Would run: npm ci && npx hardhat compile" -Phase $phase
                }
            }

            "tauri" {
                if (-not $IsDryRun) {
                    & npm ci
                    if ($LASTEXITCODE -ne 0) { throw "npm ci failed." }
                    & npm run tauri build
                    if ($LASTEXITCODE -ne 0) { throw "Tauri build failed." }
                } else {
                    Write-Dry "Would run: npm ci && npm run tauri build" -Phase $phase
                }
            }

            default {
                Write-Info "Generic build" -Phase $phase
                if (-not $IsDryRun) {
                    if (Test-Path "./package.json") { & npm ci }
                    & npm run build
                    if ($LASTEXITCODE -ne 0) { throw "Generic build failed." }
                } else {
                    Write-Dry "Would run: npm ci && npm run build" -Phase $phase
                }
            }
        }

        $duration = (Get-Date) - $start
        Write-OK "Build succeeded in $([math]::Round($duration.TotalSeconds,1))s" -Phase $phase
        Invoke-PRComment -EventType "phase_success" -PhaseLabel $phase `
                         -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun `
                         -Metadata @{ repoType = $RepoProfile.Type; duration = "$([math]::Round($duration.TotalSeconds,1))s" }
        return @{ status = "pass"; duration = $duration }
    }
    catch {
        $duration = (Get-Date) - $start
        Invoke-PRComment -EventType "phase_failure" -PhaseLabel $phase `
                         -Env $Env -Token $Token -Repo $Repo -PR $PRNumber -IsDryRun $IsDryRun `
                         -Detail "$_"
        throw
    }
}

Export-ModuleMember -Function Invoke-BuildPhase
