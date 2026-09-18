<#
.SYNOPSIS
    Copy engine for copySessions.m: runs the file copying and checksumming of a
    session batch outside MATLAB so the app stays responsive.

.DESCRIPTION
    copySessions plans a batch, writes it as a job JSON and launches this script
    detached, once per phase:

      -Phase copy   create each destination folder and its subfolders, then run
                    robocopy once per source group (not once per file), and
                    report every expected file's source and destination size.
      -Phase hash   report the SHA-256 of every expected file's source and
                    destination. Only run when Verify="hash", and only after
                    MATLAB has size-checked the copy.

    Nothing in a source tree is ever written: robocopy is called without /MIR,
    /MOV and /PURGE, so files in a destination that are not in the source are
    left alone. /Z makes a partially transferred file resume rather than
    restart, and robocopy skips a file that is already there with the same size
    and timestamp, which is what makes IfExists="resume" cheap.

    Progress is one JSON object per line, appended to the job's progress file
    and flushed immediately so MATLAB can tail it. A robocopy says nothing until
    it exits, so while one runs the engine sizes the session's destination files
    instead and reports that as a progress event; the same event carries how far
    a SHA-256 has read. Without them a multi-gigabyte session would sit at the
    same percentage from beginning to end:

      {"event":"start","phase":"copy","sessions":2,"bytes":12345}
      {"event":"session","index":1,"state":"copying","files":5,"bytes":9999}
      {"event":"progress","index":1,"bytesDone":4096,"files":2,"filesTotal":5,"bytes":4096,"bytesTotal":9999}
      {"event":"robocopy","index":1,"group":1,"exit":1,"seconds":0.4}
      {"event":"file","index":1,"rel":"amplifier.dat","srcBytes":8192,"destBytes":8192,"bytesDone":8192}
      {"event":"session","index":1,"state":"done","error":""}
      {"event":"end","state":"done","message":""}

    When every session is finished the job's status file is written with the
    final state ("done", "cancelled" or "error"); MATLAB polls for that file to
    learn the phase is over. Creating the job's cancel file stops the engine:
    a running robocopy is killed, the partial copy is left in place, and the
    remaining sessions are reported "cancelled".

    This script is an engine only. Which rows may be copied, what counts as a
    verified copy, the ePsych stitching and the session manifest all stay in
    copySessions.m.

.NOTES
    Targets Windows PowerShell 5.1, which ships with Windows; it does not need
    PowerShell 7. See also copySessions.m.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Job,
    [Parameter(Mandatory)][ValidateSet('copy', 'hash')][string] $Phase
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# File work goes through .NET rather than cmdlets on purpose: a PSModulePath
# that lists PowerShell 7's modules before 5.1's makes this host load the wrong
# Microsoft.PowerShell.Utility, and cmdlets such as Get-FileHash then do not
# exist. ConvertTo-Json / ConvertFrom-Json are the only cmdlets relied on.
$spec = [System.IO.File]::ReadAllText($Job) | ConvertFrom-Json
$out = [System.IO.StreamWriter]::new($spec.progressFile, $true)
$out.AutoFlush = $true

$bytesDone = 0.0
$state = 'done'
$message = ''

function Write-Event([hashtable] $e) {
    $out.WriteLine((ConvertTo-Json $e -Compress -Depth 4))
}

function Test-Cancelled {
    return ($spec.cancelFile -ne '') -and [System.IO.File]::Exists($spec.cancelFile)
}

$script:lastBeat = [DateTime]::MinValue

function Write-Heartbeat {
    # MATLAB watches this file's age so that an engine that dies (or is killed)
    # is noticed instead of being waited on for ever. A long single-file copy
    # produces no events, so the beat also ticks inside the robocopy wait.
    if (([DateTime]::Now - $script:lastBeat).TotalSeconds -lt 2) { return }
    $script:lastBeat = [DateTime]::Now
    try {
        [System.IO.File]::WriteAllText($spec.heartbeatFile, $script:lastBeat.Ticks.ToString())
    } catch { }
}

$script:reported = 0.0                   # the largest running total written: it never goes backwards

function Get-Reported([double] $v) {
    # The file events of a session restart from what its robocopy finished with,
    # which is behind what sizing the destination had already reported. Reporting
    # the larger of the two keeps the percentage from stepping back.
    if ($v -gt $script:reported) { $script:reported = $v }
    return $script:reported
}

$script:live = $null                      # the session robocopy is working on, or $null
$script:liveBase = 0.0                   # phase bytes finished before that session
$script:liveTotal = 0.0                  # its expected bytes
$script:liveEvery = 1.0                  # seconds between sweeps of its destination
$script:lastLive = [DateTime]::MinValue

function Write-LiveProgress {
    # robocopy reports nothing until it exits, so the only way to say how far a
    # session has got is to size the destination files it expects. That is cheap
    # (tens of files on a local disk) and moves inside one big file too, because
    # /Z grows the destination as it copies. A sweep that turns out to be slow
    # (very many files) spaces the next ones out rather than competing with the
    # copy: at most a tenth of the time is spent measuring it.
    if ($null -eq $script:live) { return }
    if (([DateTime]::Now - $script:lastLive).TotalSeconds -lt $script:liveEvery) { return }
    $script:lastLive = [DateTime]::Now
    $t0 = [DateTime]::Now
    $expect = @($script:live.expect)
    $done = 0.0
    $files = 0
    foreach ($e in $expect) {
        $n = Get-Length ([System.IO.Path]::Combine($script:live.dest, $e.rel))
        if ($n -lt 0) { continue }
        if ($n -ge [double]$e.bytes) { $n = [double]$e.bytes; $files++ }   # never report more than was planned
        $done += $n
    }
    $script:liveEvery = [math]::Max(1.0, 10 * ([DateTime]::Now - $t0).TotalSeconds)
    Write-Event @{ event = 'progress'; index = $script:live.index; bytesDone = (Get-Reported ($script:liveBase + $done));
        files = $files; filesTotal = $expect.Count; bytes = $done; bytesTotal = $script:liveTotal }
}

$script:hashBase = 0.0                   # phase bytes finished before the file being hashed
$script:hashTotal = 0.0                  # that file's bytes
$script:hashRead = 0.0                   # what has been read of it, source and destination
$script:hashIndex = 0
$script:hashRel = ''
$script:lastHashBeat = [DateTime]::MinValue

function Write-HashProgress {
    # Called from Get-Sha256 between chunks: checksumming one big file is minutes
    # of reading that would otherwise pass without a word.
    if (([DateTime]::Now - $script:lastHashBeat).TotalSeconds -lt 1) { return }
    $script:lastHashBeat = [DateTime]::Now
    $done = [math]::Min($script:hashRead / 2, $script:hashTotal)   # source and destination are both read
    Write-Event @{ event = 'progress'; index = $script:hashIndex; bytesDone = (Get-Reported ($script:hashBase + $done));
        rel = $script:hashRel; bytes = $done; bytesTotal = $script:hashTotal }
}

function Format-Arg([string] $p) {
    # Native separators; a trailing one would escape the closing quote, so a
    # drive root becomes "D:\." (the same rule as quoteArg in copySessions.m).
    $p = $p -replace '/', '\'
    if ($p.EndsWith('\')) { $p += '.' }
    return '"' + $p + '"'
}

function Get-Length([string] $p) {
    # -1 means "not a file that can be sized": missing, a folder, or unreadable.
    try {
        if ([System.IO.Directory]::Exists($p)) { return -1 }
        $i = New-Object System.IO.FileInfo -ArgumentList $p
        if (-not $i.Exists) { return -1 }
        return [double]$i.Length
    } catch {
        return -1
    }
}

function Get-Sha256([string] $p) {
    $sha = $null
    $fs = $null
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $fs = [System.IO.File]::Open($p, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        # Read it in chunks rather than handing the stream to ComputeHash: the
        # digest is the same one, and between chunks the engine can beat and say
        # how far it has read.
        $buf = New-Object byte[] 4194304
        while (($n = $fs.Read($buf, 0, $buf.Length)) -gt 0) {
            [void]$sha.TransformBlock($buf, 0, $n, $null, 0)
            $script:hashRead += $n
            Write-Heartbeat
            Write-HashProgress
        }
        [void]$sha.TransformFinalBlock($buf, 0, 0)
        return [System.BitConverter]::ToString($sha.Hash).Replace('-', '').ToLowerInvariant()
    } catch {
        $script:lastHashError = $_.Exception.Message
        return ''
    } finally {
        if ($null -ne $fs) { $fs.Dispose() }
        if ($null -ne $sha) { $sha.Dispose() }
    }
}

function Invoke-Robocopy([string] $src, [string] $dst, [string[]] $files, [bool] $recurse, [string] $log) {
    # One robocopy per source group. Returns its exit code, or -1 when cancelled.
    $a = @((Format-Arg $src), (Format-Arg $dst))
    foreach ($f in $files) { $a += (Format-Arg $f) }
    if ($recurse) { $a += '/E' }          # /E, not /S: empty source subfolders are kept
    $a += @('/Z', '/MT:8', '/R:3', '/W:5', '/NP', ('/LOG+:' + (Format-Arg $log)))

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'robocopy.exe'
    $psi.Arguments = ($a -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    while (-not $p.WaitForExit(250)) {
        Write-Heartbeat
        Write-LiveProgress
        if (Test-Cancelled) {
            try { $p.Kill() } catch { }
            try { $p.WaitForExit(5000) | Out-Null } catch { }
            return -1
        }
    }
    return $p.ExitCode
}

try {
    $sessions = @($spec.sessions)
    $totalBytes = 0.0
    foreach ($s in $sessions) { foreach ($e in @($s.expect)) { $totalBytes += [double]$e.bytes } }
    Write-Event @{ event = 'start'; phase = $Phase; sessions = $sessions.Count; bytes = $totalBytes }
    Write-Heartbeat

    foreach ($s in $sessions) {
        Write-Heartbeat
        if (Test-Cancelled) {
            Write-Event @{ event = 'session'; index = $s.index; state = 'cancelled' }
            $state = 'cancelled'
            continue
        }
        $expect = @($s.expect)
        $err = ''

        if ($Phase -eq 'copy') {
            $bytes = 0.0
            foreach ($e in $expect) { $bytes += [double]$e.bytes }
            Write-Event @{ event = 'session'; index = $s.index; state = 'copying'; files = $expect.Count; bytes = $bytes }
            try {
                [void][System.IO.Directory]::CreateDirectory($s.dest)
                foreach ($d in @($s.subdirs)) {
                    [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($s.dest, $d))
                }
                $script:live = $s
                $script:liveBase = $bytesDone
                $script:liveTotal = $bytes
                $script:lastLive = [DateTime]::MinValue
                $g = 0
                foreach ($grp in @($s.groups)) {
                    $g++
                    $t0 = [DateTime]::Now
                    $code = Invoke-Robocopy $grp.src $s.dest @($grp.files) ([bool]$grp.recurse) $s.log
                    $secs = [math]::Round(([DateTime]::Now - $t0).TotalSeconds, 2)
                    Write-Event @{ event = 'robocopy'; index = $s.index; group = $g; exit = $code; seconds = $secs }
                    if ($code -lt 0) {
                        $err = 'cancelled'
                        $state = 'cancelled'
                        break
                    }
                    if ($code -ge 8) {
                        $err = "robocopy failed (exit code $code) for $($grp.src); see $($s.log)"
                        break
                    }
                }
            } catch {
                $err = $_.Exception.Message
            }
            $script:live = $null
        } else {
            Write-Event @{ event = 'session'; index = $s.index; state = 'hashing'; files = $expect.Count }
        }

        if ($err -ne 'cancelled') {
            foreach ($e in $expect) {
                $rec = @{ event = 'file'; index = $s.index; rel = $e.rel }
                if ($Phase -eq 'copy') {
                    $rec.srcBytes = (Get-Length $e.src)
                    $rec.destBytes = (Get-Length ([System.IO.Path]::Combine($s.dest, $e.rel)))
                } else {
                    $script:lastHashError = ''
                    $script:hashBase = $bytesDone
                    $script:hashTotal = [double]$e.bytes
                    $script:hashRead = 0.0
                    $script:hashIndex = $s.index
                    $script:hashRel = $e.rel
                    $rec.sha256Source = (Get-Sha256 $e.src)
                    $rec.sha256Destination = (Get-Sha256 ([System.IO.Path]::Combine($s.dest, $e.rel)))
                    if ($script:lastHashError -ne '') { $rec.hashError = $script:lastHashError }
                }
                $bytesDone += [double]$e.bytes
                $rec.bytesDone = (Get-Reported $bytesDone)
                Write-Event $rec
                Write-Heartbeat
                if (Test-Cancelled) { break }
            }
        }

        if ($err -eq 'cancelled') {
            Write-Event @{ event = 'session'; index = $s.index; state = 'cancelled' }
        } else {
            Write-Event @{ event = 'session'; index = $s.index; state = 'done'; error = $err }
        }
    }

    if (Test-Cancelled) { $state = 'cancelled' }
} catch {
    $state = 'error'
    $message = $_.Exception.Message
    try { Write-Event @{ event = 'end'; state = $state; message = $message } } catch { }
}

try {
    Write-Event @{ event = 'end'; state = $state; message = $message }
} catch { }
try { $out.Close() } catch { }

$status = @{
    state = $state
    message = $message
    phase = $Phase
    finishedAt = [DateTime]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz')
}
# WriteAllText, not Set-Content -Encoding UTF8: Windows PowerShell 5.1 would
# write a byte-order mark, which MATLAB's jsondecode refuses.
[System.IO.File]::WriteAllText($spec.statusFile, (ConvertTo-Json $status -Compress -Depth 3))
