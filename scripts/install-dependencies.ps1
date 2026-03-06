#Requires -Version 7.0
<#
.SYNOPSIS
    SMSDAO Platform — Development Environment Bootstrap
.DESCRIPTION
    Installs all PowerShell modules and tools required to develop and
    test the SMSDAO/platform locally. Idempotent — safe to run multiple times.
.EXAMPLE
    ./scripts/install-dependencies.ps1
.EXAMPLE
    ./scripts/install-dependencies.ps1 -Force
#>
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Install-IfMissing {
    param([string]$Module, [string]$MinVersion = "0.0.0")
    $existing = Get-Module -ListAvailable -Name $Module |
                Sort-Object Version -Descending |
                Select-Object -First 1
    if (-not $existing -or ([version]$existing.Version -lt [version]$MinVersion) -or $Force) {
        Write-Host "  Installing $Module..." -ForegroundColor Cyan
        Install-Module -Name $Module -MinimumVersion $MinVersion `
                       -Force -Scope CurrentUser -Repository PSGallery
        Write-Host "  $Module installed." -ForegroundColor Green
    } else {
        Write-Host "  $Module $($existing.Version) — OK" -ForegroundColor DarkGray
    }
}

Write-Host "`nSMSDAO Platform — Installing dependencies" -ForegroundColor Cyan
Write-Host "PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray

# Required for running platform tests
Install-IfMissing -Module "Pester"         -MinVersion "5.5.0"

# Required for YAML linting in module-lint workflow
Install-IfMissing -Module "powershell-yaml" -MinVersion "0.4.0"

# Required for PSScriptAnalyzer linting
Install-IfMissing -Module "PSScriptAnalyzer" -MinVersion "1.21.0"

Write-Host "`nAll dependencies installed." -ForegroundColor Green
Write-Host "You can now run: Invoke-Pester ./tests/unit/" -ForegroundColor DarkGray
