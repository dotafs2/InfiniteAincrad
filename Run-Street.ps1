param([string]$Godot = $env:GODOT_EXE, [switch]$SkipBuild, [string]$SavePath, [switch]$Visitor, [switch]$Town)
$ErrorActionPreference = 'Stop'
if (-not $Godot) {
    $localEngine = Join-Path $PSScriptRoot 'tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe'
    if (Test-Path -LiteralPath $localEngine) { $Godot = $localEngine }
}
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
    & $Godot --headless --editor --import --path (Join-Path $PSScriptRoot 'game')
    if ($LASTEXITCODE -ne 0) { throw 'Godot asset import failed; the game was not launched.' }
}
$gameArgs = @('--path', (Join-Path $PSScriptRoot 'game'))
if ($Town) {
    if (-not $SavePath) { throw 'Town mode requires -SavePath pointing to a separate migrate_town.py output.' }
    if ($Visitor) { throw 'Town and the Luna/Mira fixture visitor are separate validation modes.' }
    $gameArgs += 'res://scenes/town_street.tscn'
}
if ($SavePath -or $Visitor) { $gameArgs += '--' }
if ($SavePath) {
    $saveFlag = if ($Town) { '--town-save=' } else { '--save-path=' }
    $gameArgs += ($saveFlag + [IO.Path]::GetFullPath($SavePath))
}
if ($Visitor) { $gameArgs += '--visitor-encounter' }
& $Godot @gameArgs
exit $LASTEXITCODE
