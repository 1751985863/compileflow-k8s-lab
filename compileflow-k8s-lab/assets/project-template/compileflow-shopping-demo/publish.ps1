param([string]$WorkbenchUrl = 'http://127.0.0.1:18080')
$ErrorActionPreference = 'Stop'
$code = 'demo.shopping.checkout'
$xml = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'checkout.bpm'))
function Post-Json($path, $data, $headers = @{}) {
    $json = $data | ConvertTo-Json -Depth 10
    Invoke-RestMethod "$WorkbenchUrl$path" -Method Post -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($json)) -Headers $headers -TimeoutSec 60
}
$preview = Post-Json '/api/executions/preview' @{code=$code;modelType='TBBPM';xml=$xml;params=@{subtotalCents=12000}}
if (-not $preview.success -or $preview.result.payableCents -ne 11000) {
    throw "Preview failed: $($preview.errorCode) ($($preview.traceId))"
}
try {
    $draft = Invoke-RestMethod "$WorkbenchUrl/api/processes/$code" -TimeoutSec 15
} catch {
    if ([int]$_.Exception.Response.StatusCode -ne 404) { throw }
    $draft = Post-Json '/api/processes' @{code=$code;name='购物结算';type='TBBPM';xml=$xml}
}
if ($draft.xml.Trim() -ne $xml.Trim()) { throw 'Workbench draft differs. Publish it in the UI to keep your changes.' }
$key = "shopping-tutorial-$($draft.revision)"
Post-Json "/api/processes/$code/publish" @{expectedRevision=$draft.revision;changelog='Shopping checkout tutorial'} @{'Idempotency-Key'=$key} |
    Select-Object processCode,version
