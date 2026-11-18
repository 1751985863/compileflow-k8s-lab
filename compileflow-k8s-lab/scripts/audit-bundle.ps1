$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path $PSScriptRoot -Parent
$template = Join-Path $skillRoot 'assets\project-template'

$required = @(
    'pom.xml',
    'compileflow-shopping-demo\k8s-cluster\deploy.ps1',
    'compileflow-shopping-demo\k8s-cluster\verify.ps1',
    'compileflow-shopping-demo\k8s-cluster\business.yaml',
    'compileflow-shopping-demo\k8s-cluster\rocketmq.yaml',
    'compileflow-shopping-demo\k8s-cluster\pxc.yaml',
    'compileflow-shopping-demo\k8s-cluster\logging\logging.yaml',
    'compileflow-shopping-demo\k8s-cluster\monitoring\prometheus.yaml',
    'compileflow-shopping-demo\k8s-cluster\monitoring\grafana.yaml',
    'compileflow-payment-service\src\main\java\lab\payment\MybatisPlusPaymentStore.java'
)

$missing = @($required | Where-Object { -not (Test-Path (Join-Path $template $_)) })
if ($missing.Count -gt 0) { throw "Bundle is missing: $($missing -join ', ')" }

$compileFlowSnapshot = Join-Path $skillRoot 'assets\compileflow-upstream'
if (-not (Test-Path (Join-Path $compileFlowSnapshot 'compileflow-workbench-server\pom.xml')) -or
    -not (Test-Path (Join-Path $compileFlowSnapshot 'CODEX_SNAPSHOT_COMMIT.txt'))) {
    throw 'Bundled CompileFlow source snapshot is incomplete.'
}

$forbiddenFiles = Get-ChildItem -LiteralPath $skillRoot -Recurse -File |
    Where-Object { $_.Name -in @('.env', 'kubeconfig') -or $_.FullName -match '\\target\\' }
if ($forbiddenFiles) {
    throw "Bundle contains runtime or secret files: $($forbiddenFiles.FullName -join ', ')"
}

$hardcoded = rg -n 'D:\\校招|C:\\Users\\test|BEGIN (RSA|OPENSSH) PRIVATE KEY' $skillRoot
if ($LASTEXITCODE -eq 0) { throw "Bundle contains machine-specific or sensitive text:`n$hardcoded" }
if ($LASTEXITCODE -gt 1) { throw 'Bundle scan failed.' }

Write-Host 'Portable bundle audit passed.'

