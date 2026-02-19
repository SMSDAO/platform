#Requires -Version 7.0
<#
.SYNOPSIS
    SMSDAO Platform — JSON Config & Secret Tools
.DESCRIPTION
    Loads config.<Env>.json once at boot. All phases resolve values
    via Get-ConfigValue() using precedence:
        CustomArgs > config.<Env>.json > default
    Secrets NEVER live in config files — they arrive via CustomArgs
    injected from GitHub Secrets.
#>

using module ./logger.psm1

$script:LoadedConfig = @{}
$script:LoadedEnv    = ""

function Import-EnvConfig {
    <#
    .SYNOPSIS
        Load config.<Env>.json into the module-scoped config store.
    .PARAMETER Env
        Target environment: Dev | Staging | Prod
    .PARAMETER ConfigRoot
        Root directory to search for config files. Default: ./templates
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Env,

        [string]$ConfigRoot = "."
    )

    $script:LoadedEnv    = $Env
    $script:LoadedConfig = @{}

    # Search order: repo root, templates/, config/
    $candidates = @(
        "$ConfigRoot/config.$Env.json",
        "$ConfigRoot/templates/config.$Env.json",
        "$ConfigRoot/config/config.$Env.json"
    )

    $configFile = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $configFile) {
        Write-Info "No config.$Env.json found — running on CustomArgs + defaults only."
        return
    }

    try {
        $raw = Get-Content $configFile -Raw | ConvertFrom-Json
        $raw.PSObject.Properties |
            Where-Object { $_.Name -notlike "_*" } |     # skip _comment, _note etc.
            ForEach-Object { $script:LoadedConfig[$_.Name] = $_.Value }

        Write-OK "Config loaded: $configFile"
        Write-Info "  Keys: $($script:LoadedConfig.Keys -join ', ')"
        return $configFile
    }
    catch {
        throw "Failed to parse $configFile — $_"
    }
}

function Get-ConfigValue {
    <#
    .SYNOPSIS
        Resolve a config key with precedence: CustomArgs > config.json > Default.
    .PARAMETER Key
        Config key to look up.
    .PARAMETER Default
        Fallback if key is not found anywhere.
    .PARAMETER CustomArgs
        Runtime overrides hashtable (typically $PSBoundParameters or pipeline arg).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        $Default    = $null,
        [hashtable]$CustomArgs = @{}
    )

    if ($CustomArgs.ContainsKey($Key))           { return $CustomArgs[$Key] }
    if ($script:LoadedConfig.ContainsKey($Key))  { return $script:LoadedConfig[$Key] }
    return $Default
}

function Get-AllConfig {
    return $script:LoadedConfig.Clone()
}

function Assert-NoSecretsInConfig {
    <#
    .SYNOPSIS
        Scan the loaded config for any key that looks like it holds a real secret value.
        Config files must contain only placeholders.
    #>
    $secretKeyPattern = '(?i)(password|secret|private_key|api_key|token|credential)'
    $placeholderRx    = '(?i)(placeholder|example\.com|your-|<.+>|REPLACE)'

    $violations = @()
    foreach ($key in $script:LoadedConfig.Keys) {
        if ($key -match $secretKeyPattern) {
            $val = "$($script:LoadedConfig[$key])"
            if ($val -and $val.Length -gt 4 -and $val -notmatch $placeholderRx) {
                $violations += "Config key '$key' appears to contain a real secret value."
            }
        }
    }

    if ($violations.Count -gt 0) {
        $violations | ForEach-Object { Write-Fail $_ }
        throw "Secret detected in config file. Move secrets to GitHub Secrets + CustomArgs."
    }

    Write-OK "Config secret scan passed — no raw secrets detected."
}

Export-ModuleMember -Function Import-EnvConfig, Get-ConfigValue, Get-AllConfig, Assert-NoSecretsInConfig
