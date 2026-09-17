[CmdletBinding()]
param(
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

# A double-click may use one ignored, path-only local profile. It never contains a
# token and this launcher never creates, replenishes, or rewrites the paid ledger.
$localProfilePath = Join-Path $root 'private/night-delivery/start-living.local.json'
$explicitGateway = $PSBoundParameters.ContainsKey('Ledger') -or
    $PSBoundParameters.ContainsKey('Config') -or $PSBoundParameters.ContainsKey('Out')
$explicitObserve = $PSBoundParameters.ContainsKey('ObserveOnly')
$localMode = ''
if (Test-Path -LiteralPath $localProfilePath -PathType Leaf) {
    try {
        $localProfile = Get-Content -Raw -LiteralPath $localProfilePath | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Invalid local launcher JSON: $localProfilePath`n$($_.Exception.Message)"
    }
    $allowed = @('mode', 'expires_at', 'on_expiry', 'save_path', 'godot', 'ledger', 'config',
        'out', 'out_root', 'gm_export', 'seconds', 'max_requests', 'concurrency',
        'shutdown_wait', 'stop_on_idle', 'stop_on_decision_limit', 'skip_build')
    foreach ($property in $localProfile.PSObject.Properties.Name) {
        if ($property -notin $allowed) { throw "Unknown local launcher setting: $property" }
    }
    function Has-LocalSetting([string]$Name) {
        return $null -ne $localProfile.PSObject.Properties[$Name]
    }
    function Resolve-LocalPath([string]$Value) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return $Value }
        if ([IO.Path]::IsPathRooted($Value)) { return [IO.Path]::GetFullPath($Value) }
        return [IO.Path]::GetFullPath((Join-Path $root $Value))
    }
    if (-not $PSBoundParameters.ContainsKey('SavePath') -and (Has-LocalSetting 'save_path')) { $SavePath = Resolve-LocalPath ([string]$localProfile.save_path) }
    if (-not $PSBoundParameters.ContainsKey('Godot') -and (Has-LocalSetting 'godot')) { $Godot = Resolve-LocalPath ([string]$localProfile.godot) }
    if (-not $PSBoundParameters.ContainsKey('Ledger') -and (Has-LocalSetting 'ledger')) { $Ledger = Resolve-LocalPath ([string]$localProfile.ledger) }
    if (-not $PSBoundParameters.ContainsKey('Config') -and (Has-LocalSetting 'config')) { $Config = Resolve-LocalPath ([string]$localProfile.config) }
    if (-not $PSBoundParameters.ContainsKey('Out') -and (Has-LocalSetting 'out')) { $Out = Resolve-LocalPath ([string]$localProfile.out) }
    if (-not $PSBoundParameters.ContainsKey('Out') -and [string]::IsNullOrWhiteSpace($Out) -and (Has-LocalSetting 'out_root')) {
        $outRoot = Resolve-LocalPath ([string]$localProfile.out_root)
        $Out = Join-Path $outRoot ('run-' + (Get-Date).ToString('yyyyMMdd-HHmmss-fff'))
    }
    if (-not $PSBoundParameters.ContainsKey('GmExport') -and (Has-LocalSetting 'gm_export')) { $GmExport = Resolve-LocalPath ([string]$localProfile.gm_export) }
    if (-not $PSBoundParameters.ContainsKey('Seconds') -and (Has-LocalSetting 'seconds')) { $Seconds = [int]$localProfile.seconds }
    if (-not $PSBoundParameters.ContainsKey('MaxRequests') -and (Has-LocalSetting 'max_requests')) { $MaxRequests = [int]$localProfile.max_requests }
    if (-not $PSBoundParameters.ContainsKey('Concurrency') -and (Has-LocalSetting 'concurrency')) { $Concurrency = [int]$localProfile.concurrency }
    if (-not $PSBoundParameters.ContainsKey('ShutdownWait') -and (Has-LocalSetting 'shutdown_wait')) { $ShutdownWait = [double]$localProfile.shutdown_wait }
    if (-not $PSBoundParameters.ContainsKey('StopOnIdle') -and (Has-LocalSetting 'stop_on_idle')) { $StopOnIdle = [bool]$localProfile.stop_on_idle }
    if (-not $PSBoundParameters.ContainsKey('StopOnDecisionLimit') -and (Has-LocalSetting 'stop_on_decision_limit')) { $StopOnDecisionLimit = [bool]$localProfile.stop_on_decision_limit }
    if (-not $PSBoundParameters.ContainsKey('SkipBuild') -and (Has-LocalSetting 'skip_build')) { $SkipBuild = [bool]$localProfile.skip_build }

    if (Has-LocalSetting 'mode') { $localMode = ([string]$localProfile.mode).ToLowerInvariant() }
    if ($localMode -notin @('', 'live', 'observe_only')) {
        throw 'Local launcher mode must be live or observe_only.'
    }
    if ((Has-LocalSetting 'on_expiry') -and ([string]$localProfile.on_expiry).ToLowerInvariant() -notin @('error', 'observe_only')) {
        throw 'Local launcher on_expiry must be error or observe_only.'
    }
    if (-not $explicitGateway -and -not $explicitObserve -and $localMode -eq 'observe_only') {
        $ObserveOnly = $true
        $Ledger = $null; $Config = $null; $Out = $null; $GmExport = $null
    }
    if (-not $explicitGateway -and -not $explicitObserve -and $localMode -eq 'live' -and (Has-LocalSetting 'expires_at')) {
        $expiry = [DateTimeOffset]::MinValue
        if ($localProfile.expires_at -is [DateTime]) {
            # PowerShell 7 may eagerly decode ISO JSON dates; the resulting Local kind retains
            # the configured offset. Windows PowerShell 5 keeps the same field as a string.
            $expiry = [DateTimeOffset]$localProfile.expires_at
        } else {
            $expiryText = [string]$localProfile.expires_at
            if ($expiryText -notmatch '(Z|[+-][0-9]{2}:[0-9]{2})$') {
                throw 'Local launcher expires_at must include an explicit UTC offset or Z.'
            }
            if (-not [DateTimeOffset]::TryParse($expiryText, [ref]$expiry)) { throw 'Local launcher expires_at is invalid.' }
        }
        if ([DateTimeOffset]::Now -ge $expiry) {
            $onExpiry = if (Has-LocalSetting 'on_expiry') { ([string]$localProfile.on_expiry).ToLowerInvariant() } else { 'error' }
            if ($onExpiry -eq 'observe_only') {
                Write-Warning "The configured live AI window expired at $($expiry.ToString('o')). Opening explicit observe-only replay; quota is not reset."
                $ObserveOnly = $true
                $Ledger = $null; $Config = $null; $Out = $null; $GmExport = $null
            } elseif ($onExpiry -eq 'error') {
                throw "The configured live AI window expired at $($expiry.ToString('o')). The launcher will not reset or extend it."
            } else {
                throw 'Local launcher on_expiry must be error or observe_only.'
            }
        }
    }
}

if ($Seconds -lt 5 -or $Seconds -gt 900) { throw 'Seconds must be within 5..900.' }
if ($MaxRequests -lt 1 -or $MaxRequests -gt 32) { throw 'MaxRequests must be within 1..32.' }
if ($Concurrency -lt 1 -or $Concurrency -gt 3) { throw 'Concurrency must be within 1..3.' }
if ($ShutdownWait -lt 0 -or $ShutdownWait -gt 120) { throw 'ShutdownWait must be within 0..120.' }
if ([string]::IsNullOrWhiteSpace($SavePath)) {
    throw "No world is configured. Create $localProfilePath from StartLiving.local.example.json, or pass -SavePath and an explicit live/observe mode."
}
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
