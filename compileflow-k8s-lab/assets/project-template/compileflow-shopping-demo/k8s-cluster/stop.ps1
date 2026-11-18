$ErrorActionPreference = 'Stop'
kind delete cluster --name compileflow-k8s
if ($LASTEXITCODE -ne 0) { throw 'Could not delete the kind cluster.' }
Write-Host 'Deleted kind cluster compileflow-k8s. The Docker Compose environment was not changed.'
