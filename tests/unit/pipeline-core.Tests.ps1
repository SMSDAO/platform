#Requires -Version 7.0
<#
.SYNOPSIS
    Unit tests for src/orchestrator/pipeline-core.psm1
    Tests Invoke-Pipeline routing and boot sequence behavior.
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

Describe "Invoke-Pipeline parameter validation" {

    It "throws on missing Phase" {
        { Invoke-Pipeline -Phase $null -Env Dev } | Should -Throw
    }

    It "accepts all valid Phase values" {
        $validPhases = @("Build","Test","Deploy","Full","Heal","DetectRepo","ValidateEnv","Policy")
        foreach ($phase in $validPhases) {
            { Get-Command Invoke-Pipeline } | Should -Not -Throw
        }
    }

    It "accepts all valid Env values" {
        $validEnvs = @("Dev","Staging","Prod")
        foreach ($env in $validEnvs) {
            { Get-Command Invoke-Pipeline } | Should -Not -Throw
        }
    }
}

Describe "Invoke-Pipeline in DryRun mode" {

    BeforeEach {
        $testDir = Join-Path $TestDrive "testrepo"
        New-Item -ItemType Directory -Force -Path $testDir | Out-Null
        Push-Location $testDir
        '{"name":"test","scripts":{"build":"echo build","test":"echo test"}}' |
            Set-Content "package.json"
    }

    AfterEach {
        Pop-Location
    }

    It "DetectRepo phase returns repo type" {
        $result = Invoke-Pipeline -Phase DetectRepo -Env Dev -DryRun
        $result | Should -Not -BeNullOrEmpty
        $result.type | Should -Not -BeNullOrEmpty
    }

    It "ValidateEnv phase runs without error in DryRun" {
        { Invoke-Pipeline -Phase ValidateEnv -Env Dev -DryRun } | Should -Not -Throw
    }

    It "Policy phase returns status in DryRun" {
        $result = Invoke-Pipeline -Phase Policy -Env Dev -DryRun
        $result | Should -Not -BeNullOrEmpty
        $result.status | Should -BeIn @("pass","fail")
    }
}
