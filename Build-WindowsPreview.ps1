param(
    [string]$Godot = $env:GODOT_EXE,
    [string]$Python = 'python',
    [string]$Output
)
$ErrorActionPreference = 'Stop'
if (!$Godot) {
    $localEngine = Join-Path $PSScriptRoot 'tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
    if (Test-Path -LiteralPath $localEngine) { $Godot = $localEngine }
    else {
        $installed = Get-Command godot -ErrorAction SilentlyContinue
        if ($installed) { $Godot = $installed.Source }
    }
}
if (!$Godot) { throw 'Provide Godot 4.7.2 .NET with matching .NET export templates using -Godot or GODOT_EXE.' }
$buildArgs = @((Join-Path $PSScriptRoot 'tools/build_windows_preview.py'), '--godot', $Godot)
if ($Output) { $buildArgs += @('--output', $Output) }
& $Python @buildArgs
if ($LASTEXITCODE -ne 0) { throw 'Preview build failed. See the printed evidence directory; no package was marked validated.' }
