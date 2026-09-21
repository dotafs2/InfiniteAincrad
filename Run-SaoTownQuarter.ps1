param([string]$Godot = $env:GODOT_EXE)
$ErrorActionPreference = 'Stop'

if (-not $Godot) {
	$cachedEngine = Join-Path $env:USERPROFILE '.cache\level0-tools\godot-4.7.2-mono/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe'
	if (Test-Path -LiteralPath $cachedEngine) { $Godot = $cachedEngine }
}
if (-not $Godot) {
	$installed = Get-Command godot -ErrorAction SilentlyContinue
	if ($installed) { $Godot = $installed.Source }
}
if (-not $Godot) { throw 'Provide Godot 4.7.2 with -Godot <path> or GODOT_EXE.' }

& $Godot --path (Join-Path $PSScriptRoot 'game') 'res://scenes/sao_town_quarter.tscn'
exit $LASTEXITCODE
