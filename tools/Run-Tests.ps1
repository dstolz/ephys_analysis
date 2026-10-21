<#
.SYNOPSIS
Run test suites of ephys_analysis (or sections of them) in a hidden MATLAB, with a log, a timing ledger
and at most two test MATLABs on the machine at a time.

.DESCRIPTION
Starts MATLAB R2025a (bin\matlab.exe -wait: MATLAB.exe started directly ends every run in
"Error on flush" once a table is displayed) with -logfile and
-batch "cd('<repo>\pipeline'); run_all_tests({...}, ExcludeTag={'Slow','Benchmark'}, ResultsCSV=...)",
its preferences in %LOCALAPPDATA%\ephys_analysis\prefdir (never yours), echoes the log as it grows, and
exits with MATLAB's exit code (0 = every test passed; 124 = killed at the timeout; 2 = usage).
A cold start costs about 9 s on the owner's machine (measured 2026-10-21), so there is no warm session.

Every suite's row of the results table is appended to %LOCALAPPDATA%\ephys_analysis\test_timings.csv
(Date, Sha, Dirty, Suite, Sections, Seconds, Passed, Tests, Failed, Skipped, FreeGB, Machine), and every
"[suite section: N s]" line of the log to section_timings.csv, so the next run can say how long it will
take (printed as "expected ~N s").

Slots: a run takes one of two slots (lock files under %LOCALAPPDATA%\ephys_analysis\locks, counted under
a named mutex; a lock whose process is gone is stale). A third run waits for a free slot. Each slot has
its own preferences folder, so two MATLABs never share matlabprefs.mat.

.PARAMETER Suites
Suite names, each with optional sections: test_AppPrefs, test_EphysAnalysisApp:5i,5j.

.PARAMETER Select
Run what .github\scripts\select_suites.py --worktree --sections prints for the uncommitted change
(against -Base, default HEAD), and print why. "none" runs nothing; "all" (the change reaches the test
runner) is refused unless -All is given, since every suite takes about 25 minutes.

.PARAMETER IncludeSlow
Also run the tests tagged Slow and Benchmark (CI runs them; locally they are left out by default).

.PARAMETER Parallel
Split the suites over this many MATLABs (at most the two slots), longest first by the ledger.

.PARAMETER Each
Run every section of each named suite on its own (one MATLAB, one run_all_tests call per section),
to check that each section can run alone after the fixture; prints the sections that failed alone.

.PARAMETER DryRun
Print the suites, the expected time and the MATLAB command, and run nothing.

.EXAMPLE
tools\Run-Tests.ps1 test_AppPrefs
tools\Run-Tests.ps1 test_EphysAnalysisApp:5i,5j test_PlotDesign
tools\Run-Tests.ps1 -Select
tools\Run-Tests.ps1 -Select -DryRun
tools\Run-Tests.ps1 test_EphysPipelineApp test_EphysAnalysisFigures -Parallel 2
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)] [string[]] $Suites = @(),
    [switch] $Select,
    [string] $Base = 'HEAD',
    [switch] $All,
    [switch] $IncludeSlow,
    [switch] $Each,
    [switch] $DryRun,
    [ValidateRange(1, 2)] [int] $Parallel = 1,
    [int] $TimeoutMin = 120,
    [string] $MatlabRoot = '',
    [string] $LogDir = '',
    [switch] $NoLedger
)

$ErrorActionPreference = 'Stop'
$MaxSlots = 2

# "test_X:5i,5j" reaches PowerShell as the two pieces test_X:5i and 5j (the comma makes an array);
# join such pieces back onto the suite before them
$pieces = @()
foreach ($s in $Suites) { foreach ($p in ($s -split '[\s,]+')) { if ($p) { $pieces += $p } } }
$Suites = @()
foreach ($p in $pieces) {
    if ($p -match '^test_' -or $Suites.Count -eq 0) { $Suites += $p } else { $Suites[-1] += ',' + $p }
}
$repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$pipeline = Join-Path $repo 'pipeline'
$appData = Join-Path $env:LOCALAPPDATA 'ephys_analysis'
if (-not $LogDir) { $LogDir = Join-Path $appData 'logs' }
$ledger = Join-Path $appData 'test_timings.csv'
$sectionLedger = Join-Path $appData 'section_timings.csv'
$lockDir = Join-Path $appData 'locks'
foreach ($d in @($LogDir, $lockDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force $d | Out-Null } }

function Find-MatlabRoot {
    $roots = @()
    if ($MatlabRoot) { $roots += $MatlabRoot }
    if ($env:EPHYS_MATLAB_ROOT) { $roots += $env:EPHYS_MATLAB_ROOT }
    $roots += (Join-Path $env:ProgramFiles 'MATLAB\R2025a')
    $all = Get-ChildItem (Join-Path $env:ProgramFiles 'MATLAB') -Directory -Filter 'R20*' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending
    foreach ($r in $all) { $roots += $r.FullName }
    $cmd = Get-Command matlab -ErrorAction SilentlyContinue
    if ($cmd) { $roots += (Split-Path -Parent (Split-Path -Parent $cmd.Source)) }
    foreach ($r in $roots) {
        if ($r -and (Test-Path (Join-Path $r 'bin\win64\MATLAB.exe'))) { return $r }
    }
    throw "No MATLAB found (looked for bin\win64\MATLAB.exe under -MatlabRoot, EPHYS_MATLAB_ROOT, $env:ProgramFiles\MATLAB\R20*)."
}

function Find-Python {
    # @{ Exe; Args } (a one-element array would unroll to a string on return)
    foreach ($name in @('python', 'python3')) {
        $c = Get-Command $name -ErrorAction SilentlyContinue
        if ($c) { return @{ Exe = $c.Source; Args = @() } }
    }
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) { return @{ Exe = $py.Source; Args = @('-3') } }
    throw 'No python on the PATH (needed for -Select).'
}

function Get-FreeGB { [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 1) }

function Read-Ledger {
    if (-not (Test-Path $ledger)) { return @() }
    try { return @(Import-Csv $ledger) } catch { return @() }
}

function Get-Expected($entry, $rows) {
    # median Seconds of the last 5 ledger rows of this suite with these sections; $null when unknown
    $parts = $entry.Split(':', 2)
    $suite = $parts[0]
    $secs = ''
    if ($parts.Count -gt 1) { $secs = $parts[1] }
    $same = @($rows | Where-Object { $_.Suite -eq $suite -and $_.Sections -eq $secs } | Select-Object -Last 5)
    if ($same.Count -eq 0) { return $null }
    $v = @($same | ForEach-Object { [double]$_.Seconds } | Sort-Object)
    return $v[[int][math]::Floor(($v.Count - 1) / 2)]
}

# ---- the suites ---------------------------------------------------------------------------------

$why = @()
if ($Select) {
    $py = Find-Python
    $pyArgs = @($py.Args) + @((Join-Path $repo '.github\scripts\select_suites.py'), '--worktree', $Base, '--sections', '--why', '--expect')
    $out = & $py.Exe @pyArgs 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Host ($out -join "`n"); exit 2 }
    $lines = @($out | ForEach-Object { [string]$_ })
    $picked = $lines[0].Trim()
    $why = $lines[1..($lines.Count - 1)]
    if ($picked -eq 'none') { Write-Host 'Nothing to test: no suite reaches the change.'; exit 0 }
    if ($picked -eq 'all') {
        if (-not $All) {
            Write-Host 'The change reaches the test runner or the CI scripts, so every suite would run (about 25 min).'
            Write-Host 'Run again with -All to do that, or name the suites.'
            exit 2
        }
        $Suites = @()
    } else {
        $Suites = @($picked -split '\s+' | Where-Object { $_ })
    }
} elseif ($Suites.Count -eq 0) {
    Write-Host 'Usage: tools\Run-Tests.ps1 <suite[:sections]> ... | -Select [-DryRun]'
    exit 2
}
if ($why.Count -gt 0) { $why | ForEach-Object { Write-Host $_ } }

$rows = Read-Ledger
$expected = 0.0
$unknown = @()
foreach ($s in $Suites) {
    $e = Get-Expected $s $rows
    if ($null -eq $e) { $unknown += $s } else { $expected += $e }
}
if ($Suites.Count -eq 0) {
    Write-Host 'Suites: every suite'
} else {
    Write-Host ("Suites: " + ($Suites -join ' '))
    $msg = "expected ~{0} s" -f [math]::Round($expected)
    if ($unknown.Count -gt 0) { $msg += " (no record yet of " + ($unknown -join ', ') + ")" }
    Write-Host $msg
}

# ---- the MATLAB command(s) -------------------------------------------------------------------------

$root = Find-MatlabRoot
$exe = Join-Path $root 'bin\matlab.exe'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'

if ($Parallel -gt 1 -and $Suites.Count -gt 1) {
    # longest first, each to the group with the least expected time so far
    $sorted = @($Suites | Sort-Object { $e = Get-Expected $_ $rows; if ($null -eq $e) { 60 } else { -$e } })
    $groups = @(); $loads = @()
    for ($i = 0; $i -lt $Parallel; $i++) { $groups += ,@(); $loads += 0.0 }
    foreach ($s in $sorted) {
        $e = Get-Expected $s $rows; if ($null -eq $e) { $e = 60 }
        $k = 0; for ($i = 1; $i -lt $Parallel; $i++) { if ($loads[$i] -lt $loads[$k]) { $k = $i } }
        $groups[$k] += $s; $loads[$k] += $e
    }
    $groups = @($groups | Where-Object { $_.Count -gt 0 })
} else {
    $groups = @(,$Suites)
}

function New-BatchCommand($names, $csv) {
    $opts = @()
    if (-not $IncludeSlow) { $opts += "ExcludeTag={'Slow','Benchmark'}" }
    if ($Each) {
        # every section of every named suite alone, in one MATLAB; a CSV per section for the ledger
        $base = $csv -replace '\.csv$', ''
        $suiteList = "{'" + (($names | ForEach-Object { ($_ -split ':')[0] }) -join "','") + "'}"
        $optText = ''
        if ($opts.Count -gt 0) { $optText = ', ' + ($opts -join ', ') }
        return "cd('$pipeline'); addpath(fullfile(fileparts(pwd), 'analysis')); failed = {}; n = 0; for s = $suiteList, f = which(s{1}); ids = TestSections.list(f); " +
            "for id = ids, n = n + 1; try, run_all_tests({[s{1} ':' char(id)]}$optText, ResultsCSV=sprintf('%s_%s_%s.csv', '$base', s{1}, strrep(char(id), '.', '_'))); " +
            "catch ME, failed{end+1} = [s{1} ':' char(id)]; fprintf(2, 'SECTION FAILED ALONE %s:%s: %s\n', s{1}, id, ME.message); end, end, end; " +
            "fprintf('\nEACH: %d of %d sections failed alone', numel(failed), n); if ~isempty(failed), fprintf(': %s', strjoin(failed, ', ')); end; fprintf('\n'); " +
            "if ~isempty(failed), error('RunTests:Each', '%d of %d sections failed alone.', numel(failed), n); end"
    }
    $list = ''
    if ($names.Count -gt 0) { $list = "{'" + ($names -join "','") + "'}" }
    $opts += "ResultsCSV='$csv'"
    if ($list) { $argList = $list + ', ' + ($opts -join ', ') } else { $argList = $opts -join ', ' }
    return "cd('$pipeline'); run_all_tests($argList)"
}

$runs = @()
for ($g = 0; $g -lt $groups.Count; $g++) {
    $names = @($groups[$g])
    $tag = 'all'
    if ($names.Count -gt 0) { $tag = ($names[0] -split ':')[0]; if ($names.Count -gt 1) { $tag += "_+$($names.Count - 1)" } }
    if ($groups.Count -gt 1) { $tag += "_p$($g + 1)" }
    $log = Join-Path $LogDir "${stamp}_$tag.log"
    $csv = Join-Path $LogDir "${stamp}_$tag.csv"
    $runs += [pscustomobject]@{ Names = $names; Log = $log; Csv = $csv; Cmd = (New-BatchCommand $names $csv); Slot = 0; Proc = $null; Offset = 0; ExitCode = $null }
}

if ($DryRun) {
    foreach ($r in $runs) { Write-Host "`n$exe -wait -logfile `"$($r.Log)`" -batch `"$($r.Cmd)`"" }
    exit 0
}

# ---- slots ---------------------------------------------------------------------------------------

$mutex = New-Object System.Threading.Mutex($false, 'Global\ephys_analysis_test_slots')

function Invoke-Locked([scriptblock] $block) {
    [void] $mutex.WaitOne()
    try { & $block } finally { $mutex.ReleaseMutex() }
}

function Test-ProcessAlive($id) {
    if (-not $id) { return $false }
    return $null -ne (Get-Process -Id $id -ErrorAction SilentlyContinue)
}

function Get-FreeSlot {
    # the lowest slot whose lock file is missing or stale; 0 when none
    for ($i = 1; $i -le $MaxSlots; $i++) {
        $lock = Join-Path $lockDir "slot$i.lock"
        if (Test-Path $lock) {
            $owner = 0
            try { $owner = [int](Get-Content $lock -First 1) } catch { $owner = 0 }
            if (Test-ProcessAlive $owner) { continue }
        }
        return $i
    }
    return 0
}

function Request-Slot {
    $deadline = (Get-Date).AddMinutes($TimeoutMin)
    $said = $false
    while ($true) {
        $slot = Invoke-Locked {
            $s = Get-FreeSlot
            if ($s -gt 0) { Set-Content -Path (Join-Path $lockDir "slot$s.lock") -Value $PID -Encoding ASCII }
            $s
        }
        if ($slot -gt 0) { return $slot }
        if (-not $said) { Write-Host "Both test slots are busy (other runs of this script); waiting for one..."; $said = $true }
        if ((Get-Date) -gt $deadline) { throw 'No test slot came free within the timeout.' }
        Start-Sleep -Seconds 5
    }
}

function Remove-SlotLock($slot) {
    if ($slot -lt 1) { return }
    Invoke-Locked { Remove-Item (Join-Path $lockDir "slot$slot.lock") -ErrorAction SilentlyContinue }
}

function Stop-MatlabTree($launcherId) {
    # the launcher (bin\matlab.exe) and the MATLAB.exe it started
    Get-CimInstance Win32_Process -Filter "ParentProcessId=$launcherId" -ErrorAction SilentlyContinue |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Stop-Process -Id $launcherId -Force -ErrorAction SilentlyContinue
}

function Read-NewText($path, $run) {
    if (-not (Test-Path $path)) { return '' }
    $fs = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        if ($fs.Length -le $run.Offset) { return '' }
        [void] $fs.Seek($run.Offset, [IO.SeekOrigin]::Begin)
        $buf = New-Object byte[] ($fs.Length - $run.Offset)
        $n = $fs.Read($buf, 0, $buf.Length)
        $run.Offset += $n
        return [Text.Encoding]::UTF8.GetString($buf, 0, $n)
    } finally { $fs.Dispose() }
}

# ---- run -----------------------------------------------------------------------------------------

if ($runs.Count -gt 1 -and (Get-FreeGB) -lt 6) {
    Write-Host ("Only {0} GB free: running the groups one after another instead of {1} at once." -f (Get-FreeGB), $runs.Count)
    $names = @(); foreach ($r in $runs) { $names += $r.Names }
    $runs = @($runs[0]); $runs[0].Names = $names; $runs[0].Cmd = New-BatchCommand $names $runs[0].Csv
}

$freeGB = Get-FreeGB
$sha = ''; $dirty = ''
try {
    $sha = [string](& git -C $repo rev-parse --short HEAD 2>&1)
    $sha = $sha.Trim()
    $status = @(& git -C $repo status --porcelain 2>&1)
    if ($status.Count -gt 0) { $dirty = 'yes' } else { $dirty = 'no' }
} catch { }

$started = Get-Date
try {
    foreach ($r in $runs) {
        $r.Slot = Request-Slot
        $env:MATLAB_PREFDIR = Join-Path $appData "prefdir\R2025a-$($r.Slot)"
        if (-not (Test-Path $env:MATLAB_PREFDIR)) { New-Item -ItemType Directory -Force $env:MATLAB_PREFDIR | Out-Null }
        Write-Host "`n[slot $($r.Slot)] $($r.Cmd)"
        Write-Host "[slot $($r.Slot)] log: $($r.Log)"
        $r.Proc = Start-Process -FilePath $exe -ArgumentList @('-wait', '-logfile', "`"$($r.Log)`"", '-batch', "`"$($r.Cmd)`"") -PassThru -WindowStyle Hidden
    }
    $deadline = $started.AddMinutes($TimeoutMin)
    while ($true) {
        $busy = $false
        foreach ($r in $runs) {
            if ($null -ne $r.ExitCode) { continue }
            $txt = Read-NewText $r.Log $r
            if ($txt) {
                if ($runs.Count -gt 1) { $txt = ($txt -replace '(?m)^', "[$($r.Slot)] ") }
                Write-Host -NoNewline $txt
            }
            if ($r.Proc.HasExited) {
                $r.ExitCode = $r.Proc.ExitCode
                Remove-SlotLock $r.Slot; $r.Slot = 0
                $txt = Read-NewText $r.Log $r
                if ($txt) { Write-Host -NoNewline $txt }
            } else {
                $busy = $true
            }
        }
        if (-not $busy) { break }
        if ((Get-Date) -gt $deadline) {
            foreach ($r in $runs) {
                if ($null -eq $r.ExitCode) {
                    Write-Host "`nTimeout after $TimeoutMin min: killing MATLAB $($r.Proc.Id)."
                    Stop-MatlabTree $r.Proc.Id
                    $r.ExitCode = 124
                }
            }
            break
        }
        Start-Sleep -Seconds 2
    }
} finally {
    foreach ($r in $runs) { if ($r.Slot -gt 0) { Remove-SlotLock $r.Slot } }
    $mutex.Dispose()
}

# ---- the ledger ----------------------------------------------------------------------------------

$elapsed = [math]::Round(((Get-Date) - $started).TotalSeconds)
$date = $started.ToString('s')
if (-not $NoLedger) {
    $mutex2 = New-Object System.Threading.Mutex($false, 'Global\ephys_analysis_test_ledger')
    [void] $mutex2.WaitOne()
    try {
        foreach ($r in $runs) {
            $csvs = @()
            if ($Each) { $csvs = @(Get-ChildItem (($r.Csv -replace '\.csv$', '') + '_*.csv') -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }
            elseif (Test-Path $r.Csv) { $csvs = @($r.Csv) }
            foreach ($csvFile in $csvs) {
                $rowsOut = Import-Csv $csvFile | ForEach-Object {
                    [pscustomobject]@{ Date = $date; Sha = $sha; Dirty = $dirty; Suite = $_.Suite; Sections = $_.Sections
                        Seconds = [math]::Round([double]$_.Seconds, 1); Passed = $_.Passed; Tests = $_.Tests; Failed = $_.Failed
                        Skipped = $_.Skipped; FreeGB = $freeGB; Machine = $env:COMPUTERNAME }
                }
                $new = -not (Test-Path $ledger)
                $csvText = $rowsOut | ConvertTo-Csv -NoTypeInformation
                if (-not $new) { $csvText = $csvText | Select-Object -Skip 1 }
                Add-Content -Path $ledger -Value $csvText -Encoding UTF8
            }
            if (Test-Path $r.Log) {
                $secRows = Get-Content $r.Log | ForEach-Object {
                    if ($_ -match '^\s*\[(\S+) (\S+): ([\d.]+) s\]\s*$') {
                        [pscustomobject]@{ Date = $date; Sha = $sha; Suite = $matches[1]; Section = $matches[2]; Seconds = $matches[3] }
                    }
                }
                if ($secRows) {
                    $new = -not (Test-Path $sectionLedger)
                    $csvText = @($secRows) | ConvertTo-Csv -NoTypeInformation
                    if (-not $new) { $csvText = $csvText | Select-Object -Skip 1 }
                    Add-Content -Path $sectionLedger -Value $csvText -Encoding UTF8
                }
            }
        }
    } finally { $mutex2.ReleaseMutex(); $mutex2.Dispose() }
}

$code = 0
foreach ($r in $runs) { if ($r.ExitCode -gt $code) { $code = $r.ExitCode } }
Write-Host ("`n{0} in {1} s (exit {2}); logs in {3}" -f $(if ($code -eq 0) { 'Passed' } elseif ($code -eq 124) { 'Timed out' } else { 'Failed' }), $elapsed, $code, $LogDir)
exit $code
