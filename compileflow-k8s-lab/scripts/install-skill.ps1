param([switch]$Force)

$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path $PSScriptRoot -Parent
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$skillsRoot = Join-Path $codexHome 'skills'
$destination = Join-Path $skillsRoot 'compileflow-k8s-lab'

if (Test-Path $destination) {
    if (-not $Force) {
        throw "Skill already exists at $destination. Inspect it first or explicitly use -Force."
    }
} else {
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
}

Get-ChildItem -LiteralPath $skillRoot -Force |
    Copy-Item -Destination $destination -Recurse -Force

Write-Host "Skill installed at: $destination"
Write-Host 'Restart Codex, then invoke $compileflow-k8s-lab.'

