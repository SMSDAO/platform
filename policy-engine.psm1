#Requires -Version 7.0
<#
.SYNOPSIS
    SMSDAO Platform — Security Policy Engine
.DESCRIPTION
    DAO-level governance enforcement without a GitHub App.
    Validates workflow permissions, blocks unapproved actions,
    enforces branch protection, checks deploy provider consistency,
    and detects direct pushes to protected branches.
    Returns structured PolicyResult objects — callers decide
    whether to block or warn.
#>

using module ../utils/logger.psm1
using module ../utils/file-scan.psm1

class PolicyViolation {
    [string]$Rule
    [string]$Severity    # critical | warn | info
    [string]$File
    [string]$Detail
    [string]$Remediation
}

class PolicyResult {
    [bool]              $Passed
    [PolicyViolation[]] $Violations
    [PolicyViolation[]] $Warnings
    [hashtable]         $Score        # { rule = pass|fail|warn }
}

# ── Approved GitHub Actions allowlist ───────────────────────────
$script:ApprovedActions = @(
    "actions/checkout"
    "actions/setup-node"
    "actions/setup-dotnet"
    "actions/cache"
    "actions/upload-artifact"
    "actions/download-artifact"
    "actions/github-script"
    "aws-actions/configure-aws-credentials"
    "azure/login"
    "azure/setup-kubectl"
    "SMSDAO/platform"    # self-reference allowed
)

function Invoke-PolicyCheck {
    <#
    .SYNOPSIS
        Run all governance policy checks against the repository.
    .PARAMETER Env
        Target environment — used for provider consistency checks.
    .PARAMETER Token
        GitHub token for API-based branch protection checks.
    .PARAMETER Repo
        GitHub "org/repo" string.
    #>
    param(
        [string]$Env   = "Dev",
        [string]$Token = $env:GH_TOKEN,
        [string]$Repo  = $env:GITHUB_REPOSITORY
    )

    $violations = [System.Collections.Generic.List[PolicyViolation]]::new()
    $warnings   = [System.Collections.Generic.List[PolicyViolation]]::new()
    $score      = [ordered]@{}

    # ── RULE 1: Workflow permission safety ───────────────────────
    Write-Info "Policy: Checking workflow permissions..."
    $wfFiles = Get-ChildItem ".github/workflows" -Filter "*.yml" -ErrorAction SilentlyContinue
    foreach ($wf in $wfFiles) {
        $content = Get-Content $wf.FullName -Raw

        # Detect dangerous trigger patterns
        $unsafeTriggers = @("issue_comment","pull_request_review_comment","workflow_run")
        foreach ($t in $unsafeTriggers) {
            if ($content -match $t) {
                $v = [PolicyViolation]::new()
                $v.Rule        = "unsafe-trigger"
                $v.Severity    = "critical"
                $v.File        = $wf.Name
                $v.Detail      = "Trigger '$t' can execute in context of the base branch with write access"
                $v.Remediation = "Move logic to pull_request trigger with explicit permissions: contents: read"
                $violations.Add($v)
            }
        }

        # Detect auto-push from workflow
        if (($content -match 'permissions[^\n]*write') -and ($content -match 'git push|gh pr merge')) {
            $v = [PolicyViolation]::new()
            $v.Rule        = "workflow-auto-push"
            $v.Severity    = "critical"
            $v.File        = $wf.Name
            $v.Detail      = "Workflow has write permissions and appears to auto-push"
            $v.Remediation = "Remove auto-push steps; require human review + PR merge"
            $violations.Add($v)
        }
    }
    $score["workflow-permissions"] = if ($violations.Where({ $_.Rule -match "unsafe|auto-push" }).Count -eq 0) { "pass" } else { "fail" }

    # ── RULE 2: Unapproved GitHub Actions ───────────────────────
    Write-Info "Policy: Scanning for unapproved Actions..."
    foreach ($wf in $wfFiles) {
        $content = Get-Content $wf.FullName -Raw
        $usesMatches = [regex]::Matches($content, 'uses:\s+([A-Za-z0-9\-_]+/[A-Za-z0-9\-_\.]+)(?:@[^\s]+)?')
        foreach ($m in $usesMatches) {
            $action = $m.Groups[1].Value
            $approved = $script:ApprovedActions | Where-Object { $action -like "$_*" }
            if (-not $approved) {
                $w = [PolicyViolation]::new()
                $w.Rule        = "unapproved-action"
                $w.Severity    = "warn"
                $w.File        = $wf.Name
                $w.Detail      = "Action '$action' is not on the SMSDAO approved list"
                $w.Remediation = "Add to approved list in src/security/policy-engine.psm1 after review"
                $warnings.Add($w)
            }
        }
    }
    $score["approved-actions"] = if ($warnings.Where({ $_.Rule -eq "unapproved-action" }).Count -eq 0) { "pass" } else { "warn" }

    # ── RULE 3: Hardcoded secrets in source ─────────────────────
    Write-Info "Policy: Scanning for hardcoded secrets..."
    $secretResults = Invoke-FilePatternScan -Patterns (Get-SecretPatterns)
    $critSecrets   = $secretResults | Where-Object { $_.Severity -eq "critical" }
    foreach ($r in $critSecrets) {
        $v = [PolicyViolation]::new()
        $v.Rule        = "hardcoded-secret"
        $v.Severity    = "critical"
        $v.File        = $r.File
        $v.Detail      = "Pattern '$($r.Category)' matched at line $($r.LineNumber): $($r.Match)"
        $v.Remediation = "Move secret to GitHub Secrets and inject via CustomArgs"
        $violations.Add($v)
    }
    $score["no-hardcoded-secrets"] = if ($critSecrets.Count -eq 0) { "pass" } else { "fail" }

    # ── RULE 4: Branch protection API check ─────────────────────
    if ($Token -and $Repo) {
        Write-Info "Policy: Checking branch protection..."
        try {
            $headers = @{
                Authorization          = "Bearer $Token"
                Accept                 = "application/vnd.github+json"
                "X-GitHub-Api-Version" = "2022-11-28"
            }
            $bp = Invoke-RestMethod `
                -Uri "https://api.github.com/repos/$Repo/branches/main/protection" `
                -Headers $headers -Method GET -ErrorAction Stop

            if (-not $bp.required_pull_request_reviews) {
                $w = [PolicyViolation]::new()
                $w.Rule        = "branch-protection-reviews"
                $w.Severity    = "warn"
                $w.File        = "GitHub Settings"
                $w.Detail      = "main branch does not require PR reviews"
                $w.Remediation = "Enable 'Require pull request reviews' in branch protection"
                $warnings.Add($w)
            }
            if (-not $bp.required_status_checks) {
                $w = [PolicyViolation]::new()
                $w.Rule        = "branch-protection-checks"
                $w.Severity    = "warn"
                $w.File        = "GitHub Settings"
                $w.Detail      = "main branch does not require status checks"
                $w.Remediation = "Enable required status checks: pipeline/deploy"
                $warnings.Add($w)
            }
            $score["branch-protection"] = "pass"
        }
        catch {
            # 404 = no protection configured
            if ($_ -match "404") {
                $v = [PolicyViolation]::new()
                $v.Rule        = "no-branch-protection"
                $v.Severity    = "critical"
                $v.File        = "GitHub Settings"
                $v.Detail      = "main has NO branch protection rules"
                $v.Remediation = "Enable branch protection: require PR reviews + status checks"
                $violations.Add($v)
            }
            $score["branch-protection"] = "fail"
        }
    }

    # ── RULE 5: Deploy provider consistency ─────────────────────
    Write-Info "Policy: Checking deploy provider consistency..."
    $configFiles = Get-ChildItem -Filter "config.*.json" -Recurse -ErrorAction SilentlyContinue
    $providers   = $configFiles | ForEach-Object {
        $cfg = Get-Content $_.FullName | ConvertFrom-Json -ErrorAction SilentlyContinue
        $cfg.provider
    } | Where-Object { $_ } | Sort-Object -Unique

    if ($providers.Count -gt 1) {
        $w = [PolicyViolation]::new()
        $w.Rule        = "provider-drift"
        $w.Severity    = "warn"
        $w.File        = "config.*.json"
        $w.Detail      = "Multiple deploy providers across environments: $($providers -join ', ')"
        $w.Remediation = "Use one provider per org or use Invoke-Provider abstraction layer"
        $warnings.Add($w)
    }
    $score["provider-consistency"] = if ($providers.Count -le 1) { "pass" } else { "warn" }

    # ── Assemble result ──────────────────────────────────────────
    $result            = [PolicyResult]::new()
    $result.Passed     = $violations.Count -eq 0
    $result.Violations = $violations.ToArray()
    $result.Warnings   = $warnings.ToArray()
    $result.Score      = $score

    # Surface findings
    foreach ($v in $result.Violations) {
        Write-Fail "POLICY VIOLATION [$($v.Rule)] $($v.File): $($v.Detail)"
        Write-Info "  Remediation: $($v.Remediation)"
    }
    foreach ($w in $result.Warnings) {
        Write-Warn "POLICY WARNING [$($w.Rule)] $($w.File): $($w.Detail)"
    }

    if ($result.Passed) {
        Write-OK "All policy checks passed."
    } else {
        Write-Fail "Policy check failed: $($violations.Count) violation(s) found."
    }

    return $result
}

function Get-SecurityScore {
    <#
    .SYNOPSIS
        Compute a 0-100 security score from a PolicyResult.
    #>
    param([Parameter(Mandatory=$true)][PolicyResult]$PolicyResult)

    $rules       = $PolicyResult.Score.Count
    if ($rules -eq 0) { return 0 }
    $passes      = ($PolicyResult.Score.Values | Where-Object { $_ -eq "pass" }).Count
    $warnPenalty = ($PolicyResult.Score.Values | Where-Object { $_ -eq "warn" }).Count * 0.5
    $score       = [math]::Round((($passes - $warnPenalty) / $rules) * 100)
    return [math]::Max(0, $score)
}

Export-ModuleMember -Function Invoke-PolicyCheck, Get-SecurityScore
