<#
.SYNOPSIS
    Resource sampler for EphysPreprocessingApp: CPU, memory, disk and GPU use,
    sampled outside MATLAB so watching them costs the app almost nothing.

.DESCRIPTION
    The app launches this script detached when Monitor resources is ticked on
    the Run tab, each time in a fresh folder -Dir. Every -Interval seconds it
    overwrites <Dir>\sample.json with one JSON object, the latest sample:

      {"t":"2026-09-18T10:41:21","cpu":37.2,"memUsedGB":12.3,"memTotalGB":31.7,
       "disk":54.1,"diskName":"1 D:","readMBs":80.2,"writeMBs":12.5,
       "gpus":[{"index":0,"name":"...","util":28,"memUsedMB":869,"memTotalMB":4094}],
       "gpuNote":""}

    cpu is Task Manager's figure (% Processor Utility, falling back to
    % Processor Time); disk is the active time of the busiest physical disk,
    and readMBs / writeMBs are summed over all disks. GPU use comes from one
    long-running `nvidia-smi -lms` child rather than a process per sample;
    without nvidia-smi, gpus is empty and gpuNote says why.

    The counters are opened once and read with NextValue, so a sample is a few
    microseconds of work; the script runs at Idle priority and sleeps between
    samples. It stops by itself when the -ParentPid process (MATLAB) exits or
    <Dir>\stop appears, and then deletes -Dir.

.NOTES
    Targets Windows PowerShell 5.1. Uses .NET rather than cmdlets throughout:
    on this workstation 5.1 can load PowerShell 7's Utility module and lose
    cmdlets (see copy_engine.ps1). Counter names are the English ones.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Dir,
    [Parameter(Mandatory)][int] $ParentPid,
    [double] $Interval = 2
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

try { [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = 'Idle' } catch { }

function New-Counter([string] $category, [string] $counter, [string] $instance) {
    try {
        $c = New-Object System.Diagnostics.PerformanceCounter($category, $counter, $instance, $true)
        [void] $c.NextValue()   # rate counters need a first read to have a baseline
        return $c
    } catch {
        return $null
    }
}

function Get-DiskCounters {
    # One % Idle Time counter per physical disk (not _Total), re-read now and
    # then so a disk plugged in later is picked up.
    $list = @()
    try {
        $names = (New-Object System.Diagnostics.PerformanceCounterCategory('PhysicalDisk')).GetInstanceNames()
        foreach ($n in ($names | Sort-Object)) {
            if ($n -eq '_Total') { continue }
            $c = New-Counter 'PhysicalDisk' '% Idle Time' $n
            if ($null -ne $c) { $list += [pscustomobject]@{ Name = $n; Counter = $c } }
        }
    } catch { }
    return ,$list
}

function Start-Gpu([double] $interval) {
    # nvidia-smi in loop mode: it prints one line per GPU every interval.
    $exe = $null
    foreach ($p in @("$env:SystemRoot\System32\nvidia-smi.exe",
                     "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe")) {
        if ([System.IO.File]::Exists($p)) { $exe = $p; break }
    }
    if ($null -eq $exe) { return $null }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = '--query-gpu=index,name,utilization.gpu,memory.used,memory.total ' +
                     '--format=csv,noheader,nounits -lms ' + [int]($interval * 1000)
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    try { $p.PriorityClass = 'Idle' } catch { }
    return $p
}

function Parse-Gpu([string] $line) {
    $f = $line.Split(',') | ForEach-Object { $_.Trim() }
    if ($f.Count -lt 5) { return $null }
    $num = { param($s) $v = 0.0; if ([double]::TryParse($s, [ref] $v)) { $v } else { $null } }
    return [ordered]@{
        index      = [int] (& $num $f[0])
        name       = $f[1]
        util       = & $num $f[2]
        memUsedMB  = & $num $f[3]
        memTotalMB = & $num $f[4]
    }
}

function Test-Parent([int] $id) {
    try {
        $p = [System.Diagnostics.Process]::GetProcessById($id)
        $alive = -not $p.HasExited
        $p.Dispose()
        return $alive
    } catch {
        return $false
    }
}

[void] [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$info = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
$memTotal = [double] $info.TotalPhysicalMemory

$cpu = New-Counter 'Processor Information' '% Processor Utility' '_Total'
if ($null -eq $cpu) { $cpu = New-Counter 'Processor' '% Processor Time' '_Total' }
$readC  = New-Counter 'PhysicalDisk' 'Disk Read Bytes/sec' '_Total'
$writeC = New-Counter 'PhysicalDisk' 'Disk Write Bytes/sec' '_Total'
$disks = Get-DiskCounters
$disksAt = [DateTime]::UtcNow

$gpu = $null; $gpuNote = ''; $gpuTask = $null
$gpuLatest = @{}
try {
    $gpu = Start-Gpu $Interval
    if ($null -eq $gpu) { $gpuNote = 'nvidia-smi not found' }
    else { $gpuTask = $gpu.StandardOutput.ReadLineAsync() }
} catch {
    $gpuNote = 'nvidia-smi failed: ' + $_.Exception.Message
}

$OutFile  = [System.IO.Path]::Combine($Dir, 'sample.json')
$StopFile = [System.IO.Path]::Combine($Dir, 'stop')
$tmp      = [System.IO.Path]::Combine($Dir, 'sample.tmp')
$ms = [int]($Interval * 1000)
try {
    while ($true) {
        if ([System.IO.File]::Exists($StopFile) -or -not (Test-Parent $ParentPid)) { break }

        if (([DateTime]::UtcNow - $disksAt).TotalSeconds -ge 30) {
            foreach ($d in $disks) { $d.Counter.Dispose() }
            $disks = Get-DiskCounters
            $disksAt = [DateTime]::UtcNow
        }

        # Drain every line nvidia-smi has printed since the last sample.
        if ($null -ne $gpuTask) {
            while ($gpuTask.IsCompleted) {
                $line = $gpuTask.Result
                if ($null -eq $line) {   # nvidia-smi exited
                    $gpuTask = $null
                    $gpuNote = 'nvidia-smi stopped'
                    $gpuLatest = @{}
                    break
                }
                $g = Parse-Gpu $line
                if ($null -ne $g) { $gpuLatest[$g.index] = $g }
                $gpuTask = $gpu.StandardOutput.ReadLineAsync()
            }
        }

        $busy = $null; $busyName = ''
        foreach ($d in $disks) {
            try {
                $b = [Math]::Max(0.0, [Math]::Min(100.0, 100.0 - $d.Counter.NextValue()))
                if ($null -eq $busy -or $b -gt $busy) { $busy = $b; $busyName = $d.Name }
            } catch { }
        }

        $gpus = @()
        foreach ($k in ($gpuLatest.Keys | Sort-Object)) { $gpus += $gpuLatest[$k] }

        $memAvail = [double] $info.AvailablePhysicalMemory
        $sample = [ordered]@{
            t          = [DateTime]::Now.ToString('yyyy-MM-ddTHH:mm:ss')
            cpu        = if ($null -ne $cpu) { [Math]::Round([Math]::Min(100.0, $cpu.NextValue()), 1) } else { $null }
            memUsedGB  = [Math]::Round(($memTotal - $memAvail) / 1GB, 2)
            memTotalGB = [Math]::Round($memTotal / 1GB, 2)
            disk       = if ($null -ne $busy) { [Math]::Round($busy, 1) } else { $null }
            diskName   = $busyName
            readMBs    = if ($null -ne $readC)  { [Math]::Round($readC.NextValue() / 1MB, 1) } else { $null }
            writeMBs   = if ($null -ne $writeC) { [Math]::Round($writeC.NextValue() / 1MB, 1) } else { $null }
            gpus       = $gpus
            gpuNote    = $gpuNote
        }
        $json = ConvertTo-Json -InputObject $sample -Compress -Depth 4
        # Write aside and swap in, so MATLAB never reads half a sample.
        [System.IO.File]::WriteAllText($tmp, $json)
        try {
            if ([System.IO.File]::Exists($OutFile)) { [System.IO.File]::Replace($tmp, $OutFile, $null) }
            else { [System.IO.File]::Move($tmp, $OutFile) }
        } catch {
            try { [System.IO.File]::WriteAllText($OutFile, $json) } catch { }   # MATLAB had it open: next time
        }

        [System.Threading.Thread]::Sleep($ms)
    }
} finally {
    if ($null -ne $gpu) {
        try { if (-not $gpu.HasExited) { $gpu.Kill() } } catch { }
    }
    foreach ($f in @($OutFile, $tmp, $StopFile)) {
        try { [System.IO.File]::Delete($f) } catch { }
    }
    try { [System.IO.Directory]::Delete($Dir) } catch { }   # only if empty
}
