$ErrorActionPreference = 'Stop'
docker compose -f (Join-Path $PSScriptRoot 'compose.yaml') stop
if ($LASTEXITCODE -ne 0) { throw 'Could not stop Headlamp.' }
Write-Host 'Headlamp stopped. Kubernetes workloads are unchanged.'

