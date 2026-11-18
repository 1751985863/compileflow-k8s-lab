param(
    [ValidateRange(1, 1000)][int]$Rate = 500,
    [ValidatePattern('^\d+(s|m|h)$')][string]$Duration = '5s',
    [ValidateRange(1, 5000)][int]$PreAllocatedVUs = 1500,
    [ValidateRange(1, 10000)][int]$MaxVUs = 3000
)

$ErrorActionPreference = 'Stop'
$Namespace = 'compileflow-lab'
$Job = 'k6-shopping-load-test'
$TestId = 'shopping-' + [DateTimeOffset]::Now.ToUnixTimeMilliseconds()

if ($MaxVUs -lt $PreAllocatedVUs) {
    throw 'MaxVUs must be greater than or equal to PreAllocatedVUs.'
}

kubectl apply -f (Join-Path $PSScriptRoot 'k6-script.yaml')
if ($LASTEXITCODE -ne 0) { throw 'Could not create the k6 script ConfigMap.' }

kubectl create configmap k6-load-settings -n $Namespace `
    --from-literal="RATE=$Rate" `
    --from-literal="DURATION=$Duration" `
    --from-literal="PRE_ALLOCATED_VUS=$PreAllocatedVUs" `
    --from-literal="MAX_VUS=$MaxVUs" `
    --from-literal="TEST_ID=$TestId" `
    --from-literal='TARGET_URL=http://nginx-entry:8080/api/checkout' `
    --dry-run=client -o yaml | kubectl apply -f -
if ($LASTEXITCODE -ne 0) { throw 'Could not create the k6 load settings.' }

kubectl delete job $Job -n $Namespace --ignore-not-found --wait=true | Out-Null
kubectl apply -f (Join-Path $PSScriptRoot 'job.yaml')
if ($LASTEXITCODE -ne 0) { throw 'Could not create the k6 Job.' }

Write-Host "k6 started: rate=$Rate requests/s, duration=$Duration, maxVUs=$MaxVUs"
Write-Host 'Waiting for the test Pod...'
kubectl wait --for=condition=Ready pod -n $Namespace -l app=k6-shopping-load-test --timeout=180s | Out-Null
if ($LASTEXITCODE -ne 0) {
    kubectl describe job $Job -n $Namespace
    throw 'The k6 Pod did not become ready.'
}

kubectl logs -f "job/$Job" -n $Namespace
$jobSucceeded = ''
for ($attempt = 1; $attempt -le 30; $attempt++) {
    $jobSucceeded = kubectl get job $Job -n $Namespace -o jsonpath='{.status.succeeded}'
    $jobFailed = kubectl get job $Job -n $Namespace -o jsonpath='{.status.failed}'
    if ($jobSucceeded -eq '1' -or $jobFailed -ge '1') { break }
    Start-Sleep -Seconds 1
}
if ($jobSucceeded -ne '1') {
    throw 'The load test failed. Review the threshold results above.'
}

Write-Host 'Load test passed. You can also inspect this Job and Pod in Headlamp.'

