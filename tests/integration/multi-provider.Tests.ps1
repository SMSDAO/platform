#Requires -Version 7.0
<#
.SYNOPSIS
    Integration test: Multi-provider deploy in DryRun mode.
    Exercises all supported providers for each environment tier.
#>

BeforeAll {
    $platformRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module (Join-Path $platformRoot "src/utils/logger.psm1")    -Force
    Import-Module (Join-Path $platformRoot "src/utils/json-tools.psm1") -Force
    Import-Module (Join-Path $platformRoot "src/providers/providers.psm1") -Force
}

Describe "Multi-provider — all providers × all environments (DryRun)" {

    BeforeEach {
        Push-Location $TestDrive
        New-Item -ItemType Directory -Force "k8s/Dev"     | Out-Null
        New-Item -ItemType Directory -Force "k8s/Staging" | Out-Null
        New-Item -ItemType Directory -Force "k8s/Prod"    | Out-Null
        Set-Content (Join-Path $TestDrive "deploy.sh") "#!/bin/bash"
    }
    AfterEach { Pop-Location }

    $testCases = @(
        @{ prov = "k8s";     envName = "Dev"     }
        @{ prov = "k8s";     envName = "Staging" }
        @{ prov = "k8s";     envName = "Prod"    }
        @{ prov = "azure";   envName = "Dev"     }
        @{ prov = "azure";   envName = "Staging" }
        @{ prov = "azure";   envName = "Prod"    }
        @{ prov = "aws";     envName = "Dev"     }
        @{ prov = "aws";     envName = "Staging" }
        @{ prov = "aws";     envName = "Prod"    }
        @{ prov = "vercel";  envName = "Dev"     }
        @{ prov = "vercel";  envName = "Staging" }
        @{ prov = "vercel";  envName = "Prod"    }
        @{ prov = "generic"; envName = "Dev"     }
        @{ prov = "generic"; envName = "Staging" }
        @{ prov = "generic"; envName = "Prod"    }
    )

    It "provider=<prov> env=<envName>" -TestCases $testCases {
        param($prov, $envName)
        $customArgs = @{}
        if ($prov -eq "vercel")  { $customArgs["vercelToken"]  = "token-placeholder" }
        if ($prov -eq "generic") { $customArgs["deployScript"] = (Join-Path $TestDrive "deploy.sh") }
        { Invoke-Provider -Name $prov -Env $envName -IsDryRun $true -CustomArgs $customArgs } |
            Should -Not -Throw
    }
}

Describe "Provider CustomArgs pass-through (DryRun)" {

    BeforeEach {
        Push-Location $TestDrive
        New-Item -ItemType Directory -Force "k8s/Dev" | Out-Null
    }
    AfterEach { Pop-Location }

    It "k8s provider accepts namespace override" {
        { Invoke-Provider -Name k8s -Env Dev -IsDryRun $true `
                          -CustomArgs @{ namespace = "custom-ns" } } |
            Should -Not -Throw
    }

    It "aws provider accepts region override" {
        { Invoke-Provider -Name aws -Env Dev -IsDryRun $true `
                          -CustomArgs @{ awsRegion = "eu-west-1" } } |
            Should -Not -Throw
    }

    It "vercel provider accepts project override" {
        { Invoke-Provider -Name vercel -Env Dev -IsDryRun $true `
                          -CustomArgs @{ project = "my-app"; vercelToken = "token-placeholder" } } |
            Should -Not -Throw
    }
}
