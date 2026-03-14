#Requires -Version 7.0
<#
.SYNOPSIS
    Integration test: Full pipeline execution in DryRun mode.
    Exercises the complete Build → Test → Deploy chain for a simulated node repo.
#>

BeforeAll {
    $platformRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module (Join-Path $platformRoot "src/utils/logger.psm1")    -Force
    Import-Module (Join-Path $platformRoot "src/utils/json-tools.psm1") -Force
    Import-Module (Join-Path $platformRoot "src/utils/repo-detect.psm1") -Force
    Import-Module (Join-Path $platformRoot "src/utils/file-scan.psm1")  -Force
    Import-Module (Join-Path $platformRoot "src/reporting/pr-comment.psm1") -Force
    Import-Module (Join-Path $platformRoot "src/reporting/summary-builder.psm1") -Force
    Import-Module (Join-Path $platformRoot "src/phases/build.psm1")     -Force
    Import-Module (Join-Path $platformRoot "src/phases/test.psm1")      -Force
    Import-Module (Join-Path $platformRoot "src/phases/deploy.psm1")    -Force
    Import-Module (Join-Path $platformRoot "src/phases/heal.psm1")      -Force
    Import-Module (Join-Path $platformRoot "src/phases/validate-env.psm1") -Force
    Import-Module (Join-Path $platformRoot "src/security/policy-engine.psm1") -Force
    Import-Module (Join-Path $platformRoot "src/orchestrator/pipeline-core.psm1") -Force
}

Describe "Full pipeline — node repo (DryRun)" {

    BeforeEach {
        $testRepo = Join-Path $TestDrive "noderepo"
        New-Item -ItemType Directory -Force -Path $testRepo | Out-Null
        Push-Location $testRepo

        '{"name":"test-node","scripts":{"build":"echo build","test":"echo test","lint":"echo lint"}}' |
            Set-Content "package.json"
        New-Item -ItemType Directory -Force ".github/workflows" | Out-Null
        @"
name: CI
on: [push]
permissions:
  contents: read
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
"@ | Set-Content ".github/workflows/ci.yml"
    }

    AfterEach { Pop-Location }

    It "Build phase succeeds" {
        $result = Invoke-Pipeline -Phase Build -Env Dev -DryRun
        $result | Should -Not -BeNullOrEmpty
    }

    It "Test phase succeeds" {
        $result = Invoke-Pipeline -Phase Test -Env Dev -DryRun
        $result | Should -Not -BeNullOrEmpty
    }

    It "ValidateEnv phase succeeds" {
        $result = Invoke-Pipeline -Phase ValidateEnv -Env Dev -DryRun
        $result | Should -Not -BeNullOrEmpty
    }

    It "Policy phase returns scored result" {
        $result = Invoke-Pipeline -Phase Policy -Env Dev -DryRun
        $result.status  | Should -BeIn @("pass","fail")
        $result.score   | Should -Not -BeNullOrEmpty
    }
}

Describe "Full pipeline — dotnet repo (DryRun)" {

    BeforeEach {
        $testRepo = Join-Path $TestDrive "dotnetrepo"
        New-Item -ItemType Directory -Force -Path $testRepo | Out-Null
        Push-Location $testRepo
        Set-Content "App.csproj" "<Project />"
    }

    AfterEach { Pop-Location }

    It "DetectRepo identifies dotnet" {
        $result = Invoke-Pipeline -Phase DetectRepo -Env Dev -DryRun
        $result.type | Should -Be "dotnet"
    }

    It "Build phase succeeds in DryRun" {
        $result = Invoke-Pipeline -Phase Build -Env Dev -DryRun
        $result | Should -Not -BeNullOrEmpty
    }
}
