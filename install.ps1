param(
    [string]$WorkshopRoot = (Join-Path $env:USERPROFILE 'Zomboid\Workshop')
)

$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Contents\mods\SurvivorPDAOrchestrator'))
$packageRoot = [IO.Path]::GetFullPath((Join-Path $WorkshopRoot 'Survivor PDA Orchestrator'))
$targetRoot = Join-Path $packageRoot 'Contents\mods\SurvivorPDAOrchestrator'
$targetInfo = Join-Path $targetRoot 'mod.info'
if ((Test-Path -LiteralPath $targetInfo) -and -not ((Get-Content -LiteralPath $targetInfo) -contains 'id=SurvivorPDAOrchestrator')) {
    throw "A different mod already occupies $targetRoot"
}

$count = 0
foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File) {
    $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\')
    $destination = Join-Path $targetRoot $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash) {
        throw "Installed file hash mismatch: $relative"
    }
    $count++
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'workshop.txt') -Destination (Join-Path $packageRoot 'workshop.txt') -Force
if (-not (Test-Path -LiteralPath (Join-Path $targetRoot '42\mod.info'))) { throw 'Missing Build 42 metadata' }
Write-Output "Installed $count verified files in $targetRoot"
Write-Output 'Enable Survivor PDA Orchestrator in the game mod list, then open its section in PDA Admin.'
