<#
.SYNOPSIS
Run test suites of ephys_analysis (or sections of them) in a hidden MATLAB, with a log, a timing ledger
and at most two test MATLABs on the machine at a time.

.DESCRIPTION
Starts MATLAB R2025a (bin\matlab.exe -wait: MATLAB.exe started directly ends every run in
"Error on flush" once a table is displayed) with -logfile and
-batch "cd('<repo>\pipeline'); run_all_tests({...}, ExcludeTag={'Slow','Benchmark'}, ResultsCSV=...)",
its preferences in %LOCALAPPDATA%\ephys_analysis\prefdir (never yours), echoes the log as it grows, and
exits with MATLAB's exit code (0 = every test passed; 1 = a test failed; 3 = a dialog waits for a person,
see below; 124 = killed at the timeout; 2 = usage).
A cold start costs about 9 s on the owner's machine (measured 2026-10-21), so there is no warm session.

Every suite's row of the results table is appended to %LOCALAPPDATA%\ephys_analysis\test_timings.csv
(Date, Sha, Dirty, Suite, Sections, Seconds, Passed, Tests, Failed, Skipped, FreeGB, Machine), and every
"[suite section: N s]" line of the log to section_timings.csv, so the next run can say how long it will
take (printed as "expected ~N s").

Windows: MATLAB runs on a desktop of its own that is never shown (Win32 CreateDesktop, "ephys_analysis_tests"),
so the apps and figures the tests open are drawn there and never come over your windows or take the focus.
-Visible runs it on your desktop instead, to watch.

Dialogs that wait for a person: nobody can answer one on the hidden desktop, so the run looks for them
(run_all_tests DialogWatch=-DialogSec, and the native dialogs' windows of the run's processes) and prints an
"ACTION NEEDED" block that names the dialog, the code that asked, the test line and the command to run it
on your desktop with -Interactive. Without -Interactive the run is then stopped (exit 3). Under -batch
MATLAB refuses its own blocking dialogs (questdlg, uiconfirm, uigetfile, ...: the test fails with "Creating
dialog boxes that block execution is not supported"); that prints the block too, and exits 3.

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

.PARAMETER Visible
Run MATLAB on your desktop, so the windows the tests open can be watched (they come over your other windows).

.PARAMETER Interactive
Run MATLAB on your desktop with -r instead of -batch, so a dialog the tests open waits for your answer (implies
-Visible; MATLAB's command window starts minimized). An "ACTION NEEDED" block says which window to answer;
the run goes on once you have.

.PARAMETER DialogSec
Seconds a dialog may wait before it counts as waiting for a person (default 30; tests that answer their own
dialogs from a timer do so within a few seconds).

.PARAMETER TimeoutMin
Minutes, from the start, after which every MATLAB still running is killed (exit 124); also the longest wait
for a free slot. Default 45 (every suite takes about 25 minutes on a quiet machine).

.PARAMETER DryRun
Print the suites, the expected time and the MATLAB command, and run nothing.

.EXAMPLE
tools\Run-Tests.ps1 test_AppPrefs
tools\Run-Tests.ps1 test_EphysAnalysisApp:5i,5j test_PlotDesign
tools\Run-Tests.ps1 -Select
tools\Run-Tests.ps1 -Select -DryRun
tools\Run-Tests.ps1 test_EphysPipelineApp test_EphysAnalysisFigures -Parallel 2
tools\Run-Tests.ps1 'test_EphysAnalysisApp:5n' -Interactive
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
    [switch] $Visible,
    [switch] $Interactive,
    [ValidateRange(5, 3600)] [int] $DialogSec = 30,
    [ValidateRange(1, 2)] [int] $Parallel = 1,
    [int] $TimeoutMin = 45,
    [string] $MatlabRoot = '',
    [string] $LogDir = '',
    [switch] $NoLedger
)

$ErrorActionPreference = 'Stop'
$MaxSlots = 2
if ($Interactive) { $Visible = [switch]::Present }

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
    $opts += "DialogWatch=$DialogSec"
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
    $runs += [pscustomobject]@{ Names = $names; Log = $log; Csv = $csv; Cmd = (New-BatchCommand $names $csv); Slot = 0; Proc = $null; Offset = 0; ExitCode = $null
        Tail = ''; Section = ''; SectionTitle = ''; Needs = $false; Told = @{}; NativeSince = @{}; LastNativeCheck = (Get-Date) }
}

function Get-MatlabArgs($r) {
    # -batch, or with -Interactive -r (MATLAB then lets its blocking dialogs wait for an answer), exiting
    # 1 on an error as -batch does
    if ($Interactive) {
        $rCmd = "try, $($r.Cmd); catch e, fprintf(2, '%s\n', getReport(e)); exit(1); end; exit(0)"
        return @('-wait', '-nodesktop', '-nosplash', '-minimize', '-logfile', "`"$($r.Log)`"", '-r', "`"$rCmd`"")
    }
    return @('-wait', '-logfile', "`"$($r.Log)`"", '-batch', "`"$($r.Cmd)`"")
}

if ($DryRun) {
    foreach ($r in $runs) { Write-Host ("`n$exe " + ((Get-MatlabArgs $r) -join ' ')) }
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
    # the launcher (bin\matlab.exe), the MATLAB.exe it started and that one's windows (MATLABWindow.exe)
    $ids = Get-ProcessTree $launcherId
    [array]::Reverse($ids)
    foreach ($id in $ids) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
}

$HiddenDesktopSource = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

// A process started on a desktop that is never shown: its windows (and its children's, which inherit
// the desktop) cannot come over the user's windows or take the focus. Id, HasExited and ExitCode
// as on System.Diagnostics.Process. DialogWindows finds the native dialogs (class #32770: file
// pickers, message boxes) that given processes show, on that desktop or on the user's.
public class EphysTestDesktop {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct STARTUPINFO {
        public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2;
        public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateDesktop(string name, IntPtr device, IntPtr devmode, int flags, uint access, IntPtr sa);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool CreateProcess(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit,
        uint flags, IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr h, uint ms);
    [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr h, out uint code);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumDesktopWindows(IntPtr desk, EnumWindowsProc fn, IntPtr lParam);
    [DllImport("user32.dll")] static extern IntPtr GetThreadDesktop(uint threadId);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd, StringBuilder s, int n);

    const uint GENERIC_ALL = 0x10000000, CREATE_NEW_CONSOLE = 0x10;
    const int STARTF_USESHOWWINDOW = 1; const short SW_HIDE = 0;
    static IntPtr desktop = IntPtr.Zero;   // held open for the life of this PowerShell

    IntPtr handle;
    public int Id { get; private set; }

    public static EphysTestDesktop Start(string desktopName, string commandLine) {
        if (desktop == IntPtr.Zero) {
            desktop = CreateDesktop(desktopName, IntPtr.Zero, IntPtr.Zero, 0, GENERIC_ALL, IntPtr.Zero);
            if (desktop == IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }
        var si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
        si.lpDesktop = @"WinSta0\" + desktopName;
        si.dwFlags = STARTF_USESHOWWINDOW; si.wShowWindow = SW_HIDE;
        PROCESS_INFORMATION pi;
        if (!CreateProcess(null, new StringBuilder(commandLine), IntPtr.Zero, IntPtr.Zero, false,
                CREATE_NEW_CONSOLE, IntPtr.Zero, null, ref si, out pi))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        CloseHandle(pi.hThread);
        var p = new EphysTestDesktop();
        p.handle = pi.hProcess; p.Id = pi.dwProcessId;
        return p;
    }
    public bool HasExited { get { return WaitForSingleObject(handle, 0) == 0; } }
    public int ExitCode { get { uint c; GetExitCodeProcess(handle, out c); return unchecked((int)c); } }

    // the titles of the visible native dialogs of processes PIDS, on the hidden desktop or on the user's
    public static string[] DialogWindows(int[] pids, bool onHidden) {
        var found = new System.Collections.Generic.List<string>();
        IntPtr desk = onHidden ? desktop : GetThreadDesktop(GetCurrentThreadId());
        if (desk == IntPtr.Zero) return found.ToArray();
        var want = new System.Collections.Generic.HashSet<int>(pids);
        EnumDesktopWindows(desk, (hwnd, l) => {
            uint pid; GetWindowThreadProcessId(hwnd, out pid);
            if (!want.Contains((int)pid) || !IsWindowVisible(hwnd)) return true;
            var cls = new StringBuilder(64); GetClassName(hwnd, cls, cls.Capacity);
            if (cls.ToString() != "#32770") return true;
            var title = new StringBuilder(256); GetWindowText(hwnd, title, title.Capacity);
            found.Add(title.ToString());
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }
}
'@

if (-not ('EphysTestDesktop' -as [type])) { Add-Type -TypeDefinition $HiddenDesktopSource -Language CSharp }

function Start-Matlab($argList) {
    # MATLAB on the hidden desktop (default) or on the user's, hidden console either way; the environment
    # (MATLAB_PREFDIR) is this process's
    if ($Visible) { return Start-Process -FilePath $exe -ArgumentList $argList -PassThru -WindowStyle Hidden }
    return [EphysTestDesktop]::Start('ephys_analysis_tests', "`"$exe`" " + ($argList -join ' '))
}

function Get-ProcessTree($rootId) {
    # the ids of process ROOTID and all its descendants
    $all = @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId -ErrorAction SilentlyContinue)
    $ids = @([int]$rootId); $i = 0
    while ($i -lt $ids.Count) {
        foreach ($p in $all) { if ($p.ParentProcessId -eq $ids[$i] -and $ids -notcontains [int]$p.ProcessId) { $ids += [int]$p.ProcessId } }
        $i++
    }
    return [int[]]$ids
}

function Show-ActionNeeded($r, [string] $what, [string] $where, [string] $suite, [switch] $Refused) {
    # the block the agent (and you) cannot miss: what waits, where it was asked, and how to answer it
    $rerun = ($r.Names | ForEach-Object { "'$_'" }) -join ' '
    if ($suite -and $r.Section) { $rerun = "'${suite}:$($r.Section)'" } elseif ($suite) { $rerun = "'$suite'" }
    $bar = '!' * 100
    Write-Host ''
    Write-Host $bar -ForegroundColor Yellow
    Write-Host '!!  ACTION NEEDED: a test is waiting for an answer from a person' -ForegroundColor Yellow
    Write-Host "!!  dialog:  $what" -ForegroundColor Yellow
    if ($where) { Write-Host "!!  where:   $where" -ForegroundColor Yellow }
    if ($r.SectionTitle) { Write-Host "!!  section: $($r.SectionTitle)" -ForegroundColor Yellow }
    if ($Interactive) {
        Write-Host '!!  Answer it on your screen now (the window named above); the run goes on once you have.' -ForegroundColor Yellow
    } elseif ($Refused) {
        Write-Host '!!  Under -batch MATLAB cannot show it, so the test failed (exit 3). To answer it yourself:' -ForegroundColor Yellow
        Write-Host "!!    tools\Run-Tests.ps1 $rerun -Interactive" -ForegroundColor Yellow
    } else {
        Write-Host '!!  Nobody can answer it on the hidden desktop, so this run stops (exit 3). To answer it yourself:' -ForegroundColor Yellow
        Write-Host "!!    tools\Run-Tests.ps1 $rerun -Interactive" -ForegroundColor Yellow
    }
    Write-Host $bar -ForegroundColor Yellow
    $r.Needs = $true
}

function Find-WaitingDialogs($r, [string] $txt) {
    # the [needs you] lines run_all_tests prints, MATLAB's refusals under -batch, the section headers, and
    # (every 10 s) the native dialogs of the run's processes; each is shown once
    $text = $r.Tail + $txt
    $lines = $text -split "`r?`n"
    $r.Tail = $lines[-1]
    $complete = @(); if ($lines.Count -gt 1) { $complete = $lines[0..($lines.Count - 2)] }   # (0..-1 would be both ends)
    foreach ($line in $complete) {
        if ($line -match '^== (\S+)\. ') { $r.Section = $matches[1]; $r.SectionTitle = $line.Trim('= ') }
        elseif ($line -match '^\[needs you\] (.*)$') {
            $parts = $matches[1] -split ' \| '
            $suite = ''; $test = ''
            $t = $parts | Where-Object { $_ -like 'test *' } | Select-Object -First 1
            if ($t -and $t -match '^test (test_[A-Za-z0-9_]+)') { $suite = $matches[1]; $test = $t.Substring(5) }
            $asked = ($parts | Where-Object { $_ -like 'asked by *' } | Select-Object -First 1)
            if ($asked -and $test -and $asked.Substring(9) -eq $test) { $test = '' }   # asked from the test line itself
            $where = (@($asked, $test) | Where-Object { $_ }) -join '; test line '
            if (-not $r.Told.ContainsKey($line)) { $r.Told[$line] = $true; Show-ActionNeeded $r $parts[0] $where $suite }
        }
        elseif ($line -match 'Creating dialog boxes that block execution is not supported' -and -not $r.Told.ContainsKey('refused')) {
            $r.Told['refused'] = $true
            Show-ActionNeeded $r 'one of MATLAB''s own dialogs (questdlg, uiconfirm, uigetfile, ...)' `
                'the failure report above (its stack names the code that asked and the test line)' '' -Refused
        }
    }
    if (((Get-Date) - $r.LastNativeCheck).TotalSeconds -ge 10) {
        $r.LastNativeCheck = Get-Date
        $titles = @([EphysTestDesktop]::DialogWindows((Get-ProcessTree $r.Proc.Id), -not $Visible))
        foreach ($k in @($r.NativeSince.Keys)) { if ($titles -notcontains $k) { $r.NativeSince.Remove($k) } }
        foreach ($t in $titles) {
            if (-not $r.NativeSince.ContainsKey($t)) { $r.NativeSince[$t] = Get-Date; continue }
            if (((Get-Date) - $r.NativeSince[$t]).TotalSeconds -ge $DialogSec -and -not $r.Told.ContainsKey("native:$t")) {
                $r.Told["native:$t"] = $true
                Show-ActionNeeded $r "a Windows dialog `"$t`" (a file picker or message box)" '' ''
            }
        }
    }
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
        $r.Proc = Start-Matlab (Get-MatlabArgs $r)
    }
    if ($Interactive) {
        Write-Host "`n-Interactive: MATLAB runs on your desktop; a dialog a test opens waits for your answer. Watch this"
        Write-Host 'output for ACTION NEEDED: it names the window to answer.'
    }
    $deadline = $started.AddMinutes($TimeoutMin)
    while ($true) {
        $busy = $false
        foreach ($r in $runs) {
            if ($null -ne $r.ExitCode) { continue }
            $txt = Read-NewText $r.Log $r
            $shown = $txt
            if ($shown) {
                if ($runs.Count -gt 1) { $shown = ($shown -replace '(?m)^', "[$($r.Slot)] ") }
                Write-Host -NoNewline $shown
            }
            Find-WaitingDialogs $r $txt
            if ($r.Proc.HasExited) {
                $r.ExitCode = $r.Proc.ExitCode
                Remove-SlotLock $r.Slot; $r.Slot = 0
                $txt = Read-NewText $r.Log $r
                if ($txt) { Write-Host -NoNewline $txt; Find-WaitingDialogs $r ($txt + "`n") }
            } elseif ($r.Needs -and -not $Interactive) {
                Write-Host "`nStopping MATLAB $($r.Proc.Id): a dialog needs a person (see above)."
                Stop-MatlabTree $r.Proc.Id
                $r.ExitCode = 3
                Remove-SlotLock $r.Slot; $r.Slot = 0
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
foreach ($r in $runs) {
    if ($r.Needs -and -not $Interactive -and $r.ExitCode -ne 124) { $r.ExitCode = 3 }   # a dialog nobody could answer
    if ($r.ExitCode -gt $code) { $code = $r.ExitCode }
}
$verdict = switch ($code) { 0 { 'Passed' } 3 { 'ACTION NEEDED (a dialog waits for a person; see above)' } 124 { 'Timed out' } default { 'Failed' } }
Write-Host ("`n{0} in {1} s (exit {2}); logs in {3}" -f $verdict, $elapsed, $code, $LogDir)
exit $code
