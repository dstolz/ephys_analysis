function result = launchSorting(obj, result, opts)
%launchSorting  Start a Kilosort4 run that runKilosort prepared.
%   RESULT = ds.launchSorting(RESULT) starts the run described by RESULT,
%   the struct ds.runKilosort(Launch=false) returned once every file of the
%   run (the .bin included) was written. Keeping the two apart lets a caller
%   write a run's files, then start it later: EphysPipeline.runSorting
%   waits for a free slot in between, and the app's monitor starts queued
%   runs as slots free. runKilosort calls this itself unless
%   Launch=false.
%
%   Options
%     Wait    (1,1) logical  block until Kilosort4 finishes (default true).
%             When false, the process is launched detached with
%             stdout/stderr redirected to RESULT.stdoutLog, and the call
%             returns at once; RESULT.status is then the launcher's status,
%             not Kilosort4's exit code.
%     Device  (1,1) string  torch device for this run ("cuda:0", "cuda:1",
%             "cpu"; see EphysDataset.isTorchDevice), passed to the driver
%             as --device. It overrides a torch_device in the run's
%             settings. "" (default) leaves the device to those settings or
%             to Kilosort4 (the first GPU when there is one).
%
%   The run folder's ks4_status.json and exit marker are deleted first, so
%   they reflect this run only. A background run leaves an empty
%   EphysDataset.SortExitMarker beside its status once its process exits
%   (EphysDataset.sortRunState). On Windows it is started through a batch
%   file written to the run folder, ks4_launch.cmd, so that paths with & or
%   ^ in them survive; a launcher that does not start writes the exit marker
%   and throws EphysDataset:launchSorting:LaunchFailed.
%
%   Kilosort4 overwrites its own output in the results folder but not the
%   curation of an earlier sort there, and its cluster ids start again at
%   0, so that sort's notes and phy labels would land on unrelated units.
%   They are moved first into <results folder>\previous_<yyyyMMdd_HHmmss>
%   (never deleted): cluster_notes.tsv, phy's cluster_group.tsv (header
%   "cluster_id<TAB>group"; Kilosort4's own copy of cluster_KSLabel.tsv
%   stays), cluster_info.tsv, any other cluster_*.tsv but Kilosort4's
%   cluster_KSLabel / ContamPct / Amplitude, and phy's .phy cache. Phy's
%   merges and splits live in spike_clusters.npy, which the new sort
%   replaces. When a file cannot be moved (phy has the folder open), the
%   ones already moved go back and EphysDataset:launchSorting:SetAsideFailed
%   is thrown before anything starts.
%
%   RESULT comes back with command (as run, --device included), status,
%   wait, background, device, launched (true) and previousDir (the
%   previous_* folder, "" when there was nothing to move) set.
%
%   See also EphysDataset.runKilosort, EphysDataset.sortRunState, waitForSortingSlot.

arguments
    obj (1,1) EphysDataset
    result (1,1) struct
    opts.Wait (1,1) logical = true
    opts.Device (1,1) string = ""
end

if result.dryRun
    error('EphysDataset:launchSorting:DryRun', 'A dry run cannot be launched (%s).', result.resultsDir);
end
if opts.Device ~= "" && ~EphysDataset.isTorchDevice(opts.Device)
    error('EphysDataset:launchSorting:BadDevice', ...
        'Device "%s" is not a torch device (cpu, mps, cuda or cuda:N).', opts.Device);
end

statusFile = char(result.statusFile);
exitFile   = fullfile(fileparts(statusFile), char(EphysDataset.SortExitMarker));
command    = char(result.driverCommand);
if opts.Device ~= ""
    command = sprintf('%s --device %s', command, opts.Device);
end
what = "Kilosort4";
title = 'Kilosort4';

% The earlier sort's curation goes aside, then any stale status / exit
% marker, so they reflect this run only.
previousDir = setAsideCuration(result.resultsDir);
if isfile(statusFile)
    delete(statusFile);
end
if isfile(exitFile)
    delete(exitFile);
end

if opts.Wait
    fprintf('Launching %s (blocking):\n  %s\n', what, command);
    [status, out] = system(command);
    fid = fopen(result.stdoutLog, 'w');   % tee the output to the log
    if fid >= 0
        fwrite(fid, out, 'char');
        fclose(fid);
    end
    if status ~= 0
        warning('EphysDataset:launchSorting:NonZeroExit', ...
            '%s exited with status %d. See log: %s', what, status, result.stdoutLog);
    end
else
    launcher = fullfile(result.runDir, 'ks4_launch.cmd');
    bgCommand = backgroundCommand(command, result.stdoutLog, exitFile, launcher, title);
    fprintf('Launching %s (background):\n  %s\n', what, bgCommand);
    status = system(bgCommand);   % returns immediately
    if status ~= 0
        fclose(fopen(exitFile, 'w'));   % nothing runs: sortRunState reports an error, the slot is free
        error('EphysDataset:launchSorting:LaunchFailed', ...
            'The background launch of %s returned status %d: %s', what, status, bgCommand);
    end
end

result.command    = command;
result.status     = status;
result.wait       = opts.Wait;
result.background = ~opts.Wait;
result.device     = opts.Device;
result.launched   = true;
result.previousDir = previousDir;

if ~isempty(obj.Manifest) && isa(obj.Manifest, 'Manifest')
    obj.Manifest.add("launchSorting", "Spawned " + what, ...
        struct('command', command, 'status', status, 'wait', opts.Wait, ...
        'device', opts.Device, 'resultsDir', result.resultsDir, 'previousDir', previousDir));
end
end


function previous = setAsideCuration(resultsDir)
%setAsideCuration  Move an earlier sort's curation out of RESULTSDIR.
%   Returns the previous_<yyyyMMdd_HHmmss> folder the files went to, ""
%   when there was nothing to move. See launchSorting's help for the files.
ksOwn = ["cluster_KSLabel.tsv" "cluster_ContamPct.tsv" "cluster_Amplitude.tsv"];
D = dir(fullfile(resultsDir, 'cluster_*.tsv'));
names = string({D(~[D.isdir]).name});
names = names(~ismember(lower(names), lower(ksOwn)));
group = strcmpi(names, "cluster_group.tsv");
if any(group) && ~EphysDataset.phyCurated(resultsDir)
    names(group) = [];                            % Kilosort4's copy of cluster_KSLabel.tsv
end
if isfolder(fullfile(resultsDir, '.phy'))
    names(end+1) = ".phy";
end
previous = "";
if isempty(names); return; end
stamp = "previous_" + string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
previous = string(fullfile(resultsDir, stamp));
n = 1;
while isfolder(previous) || isfile(previous)   % a second new sort within the same second
    n = n + 1;
    previous = string(fullfile(resultsDir, stamp + "_" + n));
end
mkdir(previous);
for k = 1:numel(names)
    [ok, msg] = movefile(fullfile(resultsDir, names(k)), fullfile(previous, names(k)));
    if ~ok
        for j = 1:k - 1                           % put them back: a retry starts over
            movefile(fullfile(previous, names(j)), fullfile(resultsDir, names(j)));
        end
        [~, ~] = rmdir(previous);
        error('EphysDataset:launchSorting:SetAsideFailed', ...
            ['Could not move %s of the earlier sort out of the way of the new one (%s). ' ...
             'Close phy if it has %s open.'], names(k), msg, resultsDir);
    end
end
fprintf('Moved the earlier sort''s curation (%s) to %s\n', strjoin(names, ", "), previous);
end
