$ErrorActionPreference = 'Stop'

$LabRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$CompileFlowRoot = Join-Path $LabRoot 'vendor\compileflow'
$Runtime = Join-Path $PSScriptRoot 'runtime'

if (-not (Test-Path (Join-Path $CompileFlowRoot 'mvnw.cmd'))) {
    throw "CompileFlow source is missing at $CompileFlowRoot. Run the skill restore script first."
}

Push-Location $LabRoot
try {
    mvn -B -ntp -pl compileflow-eureka-server,compileflow-cluster-gateway,compileflow-shopping-demo,compileflow-payment-service -am package -DskipTests
    if ($LASTEXITCODE -ne 0) { throw 'Spring Cloud cluster modules build failed.' }
}
finally {
    Pop-Location
}

Push-Location $CompileFlowRoot
try {
    .\mvnw.cmd -B -ntp -pl compileflow-workbench-server -am package -DskipTests
    if ($LASTEXITCODE -ne 0) { throw 'CompileFlow Workbench Server build failed.' }
}
finally {
    Pop-Location
}

New-Item -ItemType Directory -Force -Path $Runtime | Out-Null
Copy-Item -LiteralPath (Join-Path $CompileFlowRoot 'compileflow-workbench-server\target\compileflow-workbench-server-2.0.0-SNAPSHOT.jar') `
    -Destination (Join-Path $Runtime 'workbench-server.jar') -Force

Write-Host 'Cluster jars are ready. Run .\start.ps1 next.'
