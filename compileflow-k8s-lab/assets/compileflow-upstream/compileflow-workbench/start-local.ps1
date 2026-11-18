$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$env:VITE_COMPILEFLOW_OPERATE_MODE = 'mock'
$nodeCommand = (Get-Command node.exe -ErrorAction Stop).Source
if (-not (Get-NetTCPConnection -LocalPort 3001 -State Listen -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $nodeCommand -ArgumentList 'node_modules/tsx/dist/cli.mjs src/server.ts' -WorkingDirectory "$PSScriptRoot/apps/dev-gateway" -WindowStyle Hidden -RedirectStandardOutput "$PSScriptRoot/gateway-direct.log" -RedirectStandardError "$PSScriptRoot/gateway-direct.err.log"
}
if (-not (Get-NetTCPConnection -LocalPort 5173 -State Listen -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $nodeCommand -ArgumentList 'node_modules/vite/bin/vite.js --host 127.0.0.1 --port 5173 --strictPort' -WorkingDirectory "$PSScriptRoot/apps/web" -WindowStyle Hidden -RedirectStandardOutput "$PSScriptRoot/web-direct.log" -RedirectStandardError "$PSScriptRoot/web-direct.err.log"
}
Write-Host 'CompileFlow Workbench: http://127.0.0.1:5173'
