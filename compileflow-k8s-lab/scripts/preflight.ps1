param([switch]$Json)

$ErrorActionPreference = 'Stop'
$requiredCommands = @('docker', 'git', 'java', 'mvn', 'kubectl', 'kind', 'pwsh')
$checks = foreach ($name in $requiredCommands) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Name = $name
        Found = $null -ne $command
        Path = if ($command) { $command.Source } else { $null }
    }
}

$dockerReady = $false
if (($checks | Where-Object Name -eq 'docker').Found) {
    docker info *> $null
    $dockerReady = $LASTEXITCODE -eq 0
}

$java17 = $false
if (($checks | Where-Object Name -eq 'java').Found) {
    $javaText = (& java -version 2>&1) -join "`n"
    $java17 = $javaText -match 'version "17[\.]'
}

$systemDrive = Get-PSDrive -Name ([IO.Path]::GetPathRoot($env:SystemDrive).TrimEnd(':'))
$memoryBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
$result = [pscustomobject]@{
    Commands = $checks
    DockerReady = $dockerReady
    Java17 = $java17
    MemoryGB = [math]::Round($memoryBytes / 1GB, 1)
    FreeSystemDiskGB = [math]::Round($systemDrive.Free / 1GB, 1)
    RecommendedMemoryMet = $memoryBytes -ge 16GB
    RecommendedDiskMet = $systemDrive.Free -ge 35GB
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    $checks | Format-Table Name,Found,Path -AutoSize
    $result | Select-Object DockerReady,Java17,MemoryGB,FreeSystemDiskGB,
        RecommendedMemoryMet,RecommendedDiskMet | Format-List
}

$missing = @($checks | Where-Object { -not $_.Found } | ForEach-Object Name)
if ($missing.Count -gt 0) { throw "Missing required commands: $($missing -join ', ')" }
if (-not $dockerReady) { throw 'Docker Desktop engine is not running.' }
if (-not $java17) { throw 'Java 17 must be the active java command.' }

