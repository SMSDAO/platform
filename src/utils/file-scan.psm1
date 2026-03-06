#Requires -Version 7.0
<#
.SYNOPSIS
    SMSDAO Platform — File Scanner
.DESCRIPTION
    Reusable pattern-matching engine used by security modules.
    Returns structured scan results rather than writing directly
    to the console — callers decide how to present findings.
#>

using module ./logger.psm1

class ScanResult {
    [string]   $File
    [string]   $Pattern
    [string]   $Category
    [string]   $Severity    # info | warn | critical
    [int]      $LineNumber
    [string]   $Match
}

function Invoke-FilePatternScan {
    <#
    .SYNOPSIS
        Scan files matching include globs for regex patterns.
    .PARAMETER Paths
        Directories to recurse into.
    .PARAMETER Include
        File extension globs, e.g. "*.ts","*.js"
    .PARAMETER Patterns
        Array of hashtables: @{ regex=...; category=...; severity=... }
    .OUTPUTS
        ScanResult[]
    #>
    param(
        [string[]]$Paths    = @("."),
        [string[]]$Include  = @("*.ts","*.tsx","*.js","*.jsx","*.ps1","*.json","*.yml"),
        [Parameter(Mandatory=$true)]
        [hashtable[]]$Patterns,
        [string[]]$Exclude  = @("node_modules","dist",".next","coverage","*.min.js")
    )

    $results = [System.Collections.Generic.List[ScanResult]]::new()

    $files = Get-ChildItem -Path $Paths -Include $Include -Recurse -ErrorAction SilentlyContinue |
             Where-Object {
                 $path = $_.FullName
                 -not ($Exclude | Where-Object { $path -match [regex]::Escape($_) })
             }

    foreach ($file in $files) {
        try {
            $lines = Get-Content $file.FullName -ErrorAction SilentlyContinue
            if (-not $lines) { continue }

            for ($i = 0; $i -lt $lines.Count; $i++) {
                foreach ($p in $Patterns) {
                    if ($lines[$i] -match $p.regex) {
                        $r           = [ScanResult]::new()
                        $r.File      = $file.FullName
                        $r.Pattern   = $p.regex
                        $r.Category  = $p.category ?? "general"
                        $r.Severity  = $p.severity  ?? "warn"
                        $r.LineNumber= $i + 1
                        $r.Match     = ($Matches[0] -replace '(?<=.{6}).+(?=.{4})', '***')  # partial mask
                        $results.Add($r)
                    }
                }
            }
        }
        catch { Write-Warn "Could not scan $($file.Name): $_" }
    }

    return $results.ToArray()
}

function Get-SecretPatterns {
    <#
    .SYNOPSIS
        Return the canonical SMSDAO secret detection pattern set.
    #>
    return @(
        @{ regex = '(?i)(password|passwd)\s*[=:]\s*[''"][^''""]{8,}'; category = "hardcoded-password"; severity = "critical" }
        @{ regex = 'sk-[A-Za-z0-9]{32,}';                             category = "openai-key";         severity = "critical" }
        @{ regex = 'AKIA[0-9A-Z]{16}';                                category = "aws-access-key";     severity = "critical" }
        @{ regex = 'ghp_[A-Za-z0-9]{36}';                             category = "github-pat";         severity = "critical" }
        @{ regex = 'xox[baprs]-[A-Za-z0-9\-]{10,}';                  category = "slack-token";         severity = "critical" }
        @{ regex = '(?i)private_key\s*[=:]\s*[''"]-----BEGIN';        category = "private-key";        severity = "critical" }
        @{ regex = '(?i)api[_-]?key\s*[=:]\s*[''"][A-Za-z0-9]{16,}'; category = "api-key";            severity = "warn"     }
        @{ regex = 'https://mainnet\.infura\.io';                      category = "hardcoded-rpc";      severity = "warn"     }
        @{ regex = 'https://eth-mainnet\.g\.alchemy\.com';             category = "hardcoded-rpc";      severity = "warn"     }
    )
}

Export-ModuleMember -Function Invoke-FilePatternScan, Get-SecretPatterns
