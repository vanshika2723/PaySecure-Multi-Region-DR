param(
    [string]$Namespace = "paysecure"
)

$ErrorActionPreference = "Stop"

$failedChecks = 0

function Check-Command {
    param(
        [string]$Description,
        [scriptblock]$Command
    )

    Write-Host ""
    Write-Host "Checking: $Description"

    try {
        & $Command

        if ($LASTEXITCODE -ne 0) {
            throw "Command returned exit code $LASTEXITCODE"
        }

        Write-Host "[PASS] $Description"
    }
    catch {
        Write-Host "[FAIL] $Description"
        $script:failedChecks++
    }
}

Check-Command "Kubernetes API access" {
    kubectl cluster-info
}

Check-Command "DR nodes" {
    kubectl get nodes
}

Check-Command "PaySecure namespace" {
    kubectl get namespace $Namespace
}

Check-Command "PaySecure pods" {
    kubectl get pods -n $Namespace
}

Check-Command "PaySecure service" {
    kubectl get service -n $Namespace
}

Write-Host ""
Write-Host "======================================="
Write-Host "DR Readiness Result"
Write-Host "======================================="

if ($failedChecks -eq 0) {
    Write-Host "RESULT: READY"
    exit 0
}

Write-Host "RESULT: NOT READY"
Write-Host "Failed checks: $failedChecks"
exit 1
