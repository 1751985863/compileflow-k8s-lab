$ErrorActionPreference = 'Stop'

if ((kubectl config current-context) -ne 'kind-compileflow-k8s') {
    throw 'kubectl must use context kind-compileflow-k8s.'
}

kubectl apply -k $PSScriptRoot
if ($LASTEXITCODE -ne 0) { throw 'Could not apply the monitoring manifests.' }

kubectl rollout status statefulset/prometheus -n monitoring --timeout=600s
if ($LASTEXITCODE -ne 0) { throw 'Prometheus did not become ready.' }
kubectl rollout status deployment/kube-state-metrics -n monitoring --timeout=300s
if ($LASTEXITCODE -ne 0) { throw 'kube-state-metrics did not become ready.' }
kubectl rollout status deployment/grafana -n monitoring --timeout=600s
if ($LASTEXITCODE -ne 0) { throw 'Grafana did not become ready.' }

docker compose -f (Join-Path $PSScriptRoot 'access\compose.yaml') up -d
if ($LASTEXITCODE -ne 0) { throw 'Could not start the local monitoring access proxies.' }

$targetsReady = $false
for ($attempt = 1; $attempt -le 30; $attempt++) {
    try {
        $health = Invoke-RestMethod 'http://127.0.0.1:23000/api/health' -TimeoutSec 2
        $prometheusReady = (Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:29090/-/ready' -TimeoutSec 2).StatusCode -eq 200
        if ($health.database -eq 'ok' -and $prometheusReady) {
            $targetsReady = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 2
    }
}
if (-not $targetsReady) { throw 'Grafana or Prometheus did not become reachable.' }

Write-Host 'Grafana:    http://127.0.0.1:23000  (admin / admin)'
Write-Host 'Prometheus: http://127.0.0.1:29090'

