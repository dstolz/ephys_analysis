# Platforms

The pipeline is developed and run on Windows 11 with MATLAB R2025a. Reading
recordings, deriving signals, detecting spikes, sorting through Python,
the exports, the analysis and the apps use MATLAB and Python only, and have
paths for macOS and Linux. Those paths have not been run there. A few
features use Windows itself, and they check through one helper,
`platformSupport`. On macOS and Linux they are a known gap, refused with one
kind of message that names what they use and what to do instead.

`platformSupport()` prints this table at runtime, with a `Here` column for
the machine it runs on:

| Feature | What it uses | Windows | macOS | Linux | Elsewhere |
| --- | --- | --- | --- | --- | --- |
| Reading recordings, signals, spikes, sorting, exports, analysis and the apps (`core`) | MATLAB, and Python for sorting, probe design and NWB | yes | untested | untested | |
| Copying sessions: `copySessions`, the Copy tab; copying a run's outputs: `OutputTransfer`, the `Transfer` section (`copy`) | robocopy and a detached PowerShell copy engine | yes | no | no | copy the session folders, and the outputs afterwards, with the system's own tools (rsync, cp); the pipeline reads them where they are |
| A scheduled copy: `CopySchedule` (`copySchedule`) | Windows Task Scheduler | yes | no | no | schedule copies of your own with cron or launchd |
| Clean-up to the Recycle Bin: `runLocalCleanup(Method="recycle")` (`recycle`) | the Recycle Bin and the registry | yes | no | no | `Method="delete"` or `"move"` |
| The Run tab's resource monitor (`resourceMonitor`) | PowerShell performance counters and nvidia-smi | yes | no | no | the system's own monitor (top, htop, nvidia-smi) |
| Background Kilosort4 runs: `Sorting.Execution = "background"` (`backgroundSort`) | `cmd start` on Windows; a background `sh` on macOS and Linux | yes | untested | untested | `Sorting.Execution = "blocking"` |
| Stopping a sorting run: `EphysDataset.stopSortRun` (`stopSort`) | PowerShell and taskkill on Windows; `pgrep` / `pkill` on macOS and Linux | yes | untested | untested | end the Python process by hand |
| Opening a folder or file from the apps: `openInSystem` (`openInSystem`) | `winopen` on Windows; `open` on macOS; `xdg-open` on Linux | yes | untested | untested | open it from the file browser |
| Launching phy from the Review tab (`phy`) | `phy.exe` of the conda env `phy` on Windows; `bin/phy` on macOS and Linux | yes | untested | untested | start phy from a terminal in the sort folder |

"untested" means the code has a path for that platform that has not been
run there; a report of how it goes is welcome. The install guide,
[INSTALL.md](../pipeline/INSTALL.md), covers Windows. Elsewhere the same
pieces apply: MATLAB with the Signal Processing Toolbox, and a conda
environment for Kilosort4 (`bin/python` instead of `python.exe`).

| Function | |
| --- | --- |
| `T = platformSupport()` | the table above, plus `Here` |
| `tf = platformSupport(feature)` | whether `feature` can run here |
| `platformSupport(feature, Require=true, ErrorId=)` | raises `platformSupport:Unsupported`, or `ErrorId` (`copySessions:NotWindows`, `CopySchedule:NotWindows`, `runLocalCleanup:Recycle` keep theirs), when it cannot |
| `openInSystem(target)` | opens a folder in the file browser, or a file in its default program; `openInSystem:Missing`, `openInSystem:Failed` |

Suite `test_PlatformSupport` checks the table, the refusal on a platform
where a feature is "no" (skipped on Windows, where none is) and
`openInSystem`'s error.
