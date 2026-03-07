#Requires -Version 7.0
<#
.SYNOPSIS
    SMSDAO Platform — Repository Type Detector
.DESCRIPTION
    Structural analysis of a repository to classify its tech stack.
    Used by every phase to adapt build/test/deploy logic without
    embedding if/else chains in phase modules.
#>

using module ./logger.psm1

# Result object returned by Invoke-RepoDetect
class RepoProfile {
    [string]   $Type           # nextjs | node | tauri | electron | solidity | dotnet | generic
    [bool]     $HasLint
    [bool]     $HasTypecheck
    [bool]     $HasTest
    [bool]     $HasBuild
    [string]   $NodeVersion
    [string[]] $Frameworks
    [hashtable]$Scripts
    [bool]     $IsMonorepo
}

function Invoke-RepoDetect {
    <#
    .SYNOPSIS
        Detect repository type and surface build capability flags.
    .OUTPUTS
        RepoProfile
    #>
    [OutputType([RepoProfile])]
    param()

    Write-Step "Detecting repository type..."

    $profile            = [RepoProfile]::new()
    $profile.Frameworks = @()
    $profile.Scripts    = @{}

    # ── Tech stack detection (ordered by specificity) ────────────
    $profile.Type = switch ($true) {
        { Test-Path "./next.config.*" }    { "nextjs";   break }
        { Test-Path "./src-tauri" }         { "tauri";    break }
        { Test-Path "./hardhat.config.*" }  { "solidity"; break }
        {
            (Test-Path "./package.json") -and
            ((Get-Content "./package.json" -Raw) -match '"electron"')
        }                                   { "electron"; break }
        { Test-Path "./*.csproj" }          { "dotnet";   break }
        { Test-Path "./package.json" }      { "node";     break }
        default                             { "generic"          }
    }

    # ── Package.json introspection ───────────────────────────────
    if (Test-Path "./package.json") {
        $pkg = Get-Content "./package.json" -Raw | ConvertFrom-Json

        $profile.HasLint      = [bool]($pkg.scripts.lint)
        $profile.HasTypecheck = [bool]($pkg.scripts.typecheck)
        $profile.HasTest      = [bool]($pkg.scripts.test)
        $profile.HasBuild     = [bool]($pkg.scripts.build)
        $profile.NodeVersion  = "$($pkg.engines.node ?? "20")"
        $profile.Scripts      = @{}
        $pkg.scripts.PSObject.Properties | ForEach-Object {
            $profile.Scripts[$_.Name] = $_.Value
        }

        # Framework detection from dependencies
        $allDeps = @()
        if ($pkg.dependencies)    { $allDeps += $pkg.dependencies.PSObject.Properties.Name }
        if ($pkg.devDependencies) { $allDeps += $pkg.devDependencies.PSObject.Properties.Name }

        $frameworkMap = @{
            "react"   = "React"
            "vue"     = "Vue"
            "svelte"  = "Svelte"
            "angular" = "Angular"
            "express" = "Express"
            "fastify" = "Fastify"
            "ethers"  = "Ethers.js"
            "viem"    = "Viem"
            "wagmi"   = "Wagmi"
            "hardhat" = "Hardhat"
            "typechain" = "TypeChain"
        }
        $profile.Frameworks = $allDeps | Where-Object { $frameworkMap.ContainsKey($_) } |
                              ForEach-Object { $frameworkMap[$_] }
    }

    # ── Monorepo detection ───────────────────────────────────────
    $profile.IsMonorepo = (Test-Path "./packages") -or
                          (Test-Path "./apps") -or
                          (Test-Path "./pnpm-workspace.yaml") -or
                          ((Test-Path "./package.json") -and
                           (Get-Content "./package.json" -Raw) -match '"workspaces"')

    # ── Surface results ──────────────────────────────────────────
    Write-OK "Repo type: $($profile.Type)"
    Write-Info "  Monorepo    : $($profile.IsMonorepo)"
    Write-Info "  Frameworks  : $($profile.Frameworks -join ', ')"
    Write-Info "  HasLint     : $($profile.HasLint)"
    Write-Info "  HasTypecheck: $($profile.HasTypecheck)"
    Write-Info "  HasTest     : $($profile.HasTest)"
    Write-Info "  HasBuild    : $($profile.HasBuild)"

    return $profile
}

Export-ModuleMember -Function Invoke-RepoDetect
