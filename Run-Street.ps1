param([string]$Godot = $env:GODOT_EXE, [switch]$SkipBuild, [string]$SavePath, [switch]$Visitor)
$ErrorActionPreference = 'Stop'
if (-not $Godot) {
    $installed = Get-Command godot -ErrorAction SilentlyContinue
    if ($installed) { $Godot = $installed.Source }
}
if (-not $Godot) {
    $cachedEngine = Join-Path $env:USERPROFILE '.cache\level0-tools\godot-4.7.2-mono\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe'
    if (Test-Path -LiteralPath $cachedEngine) { $Godot = $cachedEngine }
}
if (-not $Godot) { throw 'Provide Godot 4.7.2 .NET with -Godot <path> or GODOT_EXE.' }
if (-not $SkipBuild) {
    & dotnet build (Join-Path $PSScriptRoot 'game/InfiniteAincrad.csproj') --disable-build-servers -v minimal
    if ($LASTEXITCODE -ne 0) { throw 'Godot .NET build failed; the game was not launched.' }
}
$gameArgs = @('--path', (Join-Path $PSScriptRoot 'game'))
if ($SavePath -or $Visitor) { $gameArgs += '--' }
if ($SavePath) { $gameArgs += ('--save-path=' + [IO.Path]::GetFullPath($SavePath)) }
if ($Visitor) { $gameArgs += '--visitor-encounter' }
& $Godot @gameArgs
exit $LASTEXITCODE
