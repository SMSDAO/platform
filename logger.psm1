#Requires -Version 7.0
<#
.SYNOPSIS
    SMSDAO Platform — Structured Logger
.DESCRIPTION
    Single source of truth for all console output across every module.
    Supports structured log levels, machine-readable JSON mode for CI,
    and an in-memory log buffer that can be exported for metrics.
#>

$script:LogBuffer  = [System.Collections.Generic.List[hashtable]]::new()
$script:JsonMode   = [bool]($env:SMSDAO_LOG_JSON -eq "true")
$script:LogLevel   = $env:SMSDAO_LOG_LEVEL ?? "INFO"   # DEBUG | INFO | WARN | ERROR

$LevelOrder = @{ DEBUG = 0; INFO = 1; WARN = 2; ERROR = 3 }

function Write-Log {
    param(
        [ValidateSet("DEBUG","INFO","WARN","ERROR")]
        [string]$Level   = "INFO",
        [string]$Message = "",
        [string]$Phase   = "",
        [hashtable]$Data = @{}
    )

    # Level gate
    if ($LevelOrder[$Level] -lt $LevelOrder[$script:LogLevel]) { return }

    $entry = @{
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        level     = $Level
        phase     = $Phase
        message   = $Message
        data      = $Data
    }
    $script:LogBuffer.Add($entry)

    if ($script:JsonMode) {
        $entry | ConvertTo-Json -Compress -Depth 3 | Write-Host
        return
    }

    $color = switch ($Level) {
        "DEBUG" { "DarkGray"  }
        "INFO"  { "DarkCyan"  }
        "WARN"  { "Yellow"    }
        "ERROR" { "Red"       }
    }
    $prefix = switch ($Level) {
        "DEBUG" { "  .  " }
        "INFO"  { "  i  " }
        "WARN"  { " (!!) " }
        "ERROR" { " [!!] " }
    }

    $phaseTag = if ($Phase) { "[$Phase] " } else { "" }
    Write-Host "$prefix$phaseTag$Message" -ForegroundColor $color
}

# Convenience wrappers — these are what every other module calls
function Write-Step([string]$Message, [string]$Phase = "") {
    Write-Host "`n[STEP] $Message" -ForegroundColor Cyan
    Write-Log -Level INFO -Message $Message -Phase $Phase
}
function Write-Info([string]$Message,  [string]$Phase = "") { Write-Log -Level INFO  -Message $Message  -Phase $Phase }
function Write-Warn([string]$Message,  [string]$Phase = "") { Write-Log -Level WARN  -Message $Message  -Phase $Phase }
function Write-OK([string]$Message,    [string]$Phase = "") {
    Write-Host "  OK $Message" -ForegroundColor Green
    Write-Log -Level INFO -Message "OK: $Message" -Phase $Phase
}
function Write-Fail([string]$Message,  [string]$Phase = "") {
    Write-Host "  !! $Message" -ForegroundColor Red
    Write-Log -Level ERROR -Message $Message -Phase $Phase
}
function Write-Dry([string]$Message,   [string]$Phase = "") {
    Write-Host "  >> [DRY-RUN] $Message" -ForegroundColor Magenta
    Write-Log -Level DEBUG -Message "[DRY] $Message" -Phase $Phase
}

function Get-LogBuffer { return $script:LogBuffer.ToArray() }

function Export-LogJson([string]$Path = "./pipeline-run.log.json") {
    $script:LogBuffer | ConvertTo-Json -Depth 5 | Set-Content $Path -Encoding UTF8
    Write-Info "Log exported: $Path"
}

Export-ModuleMember -Function Write-Step, Write-Info, Write-Warn, Write-OK, Write-Fail, Write-Dry, Write-Log, Get-LogBuffer, Export-LogJson
