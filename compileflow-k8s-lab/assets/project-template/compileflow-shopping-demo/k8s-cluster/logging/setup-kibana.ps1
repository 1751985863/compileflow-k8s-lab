$ErrorActionPreference = 'Stop'
$Kibana = 'http://127.0.0.1:25601'

for ($attempt = 1; $attempt -le 60; $attempt++) {
    try {
        $status = Invoke-RestMethod -Uri "$Kibana/api/status"
        if ($status.status.overall.level -eq 'available') { break }
    } catch {
        if ($attempt -eq 60) { throw 'Kibana did not become ready.' }
    }
    Start-Sleep -Seconds 5
}

$body = @{
    data_view = @{
        title = 'compileflow-logs-*'
        name = 'CompileFlow Logs'
        timeFieldName = '@timestamp'
        allowNoIndex = $true
    }
} | ConvertTo-Json -Depth 5

try {
    Invoke-RestMethod -Method Post -Uri "$Kibana/api/data_views/data_view" `
        -Headers @{ 'kbn-xsrf' = 'true' } -ContentType 'application/json' -Body $body | Out-Null
} catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 409) { throw }
}

Write-Host 'Kibana data view is ready: CompileFlow Logs'
Write-Host "$Kibana/app/discover"
