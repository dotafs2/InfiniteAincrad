#Requires -Version 7.0
<#
.SYNOPSIS
Launches ONE visible Godot editor for the Godot Anime Material Lab.

.DESCRIPTION
- The editor window is intentionally VISIBLE: the user asked to edit the shared
  shader include in the built-in shader editor.
- Isolated editor profile: only the child process gets APPDATA/LOCALAPPDATA
  pointed at C:/GodotAnimeLab/_editor_profile, so Godot editor settings, layouts
  and its own log live inside this project. Machine environment is not changed.
- Records pid, start identity, executable and argv in _work/editor-process.json.
- Re-running while the recorded lab editor is still alive does not launch a
  duplicate (use -Force to override).
- Debug server / LSP / DAP use free loopback ports checked before launch, so a
  second Godot on this machine cannot collide.

.EXAMPLE
pwsh -File C:/GodotAnimeLab/Open-Lab.ps1
#>
[CmdletBinding()]
param(
	[switch]$Force
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = 'C:/GodotAnimeLab'
$EnginePath  = 'C:/Users/quchenxi/.cache/level0-tools/godot-4.7.2-mono/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe'
$WorkDir     = Join-Path $ProjectRoot '_work'
$StatePath   = Join-Path $WorkDir 'editor-process.json'
$LogPath     = Join-Path $WorkDir 'editor.log'
$ProfileRoot = Join-Path $ProjectRoot '_editor_profile'
$RoamingDir  = Join-Path $ProfileRoot 'Roaming'
$LocalDir    = Join-Path $ProfileRoot 'Local'
$ScenePath   = 'res://scenes/material_lab.tscn'
$PortBase    = 64217

function Test-TcpPortFree {
	param([int]$Port)
	$listener = $null
	try {
		$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
		$listener.Start()
		return $true
	} catch {
		return $false
	} finally {
		if ($listener) { $listener.Stop() }
	}
}

function Get-FreePorts {
	param([int]$Start, [int]$Count)
	$found = [System.Collections.Generic.List[int]]::new()
	$candidate = $Start
	while ($found.Count -lt $Count -and $candidate -lt ($Start + 400)) {
		if (Test-TcpPortFree -Port $candidate) { $found.Add($candidate) }
		$candidate++
	}
	if ($found.Count -lt $Count) { throw "No free TCP ports found near $Start" }
	return $found.ToArray()
}

if (-not (Test-Path -LiteralPath $EnginePath)) {
	throw "Godot engine not found: $EnginePath"
}

if ((Test-Path -LiteralPath $StatePath) -and -not $Force) {
	$recorded = $null
	try { $recorded = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json } catch { $recorded = $null }
	if ($recorded -and $recorded.pid) {
		$live = Get-Process -Id $recorded.pid -ErrorAction SilentlyContinue
		if ($live) {
			$sameExe = $false
			$sameStart = $false
			try { $sameExe = ($live.Path -replace '\\', '/') -eq $EnginePath } catch { $sameExe = $false }
			try { $sameStart = $live.StartTime.ToUniversalTime().Ticks -eq ([datetime]$recorded.start_time_utc).ToUniversalTime().Ticks } catch { $sameStart = $false }
			if ($sameExe -and $sameStart) {
				Write-Host "Lab editor already running (pid $($recorded.pid)); not launching a duplicate."
				Write-Host "State: $StatePath"
				exit 0
			}
			Write-Host "Recorded pid $($recorded.pid) is a different process; launching a fresh editor."
		}
	}
}

foreach ($dir in @($WorkDir, $ProfileRoot, $RoamingDir, $LocalDir)) {
	if (-not (Test-Path -LiteralPath $dir)) {
		New-Item -ItemType Directory -Path $dir -Force | Out-Null
	}
}

# Keep Godot from importing the editor profile that sits inside this project.
$gdIgnore = Join-Path $ProfileRoot '.gdignore'
if (-not (Test-Path -LiteralPath $gdIgnore)) {
	New-Item -ItemType File -Path $gdIgnore | Out-Null
}

$ports = Get-FreePorts -Start $PortBase -Count 3
$debugPort = $ports[0]
$lspPort = $ports[1]
$dapPort = $ports[2]

$arguments = @(
	'-e'
	'--path', $ProjectRoot
	'--scene', $ScenePath
	'--resolution', '1400x900'
	'--max-fps', '30'
	'--log-file', $LogPath
	'--debug-server', "tcp://127.0.0.1:$debugPort"
	'--lsp-port', "$lspPort"
	'--dap-port', "$dapPort"
)

# Output goes to files (not to a pipe that dies with the caller), so the editor
# survives after the launching shell exits. Env overrides are process-only.
$stdoutLog = Join-Path $WorkDir 'editor.stdout.log'
$stderrLog = Join-Path $WorkDir 'editor.stderr.log'
$environmentOverrides = @{
	APPDATA = $RoamingDir
	LOCALAPPDATA = $LocalDir
}

if ((Get-Command Start-Process).Parameters.ContainsKey('Environment')) {
	$process = Start-Process -FilePath $EnginePath -ArgumentList $arguments -WorkingDirectory $ProjectRoot `
		-Environment $environmentOverrides -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -PassThru
} else {
	$psi = [System.Diagnostics.ProcessStartInfo]::new()
	$psi.FileName = $EnginePath
	$psi.WorkingDirectory = $ProjectRoot
	$psi.UseShellExecute = $false
	$psi.CreateNoWindow = $false
	foreach ($argument in $arguments) { [void]$psi.ArgumentList.Add($argument) }
	$psi.Environment['APPDATA'] = $RoamingDir
	$psi.Environment['LOCALAPPDATA'] = $LocalDir
	$process = [System.Diagnostics.Process]::Start($psi)
}
Start-Sleep -Milliseconds 1500
if ($process.HasExited) {
	throw "Godot exited immediately (exit code $($process.ExitCode)); see $LogPath"
}

$state = [ordered]@{
	schema = 'godot-anime-lab/editor-process/1'
	pid = $process.Id
	start_time_utc = $process.StartTime.ToUniversalTime().ToString('o')
	start_time_local = $process.StartTime.ToString('o')
	executable = $EnginePath
	arguments = $arguments
	working_directory = $ProjectRoot
	log_file = $LogPath
	stdout_log = $stdoutLog
	stderr_log = $stderrLog
	profile_appdata = $RoamingDir
	profile_localappdata = $LocalDir
	ports = [ordered]@{ debug_server = $debugPort; lsp = $lspPort; dap = $dapPort }
	visible_window = $true
	user_requested = 'The user asked for a visible editor to edit the shared shader include; this process is an intentional persistent handoff.'
	launched_at_utc = [DateTime]::UtcNow.ToString('o')
	launched_by = 'Open-Lab.ps1'
}
$state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StatePath -Encoding utf8NoBOM

Write-Host "Godot lab editor started (visible)."
Write-Host "  pid        : $($process.Id)"
Write-Host "  executable : $EnginePath"
Write-Host "  log        : $LogPath
  stdout     : $stdoutLog"
Write-Host "  state      : $StatePath"
Write-Host "  profile    : $RoamingDir / $LocalDir"
Write-Host "  3D view    : middle mouse = orbit, Shift+middle = pan, right mouse + WASD = free-look, F = frame selected."
