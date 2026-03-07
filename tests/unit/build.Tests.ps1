#Requires -Version 7.0
<#
.SYNOPSIS
    Unit tests for src/phases/build.psm1
    Tests Invoke-BuildPhase for all repo types in DryRun mode.
#>

BeforeAll {
    $platformRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module (Join-Path $platformRoot "src/utils/logger.psm1")    -Force
    Import-Module (Join-Path $platformRoot "src/utils/json-tools.psm1") -Force
    Import-Module (Join-Path $platformRoot "src/reporting/pr-comment.psm1") -Force
    Import-Module (Join-Path $platformRoot "src/phases/build.psm1")    -Force

    function New-RepoProfile([string]$Type, [bool]$HasTypecheck = $false) {
        return [PSCustomObject]@{
            Type         = $Type
            HasLint      = $false
            HasTypecheck = $HasTypecheck
            HasTest      = $false
            HasBuild     = $true
            NodeVersion  = "20"
            Frameworks   = @()
            Scripts      = @{}
            IsMonorepo   = $false
        }
    }
}

Describe "Invoke-BuildPhase — DryRun" {

    BeforeEach {
        Push-Location $TestDrive
    }
    AfterEach {
        Pop-Location
    }

    It "returns pass for nextjs repo type" {
        $result = Invoke-BuildPhase -RepoProfile (New-RepoProfile "nextjs") `
                                    -Env Dev -IsDryRun $true
        $result.status | Should -Be "pass"
    }

    It "returns pass for node repo type" {
        $result = Invoke-BuildPhase -RepoProfile (New-RepoProfile "node") `
                                    -Env Dev -IsDryRun $true
        $result.status | Should -Be "pass"
    }

    It "returns pass for dotnet repo type" {
        $result = Invoke-BuildPhase -RepoProfile (New-RepoProfile "dotnet") `
                                    -Env Dev -IsDryRun $true
        $result.status | Should -Be "pass"
    }

    It "returns pass for solidity repo type" {
        $result = Invoke-BuildPhase -RepoProfile (New-RepoProfile "solidity") `
                                    -Env Dev -IsDryRun $true
        $result.status | Should -Be "pass"
    }

    It "returns pass for tauri repo type" {
        $result = Invoke-BuildPhase -RepoProfile (New-RepoProfile "tauri") `
                                    -Env Dev -IsDryRun $true
        $result.status | Should -Be "pass"
    }

    It "returns pass for generic repo type" {
        $result = Invoke-BuildPhase -RepoProfile (New-RepoProfile "generic") `
                                    -Env Dev -IsDryRun $true
        $result.status | Should -Be "pass"
    }

    It "result includes duration" {
        $result = Invoke-BuildPhase -RepoProfile (New-RepoProfile "node") `
                                    -Env Dev -IsDryRun $true
        $result.duration | Should -Not -BeNullOrEmpty
    }
}
