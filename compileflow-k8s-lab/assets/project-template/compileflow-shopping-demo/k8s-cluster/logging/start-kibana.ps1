$ErrorActionPreference = 'Stop'
$Namespace = 'compileflow-lab'
$PidFile = Join-Path $PSScriptRoot '.kibana-port-forward.pid'

if (Test-Path $PidFile) {
    $oldPid = [int](Get-Content $PidFile)
    if (Get-Process -Id $oldPid -ErrorAction SilentlyContinue) {
        Write-Host 'Kibana port-forward is already running.'
        Write-Host 'Kibana: http://127.0.0.1:25601/app/discover'
        exit 0
    }
}

$process = Start-Process kubectl -ArgumentList @(
    'port-forward',
    '-n', $Namespace,
    'service/kibana',
    '25601:5601',
    '--address=127.0.0.1'
) -WindowStyle Hidden -PassThru

$process.Id | Set-Content $PidFile
Start-Sleep -Seconds 2
if ($process.HasExited) { throw 'Kibana port-forward failed to start.' }

Write-Host 'Kibana: http://127.0.0.1:25601/app/discover'
