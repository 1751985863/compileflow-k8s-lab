$ErrorActionPreference = 'Stop'
$baseUrl = 'http://127.0.0.1:15601'
$headers = @{'kbn-xsrf' = 'logging-lab'}
$payload = @{
    data_view = @{
        id = 'compileflow-logs'
        name = 'CompileFlow Logs'
        title = 'compileflow-logs-*'
        timeFieldName = '@timestamp'
    }
    override = $true
} | ConvertTo-Json

Invoke-RestMethod "$baseUrl/api/data_views/data_view" -Method Post -Headers $headers -ContentType 'application/json' -Body $payload -TimeoutSec 15 |
    Select-Object -ExpandProperty data_view | Select-Object id, title, timeFieldName
Write-Host "$baseUrl/app/discover"
