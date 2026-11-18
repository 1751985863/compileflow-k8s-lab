$OldDeploy = Resolve-Path (Join-Path $PSScriptRoot '..\..\compileflow-credit-service\workbench-docker')
$EnvFile = Join-Path $OldDeploy '.env'
docker compose --env-file $EnvFile -f (Join-Path $PSScriptRoot 'compose.yaml') stop
