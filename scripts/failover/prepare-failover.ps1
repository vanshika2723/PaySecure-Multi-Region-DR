param(
    [string]$DrCluster = "paysecure-dr",
    [string]$DrRegion = "ap-south-2",
    [switch]$DryRun = $true
)

$ErrorActionPreference = "Stop"

Write-Host "======================================="
Write-Host "PaySecure DR Failover Preparation"
Write-Host "======================================="

Write-Host "DR Cluster : $DrCluster"
Write-Host "DR Region  : $DrRegion"
Write-Host "Dry Run    : $DryRun"
Write-Host ""

Write-Host "[1/5] Checking AWS identity..."

aws sts get-caller-identity

Write-Host ""
Write-Host "[2/5] Checking DR EKS cluster..."

aws eks describe-cluster `
    --name $DrCluster `
    --region $DrRegion `
    --query "cluster.status" `
    --output text

Write-Host ""
Write-Host "[3/5] Checking Kubernetes nodes..."

kubectl get nodes

Write-Host ""
Write-Host "[4/5] Checking PaySecure namespace..."

kubectl get namespace paysecure

Write-Host ""
Write-Host "[5/5] Checking application pods..."

kubectl get pods `
    --namespace paysecure `
    --show-labels

Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN] No DNS or traffic-routing changes were made."
    Write-Host "[DRY RUN] Failover preparation checks completed."
    exit 0
}

Write-Warning "Live failover mode requested."
Write-Warning "DNS changes require an approved change window."
Write-Host "No automatic DNS modification is implemented in this script."
exit 0

