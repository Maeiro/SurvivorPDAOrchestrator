param(
    [Parameter(Mandatory = $true)]
    [string]$ZombieBuddyJar,
    [Parameter(Mandatory = $true)]
    [string]$GameDirectory,
    [string]$CompilerJar
)

$ErrorActionPreference = 'Stop'
$dependency = (Resolve-Path -LiteralPath $ZombieBuddyJar).Path
$gameRoot = (Resolve-Path -LiteralPath $GameDirectory).Path
$gameJar = Join-Path $gameRoot 'projectzomboid.jar'
if (-not (Test-Path -LiteralPath $gameJar)) { throw 'GameDirectory must contain projectzomboid.jar.' }
$classpath = "$dependency;$gameJar;$gameRoot"
$classes = Join-Path $PSScriptRoot ('build\classes-' + [Guid]::NewGuid().ToString('N'))
$modRoot = Join-Path $PSScriptRoot 'Contents\mods\SurvivorPDAOrchestrator'
$output = Join-Path $modRoot '42\media\java\client\SurvivorPDAOrchestrator.jar'
New-Item -ItemType Directory -Force -Path $classes, (Split-Path -Parent $output) | Out-Null
$sources = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'src') -Recurse -Filter '*.java' -File
if ($CompilerJar) {
    & (Join-Path $gameRoot 'jre64\bin\java.exe') -jar $CompilerJar -17 -warn:none -proc:none -cp $classpath -d $classes $sources.FullName
} else {
    & javac --release 17 -proc:none -cp $classpath -d $classes $sources.FullName
}
if ($LASTEXITCODE -ne 0) { throw 'Java compilation failed.' }
& jar --create --file $output -C $classes maeiro
if ($LASTEXITCODE -ne 0) { throw 'JAR packaging failed.' }
Write-Output $output
