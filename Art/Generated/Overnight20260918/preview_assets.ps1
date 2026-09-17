$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$previewRoot = Join-Path $PSScriptRoot 'preview-project'
$assetTarget = Join-Path $previewRoot 'assets/overnight20260918'
$captureRoot = Join-Path $PSScriptRoot 'captures'
$godotExe = 'D:/lucidgloves/InfiniteAincrad/tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe'
New-Item -ItemType Directory -Force $assetTarget, $captureRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot 'game/assets/overnight20260918/baking_oven.glb'),(Join-Path $repoRoot 'game/assets/overnight20260918/bread_loaf.glb'),(Join-Path $repoRoot 'game/assets/overnight20260918/flour_sack.glb'),(Join-Path $repoRoot 'game/assets/overnight20260918/baking_oven.tscn'),(Join-Path $repoRoot 'game/assets/overnight20260918/bread_loaf.tscn'),(Join-Path $repoRoot 'game/assets/overnight20260918/flour_sack.tscn'),(Join-Path $repoRoot 'game/assets/overnight20260918/preview.gd') -Destination $assetTarget -Force
@'
config_version=5
[application]
config/name="Overnight Baking Asset Review"
[display]
window/size/viewport_width=1280
window/size/viewport_height=900
[rendering]
renderer/rendering_method="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
anti_aliasing/quality/msaa_3d=2
'@ | Set-Content (Join-Path $previewRoot 'project.godot') -Encoding utf8
$env:DOTNET_ROLL_FORWARD = 'LatestMajor'
$env:DOTNET_ROOT = 'C:/Program Files/dotnet'
$env:PATH = 'C:/Program Files/dotnet;' + $env:PATH
$importLog = Join-Path $PSScriptRoot 'godot-import.log'
& ($godotExe -replace '\.exe$','_console.exe') --headless --path $previewRoot --editor --import --quit *> $importLog
if ($LASTEXITCODE -ne 0) { throw "Godot import failed; inspect $importLog" }
$arguments = @('--path', ('"' + $previewRoot + '"'), '--rendering-method', 'gl_compatibility', '--script', 'res://assets/overnight20260918/preview.gd', '--', ('"--output=' + $captureRoot + '"'))
$renderProcess = Start-Process -FilePath $godotExe -ArgumentList $arguments -WorkingDirectory $repoRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PSScriptRoot 'godot-preview.log') -RedirectStandardError (Join-Path $PSScriptRoot 'godot-preview-error.log')
@{pid=$renderProcess.Id;purpose='owned asset preview';started=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content (Join-Path $PSScriptRoot 'owned-process.json')
if (-not $renderProcess.WaitForExit(45000)) { throw "Owned preview PID $($renderProcess.Id) exceeded 45s; inspect logs before stopping it." }
if ($renderProcess.ExitCode -ne 0) { throw 'Godot preview failed; inspect godot-preview-error.log' }
Get-Content (Join-Path $captureRoot 'godot-import-report.json')
