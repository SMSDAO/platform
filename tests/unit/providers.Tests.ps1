#Requires -Version 7.0
<#
.SYNOPSIS
    Unit tests for src/providers/providers.psm1
    Tests provider dispatch and individual provider functions in DryRun mode.
#>

BeforeAll {
    $platformRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module (Join-Path $platformRoot "src/utils/logger.psm1")    -Force
    Import-Module (Join-Path $platformRoot "src/utils/json-tools.psm1") -Force
    Import-Module (Join-Path $platformRoot "src/providers/providers.psm1") -Force
}

Describe "Invoke-Provider — DryRun" {

    BeforeEach {
        Push-Location $TestDrive
        New-Item -ItemType Directory -Force "k8s/Dev" | Out-Null
        New-Item -ItemType Directory -Force "k8s/Staging" | Out-Null
        New-Item -ItemType Directory -Force "k8s/Prod" | Out-Null
    }
    AfterEach {
        Pop-Location
    }

    It "dispatches to k8s provider" {
        { Invoke-Provider -Name k8s -Env Dev -IsDryRun $true } | Should -Not -Throw
    }

    It "dispatches to azure provider" {
        { Invoke-Provider -Name azure -Env Dev -IsDryRun $true } | Should -Not -Throw
    }

    It "dispatches to aws provider" {
        { Invoke-Provider -Name aws -Env Dev -IsDryRun $true } | Should -Not -Throw
    }

    It "dispatches to vercel provider" {
        { Invoke-Provider -Name vercel -Env Dev -IsDryRun $true `
                          -CustomArgs @{ vercelToken = "token-placeholder" } } |
            Should -Not -Throw
    }

    It "dispatches to generic provider" {
        $script = Join-Path $TestDrive "deploy.sh"
        Set-Content $script "#!/bin/bash"
        { Invoke-Provider -Name generic -Env Dev -IsDryRun $true `
                          -CustomArgs @{ deployScript = $script } } |
            Should -Not -Throw
    }

    It "throws on unknown provider" {
        { Invoke-Provider -Name "unknownprovider" -Env Dev -IsDryRun $true } | Should -Throw
    }
}
