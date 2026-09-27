param(
    [int]$Seconds = 60,
    [string]$OutputDirectory = "tmp/mobile-preview",
    [string]$Godot = "C:\Users\quchenxi\.cache\level0-tools\godot-4.7.2-mono\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe",
    [string]$Ffmpeg = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." )).Path
$repoRoot = (Resolve-Path (Join-Path $projectRoot "..\.." )).Path
$outputRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDirectory))
$null = New-Item -ItemType Directory -Force -Path $outputRoot

if (-not (Test-Path -LiteralPath $Godot)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -eq $godotCommand) { throw "Godot executable was not found. Pass -Godot with the local executable path." }
    $Godot = $godotCommand.Source
}

if ([string]::IsNullOrWhiteSpace($Ffmpeg)) {
    $ffmpegCommand = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($null -ne $ffmpegCommand) {
        $Ffmpeg = $ffmpegCommand.Source
    } else {
        $Ffmpeg = python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())"
    }
}
if (-not (Test-Path -LiteralPath $Ffmpeg)) { throw "ffmpeg executable was not found. Pass -Ffmpeg with the local executable path." }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$avi = Join-Path $outputRoot "hole-city-$stamp.avi"
$mp4 = Join-Path $outputRoot "hole-city-$stamp.mp4"
$frames = [Math]::Max(30, $Seconds * 30)

Push-Location $projectRoot
try {
    & $Godot --path $projectRoot --rendering-method gl_compatibility --fixed-fps 30 --write-movie $avi --quit-after $frames -- --demo
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $avi)) { throw "Godot movie recording failed." }
} finally {
    Pop-Location
}

& $Ffmpeg -y -i $avi -c:v libx264 -preset veryfast -crf 24 -pix_fmt yuv420p -movflags +faststart -an $mp4
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $mp4)) { throw "MP4 conversion failed." }
& $Ffmpeg -v error -i $mp4 -f null -
if ($LASTEXITCODE -ne 0) { throw "MP4 validation failed." }
Remove-Item -LiteralPath $avi -Force
$info = Get-Item -LiteralPath $mp4
Write-Output ("MOBILE_PREVIEW " + $info.FullName + " " + $info.Length + " bytes")
