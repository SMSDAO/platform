<#
.SYNOPSIS
    SMSDAO Platform — Pipeline Entry Point
.DESCRIPTION
    Intentionally thin. All logic lives in src/orchestrator/pipeline-core.psm1.
    This script is the only file that consumer repos need to call.
    DRY principle: YAML calls this; local devs call this. One command for both.
.EXAMPLE
    ./bin/pipeline.ps1 -Phase Full -Env Staging -PRNumber 42
.EXAMPLE
    ./bin/pipeline.ps1 -Phase Heal -Env Dev -DryRun
.EXAMPLE
    ./bin/pipeline.ps1 -Phase Build -Env Prod -Args @{ output = "./dist" }
#>
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Build","Test","Deploy","Full","Heal","DetectRepo","ValidateEnv","Policy")]
    [string]$Phase,

    [ValidateSet("Dev","Staging","Prod")]
    [string]$Env = "Dev",

    [hashtable]$Args = @{},

    [switch]$DryRun,

    [string]$PRNumber  = $env:PR_NUMBER,
    [string]$Token     = $env:GH_TOKEN,
    [string]$Repo      = $env:GITHUB_REPOSITORY
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve module root relative to this script regardless of CWD
$platformRoot  = Split-Path -Parent $PSScriptRoot
$orchestrator  = Join-Path $platformRoot "src/orchestrator/pipeline-core.psm1"

if (-not (Test-Path $orchestrator)) {
    Write-Error "Orchestrator not found at: $orchestrator`nRun from the SMSDAO/platform repo root."
    exit 1
}

Import-Module $orchestrator -Force

try {
    Invoke-Pipeline `
        -Phase     $Phase `
        -Env       $Env `
        -Args      $Args `
        -DryRun:   $DryRun `
        -PRNumber  $PRNumber `
        -Token     $Token `
        -Repo      $Repo
}
catch {
    Write-Host "`n[FATAL] $Phase failed: $_" -ForegroundColor Red
    exit 1
}
