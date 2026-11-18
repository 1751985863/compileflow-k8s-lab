$ErrorActionPreference = 'Stop'

$OldDeploy = Resolve-Path (Join-Path $PSScriptRoot '..\..\compileflow-credit-service\workbench-docker')
$OldCompose = Join-Path $OldDeploy 'compose.yaml'
$EnvFile = Join-Path $OldDeploy '.env'

if (-not (Test-Path -LiteralPath $EnvFile)) {
    throw "Missing $EnvFile. Keep the original Workbench .env so the existing PostgreSQL volume can be reused."
}

# 旧的单节点和新集群共用同一个数据库卷与 18080 端口，先停旧容器，但不删数据卷。
docker compose --env-file $EnvFile -f $OldCompose stop server postgres
if ($LASTEXITCODE -ne 0) { throw 'Could not stop the old single-node Workbench deployment.' }

docker compose --env-file $EnvFile -f (Join-Path $PSScriptRoot 'compose.yaml') up -d --build --wait
if ($LASTEXITCODE -ne 0) { throw 'Cluster startup failed.' }

Write-Host 'Eureka:   http://127.0.0.1:18761'
Write-Host 'Gateway:  http://127.0.0.1:18080'
Write-Host 'Kibana:   http://127.0.0.1:15601'
Write-Host 'SkyWalking: http://127.0.0.1:18090'
