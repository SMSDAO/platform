#Requires -Version 7.0
<#
.SYNOPSIS
    SMSDAO Platform — Summary Builder & Metrics Exporter
.DESCRIPTION
    Aggregates phase results into a single PR summary comment
    and exports metrics for dashboards / org-level tracking.
#>

using module ../utils/logger.psm1
using module ./pr-comment.psm1

# ── Phase result accumulator ─────────────────────────────────────
$script:PhaseResults = [ordered]@{}
$script:RunStart     = Get-Date

function Register-PhaseResult {
    param(
        [string]$PhaseName,
        [ValidateSet("pass","fail","skip","running")]
        [string]$Status,
        [timespan]$Duration,
        [hashtable]$Data = @{}
    )
    $script:PhaseResults[$PhaseName] = @{
        status   = $Status
        duration = $Duration.TotalSeconds
        data     = $Data
        at       = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }
}

function Get-RunSummary {
    $totalDuration = (Get-Date) - $script:RunStart
    $allPass       = -not ($script:PhaseResults.Values | Where-Object { $_.status -eq "fail" })

    return @{
        overallStatus = if ($allPass) { "success" } else { "failure" }
        totalSeconds  = [math]::Round($totalDuration.TotalSeconds, 1)
        phases        = $script:PhaseResults.Clone()
        phaseCount    = $script:PhaseResults.Count
        failCount     = ($script:PhaseResults.Values | Where-Object { $_.status -eq "fail" }).Count
    }
}

function New-SummaryComment {
    <#
    .SYNOPSIS
        Build the aggregate Markdown comment posted after all phases complete.
    #>
    param(
        [string]$Env   = "Dev",
        [string]$Phase = "Full",
        [string]$Repo  = ""
    )

    $botTag   = "<!-- smsdao-pipeline-bot -->"
    $summary  = Get-RunSummary
    $runUrl   = if ($env:GITHUB_RUN_ID -and $Repo) {
        "[$($env:GITHUB_RUN_NUMBER)](https://github.com/$Repo/actions/runs/$($env:GITHUB_RUN_ID))"
    } else { "local" }
    $ts       = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " UTC"

    $statusBadge = if ($summary.overallStatus -eq "success") {
        "![Passed](https://img.shields.io/badge/pipeline-passed-brightgreen)"
    } else {
        "![Failed](https://img.shields.io/badge/pipeline-failed-red)"
    }

    $icon = if ($summary.overallStatus -eq "success") { ":white_check_mark:" } else { ":x:" }

    # Phase rows
    $phaseRows = $script:PhaseResults.GetEnumerator() | ForEach-Object {
        $s = $_.Value.status
        $e = switch ($s) {
            "pass" { ":white_check_mark:" }
            "fail" { ":x:"               }
            "skip" { ":next_track_button:" }
            default { ":hourglass:"      }
        }
        $dur = "$([math]::Round($_.Value.duration, 1))s"
        "| $e | **$($_.Key)** | ``$s`` | $dur |"
    }

    return @"
$botTag
---
### $icon SMSDAO Pipeline Summary — ``$Phase`` · ``$Env`` $statusBadge

| | Phase | Result | Duration |
|---|---|---|---|
$($phaseRows -join "`n")

| Field | Value |
|---|---|
| Total Duration | ``$($summary.totalSeconds)s`` |
| Phases Run | $($summary.phaseCount) |
| Failures | $($summary.failCount) |
| Run | $runUrl |
| Timestamp | $ts |

> *[SMSDAO/platform](https://github.com/SMSDAO/platform) Smart Healing Pipeline*
"@
}

function Export-Metrics {
    <#
    .SYNOPSIS
        Export run metrics to JSON for org-level dashboard aggregation.
    #>
    param([string]$Path = "./pipeline-metrics.json")

    $summary = Get-RunSummary
    $metrics = @{
        run_id      = $env:GITHUB_RUN_ID
        run_number  = $env:GITHUB_RUN_NUMBER
        repo        = $env:GITHUB_REPOSITORY
        ref         = $env:GITHUB_REF_NAME
        sha         = $env:GITHUB_SHA
        actor       = $env:GITHUB_ACTOR
        workflow    = $env:GITHUB_WORKFLOW
        summary     = $summary
        recorded_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }

    $metrics | ConvertTo-Json -Depth 6 | Set-Content $Path -Encoding UTF8
    Write-OK "Metrics exported: $Path"
}

Export-ModuleMember -Function Register-PhaseResult, Get-RunSummary, New-SummaryComment, Export-Metrics
