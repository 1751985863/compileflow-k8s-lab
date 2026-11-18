$ErrorActionPreference = 'Stop'
docker compose -f (Join-Path $PSScriptRoot 'access\compose.yaml') stop
if ($LASTEXITCODE -ne 0) { throw 'Could not stop the monitoring access proxies.' }
Write-Host 'Local access stopped. Prometheus and Grafana Pods are still running in Kubernetes.'

