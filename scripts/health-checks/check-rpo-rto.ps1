param(
    [int]$ObservedRpoSeconds = 0,
    [int]$ObservedRtoSeconds = 0
)

$ErrorActionPreference = "Stop"

$TargetRpoSeconds = 60
$TargetRtoSeconds = 300

Write-Host "======================================="
Write-Host "PaySecure DR RPO/RTO Validation"
Write-Host "======================================="

Write-Host "Target RPO : < $TargetRpoSeconds seconds"
Write-Host "Observed RPO: $ObservedRpoSeconds seconds"
Write-Host ""

Write-Host "Target RTO : < $TargetRtoSeconds seconds"
Write-Host "Observed RTO: $ObservedRtoSeconds seconds"
Write-Host ""

$rpoPass = $ObservedRpoSeconds -lt $TargetRpoSeconds
$rtoPass = $ObservedRtoSeconds -lt $TargetRtoSeconds

if ($rpoPass) {
    Write-Host "[PASS] RPO target achieved."
}
else {
    Write-Host "[FAIL] RPO target exceeded."
}

if ($rtoPass) {
    Write-Host "[PASS] RTO target achieved."
}
else {
    Write-Host "[FAIL] RTO target exceeded."
}

if ($rpoPass -and $rtoPass) {
    Write-Host ""
    Write-Host "DR SUCCESS CRITERIA: PASSED"
    exit 0
}

Write-Host ""
Write-Host "DR SUCCESS CRITERIA: FAILED"
exit 1

