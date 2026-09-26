
param(
    [string]$PrimaryHealthUrl = "https://api.paysecure.in/health/ready",
    [string]$DrHealthUrl = "https://dr-api.paysecure.in/health/ready"
)

$ErrorActionPreference = "Stop"

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Url
    )

    try {
        $response = Invoke-WebRequest `
            -Uri $Url `
            -Method GET `
            -TimeoutSec 10 `
            -UseBasicParsing

        if ($response.StatusCode -eq 200) {
            Write-Host "[PASS] $Name : HTTP $($response.StatusCode)"
            return $true
        }

        Write-Host "[FAIL] $Name : HTTP $($response.StatusCode)"
        return $false
    }
    catch {
        Write-Host "[FAIL] $Name : $($_.Exception.Message)"
        return $false
    }
}

$primaryHealthy = Test-Endpoint -Name "Primary Mumbai" -Url $PrimaryHealthUrl
$drHealthy      = Test-Endpoint -Name "DR Hyderabad" -Url $DrHealthUrl

Write-Host ""
Write-Host "========== PaySecure DR Health =========="

if ($primaryHealthy) {
    Write-Host "Primary region: HEALTHY"
}
else {
    Write-Host "Primary region: UNHEALTHY"
}

if ($drHealthy) {
    Write-Host "DR region: HEALTHY"
}
else {
    Write-Host "DR region: UNHEALTHY"
}

Write-Host "========================================="

if (-not $drHealthy) {
    Write-Error "DR region is not healthy. Failover must not proceed."
    exit 2
}

if (-not $primaryHealthy) {
    Write-Host "Primary is unhealthy and DR is healthy."
    Write-Host "DR is technically ready for failover assessment."
    exit 10
}

Write-Host "Both regions are healthy."
exit 0

