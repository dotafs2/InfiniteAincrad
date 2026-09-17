[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Save')]
    [string]$SavePath,
    [string]$Godot = $env:GODOT_EXE,
    [string]$Ledger,
    [string]$Config,
    [string]$Out,
    [ValidateRange(5, 900)]
    [int]$Seconds = 300,
    [ValidateRange(1, 32)]
    [int]$MaxRequests = 12,
    [ValidateRange(1, 3)]
    [int]$Concurrency = 1,
    [ValidateRange(0, 120)]
    [double]$ShutdownWait = 45,
    [string]$GmExport,
    [switch]$ObserveOnly,
    [switch]$StopOnIdle,
    [switch]$StopOnDecisionLimit,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$save = [IO.Path]::GetFullPath($SavePath)
if (-not (Test-Path -LiteralPath $save -PathType Leaf)) {
    throw "SavePath does not exist: $save"
}

$gatewayValues = @($Ledger, $Config, $Out) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
if ($gatewayValues.Count -ne 0 -and $gatewayValues.Count -ne 3) {
    throw 'Live AI mode requires Ledger, Config, and Out together. Nothing was launched.'
}
$live = $gatewayValues.Count -eq 3
if (-not $live -and -not $ObserveOnly) {
    throw 'Choose live AI with Ledger + Config + Out, or explicitly pass -ObserveOnly. Nothing was launched.'
}
if ($live -and $ObserveOnly) {
    throw 'ObserveOnly cannot be combined with live Ledger/Config/Out. Nothing was launched.'
}

if (-not $Godot) {
    $localEngine = Join-Path $root 'tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe'
    if (Test-Path -LiteralPath $localEngine) { $Godot = $localEngine }
}
if (-not $Godot) {
    $installed = Get-Command godot -ErrorAction SilentlyContinue
    if ($installed) { $Godot = $installed.Source }
}
if (-not $Godot -or -not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    throw 'Provide Godot 4.7.2 .NET with -Godot <path> or GODOT_EXE.'
}
$Godot = [IO.Path]::GetFullPath($Godot)

$oldDotnetRoot = $env:DOTNET_ROOT
$oldDotnetRootX64 = $env:DOTNET_ROOT_X64
$oldRollForward = $env:DOTNET_ROLL_FORWARD
try {
    if (-not $env:DOTNET_ROOT -and (Test-Path -LiteralPath 'C:\Program Files\dotnet\dotnet.exe')) {
        $env:DOTNET_ROOT = 'C:\Program Files\dotnet'
    }
    if ($env:DOTNET_ROOT) { $env:DOTNET_ROOT_X64 = $env:DOTNET_ROOT }
    $env:DOTNET_ROLL_FORWARD = 'LatestMajor'

    if (-not $SkipBuild) {
        & dotnet build (Join-Path $root 'game/InfiniteAincrad.csproj') --disable-build-servers -v minimal
        if ($LASTEXITCODE -ne 0) { throw 'Godot .NET build failed; the world was not launched.' }
        & $Godot --headless --editor --import --path (Join-Path $root 'game')
        if ($LASTEXITCODE -ne 0) { throw 'Godot asset import failed; the world was not launched.' }
    }

    if (-not $live) {
        Write-Host 'Opening ten physical residents in restore-only observation: models paused, no new decisions, no model calls.'
        $observe = @('--path', (Join-Path $root 'game'), 'res://scenes/town_street.tscn', '--',
            ('--town-save=' + $save), '--town-restore')
        & $Godot @observe
        $result = $LASTEXITCODE
    } else {
        $liveArgs = @('-X', 'utf8', (Join-Path $root 'tools/run_town_model_validation.py'),
            '--godot', $Godot,
            '--ledger', [IO.Path]::GetFullPath($Ledger),
            '--config', [IO.Path]::GetFullPath($Config),
            '--save', $save,
            '--out', [IO.Path]::GetFullPath($Out),
            '--seconds', $Seconds,
            '--max-requests', $MaxRequests,
            '--concurrency', $Concurrency,
            '--shutdown-wait', $ShutdownWait)
        if ($GmExport) { $liveArgs += @('--gm-export', [IO.Path]::GetFullPath($GmExport)) }
        if ($StopOnIdle) { $liveArgs += '--stop-on-idle' }
        if ($StopOnDecisionLimit) { $liveArgs += '--stop-on-decision-limit' }
        Write-Host 'Opening the bounded live AI world. Historical events remain labelled separately from this run.'
        & python @liveArgs
        $result = $LASTEXITCODE
    }
} finally {
    $env:DOTNET_ROOT = $oldDotnetRoot
    $env:DOTNET_ROOT_X64 = $oldDotnetRootX64
    $env:DOTNET_ROLL_FORWARD = $oldRollForward
}
exit $result
