param(
    [string]$Destination = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'compileflow-k8s-lab'),
    [switch]$Force,
    [switch]$Deploy
)

$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path $PSScriptRoot -Parent
$template = Join-Path $skillRoot 'assets\project-template'
$compileFlowSnapshot = Join-Path $skillRoot 'assets\compileflow-upstream'
$compileFlowCommit = 'c2831832745e893f0dbe22b1e94810625372a356'

& (Join-Path $PSScriptRoot 'preflight.ps1')

if (Test-Path $Destination) {
    $hasFiles = $null -ne (Get-ChildItem -LiteralPath $Destination -Force | Select-Object -First 1)
    if ($hasFiles -and -not $Force) {
        throw "Destination is not empty: $Destination. Choose another folder or explicitly use -Force."
    }
} else {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

Get-ChildItem -LiteralPath $template -Force | Copy-Item -Destination $Destination -Recurse -Force

$vendor = Join-Path $Destination 'vendor'
$compileFlowRoot = Join-Path $vendor 'compileflow'
if (-not (Test-Path (Join-Path $compileFlowSnapshot 'mvnw.cmd'))) {
    throw 'The bundled CompileFlow source snapshot is incomplete.'
}
New-Item -ItemType Directory -Path $compileFlowRoot -Force | Out-Null
Get-ChildItem -LiteralPath $compileFlowSnapshot -Force |
    Copy-Item -Destination $compileFlowRoot -Recurse -Force

$passwordBytes = New-Object byte[] 24
[Security.Cryptography.RandomNumberGenerator]::Fill($passwordBytes)
$password = [Convert]::ToBase64String($passwordBytes).TrimEnd('=').Replace('+','A').Replace('/','B')
[IO.File]::WriteAllText(
    (Join-Path $Destination '.lab.env'),
    "WORKBENCH_DB_PASSWORD=$password`r`n",
    [Text.UTF8Encoding]::new($false)
)

Write-Host "Portable project restored to: $Destination"
Write-Host "Bundled CompileFlow source restored from commit: $compileFlowCommit"

if ($Deploy) {
    & (Join-Path $Destination 'compileflow-shopping-demo\k8s-cluster\deploy.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Cluster deployment failed.' }
}

