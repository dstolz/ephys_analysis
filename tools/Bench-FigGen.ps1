<#
.SYNOPSIS
Run tools\benchFigGenUI.m (timings of the Figures tab) in MATLAB on a hidden desktop.

.DESCRIPTION
Starts MATLAB R2025a on the desktop of Run-Tests.ps1 (never shown, so no window covers your work), with
a scratch MATLAB preferences folder that holds a COPY of your matlabprefs.mat (read for LastConfigFile and
FigureAutoRedraw) and the app's own preferences in a scratch file (EPHYS_APP_PREFS_FILE), so nothing of
yours is written. Waits, prints the exit code and the seconds, and tails the log.

-Project ''  runs the synthetic fixture. -Config, -Figure, -Auto and -Reps go to benchFigGenUI.
-Scratch is the folder for the log and the scratch preferences (default: %TEMP%\bench_figgen).
#>
param(
    [string]$Project = 'S:\ANALYSIS_BACKUPS\Daniel\EPHYS\OFC\Analysis',
    [string]$Config = '',
    [string]$Figure = '',
    [string]$Auto = '',
    [int]$Reps = 3,
    [string]$Log = '',
    [string]$Scratch = '',
    [int]$TimeoutMin = 20
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $Scratch) { $Scratch = Join-Path $env:TEMP 'bench_figgen' }
New-Item -ItemType Directory -Force $Scratch | Out-Null
if (-not $Log) { $Log = Join-Path $Scratch ('bench_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log') }
$matlabLog = [IO.Path]::ChangeExtension($Log, '.matlab.log')

$src = Get-Content -Raw (Join-Path $PSScriptRoot 'Run-Tests.ps1')
if ($src -notmatch "(?s)\`$HiddenDesktopSource = @'\r?\n(.*?)\r?\n'@") { throw 'no C# source in Run-Tests.ps1' }
if (-not ('EphysTestDesktop' -as [type])) { Add-Type -TypeDefinition $matches[1] -Language CSharp }

$prefdir = Join-Path $Scratch 'prefdir'
New-Item -ItemType Directory -Force $prefdir | Out-Null
$real = Join-Path $env:APPDATA 'MathWorks\MATLAB\R2025a\matlabprefs.mat'
if (Test-Path $real) { Copy-Item $real (Join-Path $prefdir 'matlabprefs.mat') -Force } else { Write-Host "no ${real}: no preferences to read" }
$env:MATLAB_PREFDIR = $prefdir
$env:EPHYS_APP_PREFS_FILE = Join-Path $Scratch 'app_prefs.mat'
if (Test-Path $env:EPHYS_APP_PREFS_FILE) { Remove-Item $env:EPHYS_APP_PREFS_FILE }

# -batch drops double quotes: single quotes inside (a quote in a value is doubled)
function Q([string]$s) { "'" + $s.Replace("'", "''") + "'" }
$ml = "Project=$(Q $Project)"
if ($Config) { $ml += ", Config=$(Q $Config)" }
if ($Figure) { $ml += ", Figure=$(Q $Figure)" }
if ($Auto) { $ml += ", Auto=$Auto" }
$ml += ", Reps=$Reps, Log=$(Q $Log)"
$exe = 'C:\Program Files\MATLAB\R2025a\bin\matlab.exe'
$batch = "cd($(Q (Join-Path $repo 'tools'))); benchFigGenUI($ml)"
$cmd = "`"$exe`" -wait -logfile `"$matlabLog`" -batch `"$batch`""
Write-Host "log: $Log"
$p = [EphysTestDesktop]::Start('ephys_analysis_tests', $cmd)
$t0 = Get-Date
while (-not $p.HasExited) {
    Start-Sleep -Seconds 5
    if (((Get-Date) - $t0).TotalMinutes -gt $TimeoutMin) { Stop-Process -Id $p.Id -Force; Write-Host 'TIMEOUT'; break }
}
Write-Host "exit $($p.ExitCode) after $([int]((Get-Date) - $t0).TotalSeconds) s"
if (Test-Path $matlabLog) { Get-Content $matlabLog -Tail 60 }
