function out = platformSupport(feature, opts)
%platformSupport  Which features depend on the operating system, and one error for those that cannot run here.
%   T = platformSupport() is the support matrix, one row per feature that
%   depends on the operating system (documentation/platforms.md shows the
%   same table): Feature (the key), Description, Uses (what it relies on),
%   Windows, macOS and Linux ("yes": tested there; "untested": the code
%   has a path for that platform that has not been run there; "no": not
%   available), Alternative (what to do where it is not available) and Here
%   (true when it can run on this machine: not "no").
%   TF = platformSupport(FEATURE) is Here for one feature.
%   platformSupport(FEATURE, Require=true) raises platformSupport:Unsupported
%   when FEATURE cannot run here, with a message that names the feature,
%   what it uses and the alternative. ErrorId= gives the identifier instead
%   (a caller's own, kept for code that catches it).
%
%   Every Windows-only piece checks through here, so on macOS and Linux it
%   is a known gap with one kind of message, not a failure deep inside.
%
%   See also openInSystem, copySessions, CopySchedule, runLocalCleanup.

arguments
    feature (1,1) string = ""
    opts.Require (1,1) logical = false
    opts.ErrorId (1,1) string = "platformSupport:Unsupported"
end

T = matrix();
if ispc
    here = "Windows";
elseif ismac
    here = "macOS";
else
    here = "Linux";
end
T.Here = T.(here) ~= "no";
if feature == ""
    out = T;
    return
end
row = T.Feature == feature;
if ~any(row)
    error('platformSupport:UnknownFeature', 'No feature "%s" (the features are %s).', feature, strjoin(T.Feature, ", "));
end
out = T.Here(row);
if opts.Require && ~out
    error(char(opts.ErrorId), '%s needs %s and is not available on %s. %s', ...
        T.Description(row), T.Uses(row), here, T.Alternative(row));
end
end


function T = matrix()
%matrix  The features that depend on the operating system.
rows = [
    "core", "Reading recordings, signals, spikes, sorting, exports, analysis and the apps", ...
        "MATLAB, and Python for sorting, probe design and NWB", "yes", "untested", "untested", ...
        "Nothing else in this table is needed for them."
    "copy", "Copying sessions (copySessions, the Copy tab)", ...
        "robocopy and a detached PowerShell copy engine", "yes", "no", "no", ...
        "Copy the session folders with the system's own tools (rsync, cp); the pipeline reads them where they are."
    "copySchedule", "A scheduled copy (CopySchedule)", ...
        "Windows Task Scheduler", "yes", "no", "no", ...
        "Schedule copies of your own with cron or launchd."
    "recycle", "Clean-up to the Recycle Bin (runLocalCleanup Method ""recycle"")", ...
        "the Recycle Bin and the registry", "yes", "no", "no", ...
        "Use Method ""delete"" or ""move""."
    "resourceMonitor", "The Run tab's resource monitor", ...
        "PowerShell performance counters and nvidia-smi", "yes", "no", "no", ...
        "Watch the system's own monitor (top, htop, nvidia-smi)."
    "backgroundSort", "Background Kilosort4 runs (Sorting.Execution ""background"")", ...
        "cmd start on Windows; a background sh on macOS and Linux", "yes", "untested", "untested", ...
        "Sorting.Execution ""blocking"" runs Kilosort4 in MATLAB's own process."
    "stopSort", "Stopping a sorting run (EphysDataset.stopSortRun)", ...
        "PowerShell and taskkill on Windows; pgrep and pkill on macOS and Linux", "yes", "untested", "untested", ...
        "End the Python process by hand."
    "openInSystem", "Opening a folder or file from the apps (openInSystem)", ...
        "winopen on Windows; open on macOS; xdg-open on Linux", "yes", "untested", "untested", ...
        "Open it from the file browser."
    "phy", "Launching phy from the Review tab", ...
        "phy.exe of the conda env ""phy"" on Windows; bin/phy on macOS and Linux", "yes", "untested", "untested", ...
        "Start phy from a terminal in the sort folder."
    ];
T = array2table(rows, 'VariableNames', {'Feature', 'Description', 'Uses', 'Windows', 'macOS', 'Linux', 'Alternative'});
end
