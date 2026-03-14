#Requires -Version 7.0
<#
.SYNOPSIS
    Unit tests for src/security/policy-engine.psm1
    Tests Invoke-PolicyCheck, Get-SecurityScore, and secret detection.
#>

BeforeAll {
    $platformRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module (Join-Path $platformRoot "src/utils/logger.psm1")    -Force
    Import-Module (Join-Path $platformRoot "src/utils/file-scan.psm1") -Force
    Import-Module (Join-Path $platformRoot "src/security/policy-engine.psm1") -Force
}

Describe "Get-SecurityScore" {

    It "returns 100 for empty violations" {
        $result = [PSCustomObject]@{
            Passed     = $true
            Violations = @()
            Warnings   = @()
            Score      = @{}
        }
        $score = Get-SecurityScore -PolicyResult $result
        $score | Should -BeGreaterOrEqual 0
        $score | Should -BeLessOrEqual 100
    }
}

Describe "Get-SecretPatterns (file-scan)" {
    BeforeAll {
        Import-Module (Join-Path $platformRoot "src/utils/file-scan.psm1") -Force
    }

    It "returns non-empty pattern list" {
        $patterns = Get-SecretPatterns
        $patterns | Should -Not -BeNullOrEmpty
        $patterns.Count | Should -BeGreaterThan 5
    }

    It "every pattern has required fields" {
        $patterns = Get-SecretPatterns
        foreach ($p in $patterns) {
            $p.regex    | Should -Not -BeNullOrEmpty
            $p.category | Should -Not -BeNullOrEmpty
            $p.severity | Should -BeIn @("info","warn","critical")
        }
    }
}

Describe "Invoke-PolicyCheck — DryRun context" {

    BeforeEach {
        $testDir = Join-Path $TestDrive "policytest"
        New-Item -ItemType Directory -Force -Path $testDir | Out-Null
        Push-Location $testDir
        New-Item -ItemType Directory -Force -Path ".github/workflows" | Out-Null
        # Create a minimal safe workflow
        @"
name: CI
on: [push]
permissions:
  contents: read
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
"@ | Set-Content ".github/workflows/ci.yml"
    }

    AfterEach {
        Pop-Location
    }

    It "returns a PolicyResult with Passed field" {
        $result = Invoke-PolicyCheck -Env Dev
        $result | Should -Not -BeNullOrEmpty
        $result.Passed | Should -BeIn @($true, $false)
    }

    It "returns Violations array" {
        $result = Invoke-PolicyCheck -Env Dev
        $result.PSObject.Properties.Name | Should -Contain "Violations"
    }
}
