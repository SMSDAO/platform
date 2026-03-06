#Requires -Version 7.0
<#
.SYNOPSIS
    SMSDAO Platform — Provider Engine
.DESCRIPTION
    Single abstraction for all deploy targets. Phase modules call
    Invoke-Provider -Name $provider and never contain cloud-specific
    CLI commands directly. Adding a new provider = one new function here.
    Supports: k8s | azure | aws | vercel | generic
#>

using module ../utils/logger.psm1
using module ../utils/json-tools.psm1

function Invoke-Provider {
    <#
    .SYNOPSIS
        Dispatch to the correct cloud provider deploy function.
    .PARAMETER Name
        Provider name: k8s | azure | aws | vercel | generic
    .PARAMETER Env
        Target environment string.
    .PARAMETER CustomArgs
        Hashtable of provider-specific arguments (never contains raw secrets).
    .PARAMETER IsDryRun
        When true, print commands but do not execute them.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("k8s","azure","aws","vercel","generic")]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string]$Env,

        [hashtable]$CustomArgs = @{},
        [bool]$IsDryRun        = $false
    )

    Write-Step "Deploy via provider: $Name -> $Env"

    $result = switch ($Name) {
        "k8s"     { Invoke-K8sDeploy  -Env $Env -CustomArgs $CustomArgs -IsDryRun $IsDryRun }
        "azure"   { Invoke-AzureDeploy -Env $Env -CustomArgs $CustomArgs -IsDryRun $IsDryRun }
        "aws"     { Invoke-AwsDeploy   -Env $Env -CustomArgs $CustomArgs -IsDryRun $IsDryRun }
        "vercel"  { Invoke-VercelDeploy -Env $Env -CustomArgs $CustomArgs -IsDryRun $IsDryRun }
        "generic" { Invoke-GenericDeploy -Env $Env -CustomArgs $CustomArgs -IsDryRun $IsDryRun }
        default   { throw "Unknown provider '$Name'. Supported: k8s, azure, aws, vercel, generic." }
    }

    return $result
}

# ── Kubernetes ───────────────────────────────────────────────────
function Invoke-K8sDeploy {
    param([string]$Env, [hashtable]$CustomArgs, [bool]$IsDryRun)

    $namespace  = Get-ConfigValue "namespace"  -Default $Env.ToLower() -CustomArgs $CustomArgs
    $manifest   = Get-ConfigValue "manifest"   -Default "./k8s/$Env"   -CustomArgs $CustomArgs
    $deployment = Get-ConfigValue "deployment" -Default "app"          -CustomArgs $CustomArgs
    $timeout    = Get-ConfigValue "timeout"    -Default "300s"         -CustomArgs $CustomArgs

    Write-Info "K8s | namespace=$namespace | manifest=$manifest | deployment=$deployment"

    if (-not $IsDryRun) {
        # Validate manifest exists before sending to cluster
        if (-not (Test-Path $manifest)) { throw "Manifest path not found: $manifest" }

        & kubectl apply -f $manifest --namespace $namespace
        if ($LASTEXITCODE -ne 0) { throw "kubectl apply failed (exit $LASTEXITCODE)." }

        & kubectl rollout status deployment/$deployment --namespace $namespace --timeout=$timeout
        if ($LASTEXITCODE -ne 0) { throw "Rollout did not complete within $timeout." }

        # Surface running pod count
        $pods = & kubectl get pods --namespace $namespace --selector=app=$deployment `
                                   --field-selector=status.phase=Running `
                                   -o jsonpath='{.items[*].metadata.name}' 2>$null
        Write-Info "Running pods: $($pods.Split(' ').Count)"
    } else {
        Write-Dry "Would run: kubectl apply -f $manifest --namespace $namespace"
        Write-Dry "Would run: kubectl rollout status deployment/$deployment --namespace $namespace"
    }

    Write-OK "K8s deploy complete: $namespace/$deployment"
    return @{ provider = "k8s"; namespace = $namespace; deployment = $deployment }
}

# ── Azure Web App ────────────────────────────────────────────────
function Invoke-AzureDeploy {
    param([string]$Env, [hashtable]$CustomArgs, [bool]$IsDryRun)

    $rg      = Get-ConfigValue "resourceGroup" -Default "rg-$Env"   -CustomArgs $CustomArgs
    $appName = Get-ConfigValue "appName"       -Default "app-$Env"  -CustomArgs $CustomArgs
    $srcPath = Get-ConfigValue "srcPath"       -Default "./publish"  -CustomArgs $CustomArgs
    $slot    = Get-ConfigValue "slot"          -Default ""           -CustomArgs $CustomArgs

    Write-Info "Azure | rg=$rg | app=$appName | slot=$(if($slot){"$slot"} else {"production"})"

    if (-not $IsDryRun) {
        $deployArgs = @("webapp","deploy","--resource-group",$rg,"--name",$appName,"--src-path",$srcPath)
        if ($slot) { $deployArgs += "--slot", $slot }

        & az @deployArgs
        if ($LASTEXITCODE -ne 0) { throw "az webapp deploy failed." }

        # Swap slot to production if staging slot used
        if ($slot -and $Env -eq "Prod") {
            & az webapp deployment slot swap --resource-group $rg --name $appName `
                                             --slot $slot --target-slot production
            if ($LASTEXITCODE -ne 0) { throw "Slot swap failed." }
            Write-OK "Slot '$slot' swapped to production."
        }
    } else {
        Write-Dry "Would run: az webapp deploy --resource-group $rg --name $appName --src-path $srcPath"
        if ($slot) { Write-Dry "Would swap slot '$slot' to production" }
    }

    Write-OK "Azure deploy complete: $rg/$appName"
    return @{ provider = "azure"; resourceGroup = $rg; appName = $appName }
}

# ── AWS ECS ──────────────────────────────────────────────────────
function Invoke-AwsDeploy {
    param([string]$Env, [hashtable]$CustomArgs, [bool]$IsDryRun)

    $cluster   = Get-ConfigValue "ecsCluster" -Default "$Env-Cluster-01" -CustomArgs $CustomArgs
    $service   = Get-ConfigValue "ecsService" -Default "$Env-service"    -CustomArgs $CustomArgs
    $waitMax   = Get-ConfigValue "waitMax"    -Default 300               -CustomArgs $CustomArgs

    Write-Info "AWS ECS | cluster=$cluster | service=$service"

    if (-not $IsDryRun) {
        & aws ecs update-service --cluster $cluster --service $service --force-new-deployment
        if ($LASTEXITCODE -ne 0) { throw "aws ecs update-service failed." }

        # Wait for service stability
        Write-Info "Waiting for ECS service stability (max ${waitMax}s)..."
        & aws ecs wait services-stable --cluster $cluster --services $service
        if ($LASTEXITCODE -ne 0) { throw "ECS service did not stabilize within timeout." }

        $svc = & aws ecs describe-services --cluster $cluster --services $service `
               --query 'services[0].{running:runningCount,desired:desiredCount}' `
               --output json | ConvertFrom-Json
        Write-Info "ECS status: running=$($svc.running) desired=$($svc.desired)"
    } else {
        Write-Dry "Would run: aws ecs update-service --cluster $cluster --service $service --force-new-deployment"
        Write-Dry "Would wait for ECS services-stable"
    }

    Write-OK "AWS ECS deploy complete: $cluster/$service"
    return @{ provider = "aws"; cluster = $cluster; service = $service }
}

# ── Vercel ───────────────────────────────────────────────────────
function Invoke-VercelDeploy {
    param([string]$Env, [hashtable]$CustomArgs, [bool]$IsDryRun)

    # Token must arrive via CustomArgs from GitHub Secrets — never from config
    $token   = Get-ConfigValue "vercelToken" -CustomArgs $CustomArgs
    $orgId   = Get-ConfigValue "vercelOrgId" -CustomArgs $CustomArgs
    $projId  = Get-ConfigValue "vercelProjectId" -CustomArgs $CustomArgs

    if (-not $token)  { throw "vercelToken not found in CustomArgs. Inject from GitHub Secrets." }

    $isProd  = $Env -eq "Prod"
    $prodFlag = if ($isProd) { "--prod" } else { "" }

    Write-Info "Vercel | env=$Env | production=$isProd"

    if (-not $IsDryRun) {
        $vercelArgs = @("vercel","deploy","--token",$token,"--yes")
        if ($isProd)  { $vercelArgs += "--prod" }
        if ($orgId)   { $vercelArgs += "--scope", $orgId }

        $output = & npx @vercelArgs 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Vercel deploy failed: $output" }

        # Extract deployment URL from output
        $url = ($output | Select-String -Pattern 'https://[^\s]+\.vercel\.app').Matches.Value | Select-Object -Last 1
        Write-Info "Deployed URL: $url"
    } else {
        Write-Dry "Would run: npx vercel deploy $prodFlag --token *** --yes"
    }

    Write-OK "Vercel deploy complete (env=$Env)"
    return @{ provider = "vercel"; production = $isProd }
}

# ── Generic script-based deploy ──────────────────────────────────
function Invoke-GenericDeploy {
    param([string]$Env, [hashtable]$CustomArgs, [bool]$IsDryRun)

    $deployScript = Get-ConfigValue "deployScript" -Default "./deploy.sh" -CustomArgs $CustomArgs
    Write-Info "Generic deploy | script=$deployScript | env=$Env"

    if (-not (Test-Path $deployScript)) {
        throw "Deploy script not found: $deployScript. Set 'deployScript' in config.$Env.json."
    }

    if (-not $IsDryRun) {
        $env:DEPLOY_ENV = $Env
        & bash $deployScript
        if ($LASTEXITCODE -ne 0) { throw "Deploy script '$deployScript' failed." }
    } else {
        Write-Dry "Would run: bash $deployScript (DEPLOY_ENV=$Env)"
    }

    Write-OK "Generic deploy complete"
    return @{ provider = "generic"; script = $deployScript }
}

Export-ModuleMember -Function Invoke-Provider, Invoke-K8sDeploy, Invoke-AzureDeploy, Invoke-AwsDeploy, Invoke-VercelDeploy, Invoke-GenericDeploy
