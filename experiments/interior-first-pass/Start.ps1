param([string]$Godot = "C:\Users\quchenxi\.cache\level0-tools\godot-4.7.2-mono\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe")
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Godot)) {
    $availableGodot = Get-Command godot -ErrorAction SilentlyContinue
    if ($availableGodot) { $Godot = $availableGodot.Source }
    else { $Godot = Read-Host 'Enter the path to your Godot 4.7 executable' }
}
if (-not (Test-Path -LiteralPath $Godot)) { throw 'Godot executable not found.' }
# User-invoked foreground preview. No model API, secrets, server or timed job.
& $Godot --headless --editor --path $PSScriptRoot --import
if ($LASTEXITCODE -ne 0) { throw 'Godot asset import failed.' }
& $Godot --path $PSScriptRoot
