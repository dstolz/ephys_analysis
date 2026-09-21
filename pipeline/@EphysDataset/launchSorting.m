function result = launchSorting(obj, result, opts)
%launchSorting  Start a Kilosort4 run that runKilosort / runSpikeInterface prepared.
%   RESULT = ds.launchSorting(RESULT) starts the run described by RESULT,
%   the struct ds.runKilosort(Launch=false) or
%   ds.runSpikeInterface(Launch=false) returned once every file of the run
%   (the .bin included) was written. Keeping the two apart lets a caller
%   write a run's files, then start it later: EphysPipeline.runSorting
%   waits for a free slot in between, and the app's monitor starts queued
%   runs as slots free. runKilosort / runSpikeInterface call this
%   themselves unless Launch=false.
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
%   (EphysDataset.sortRunState).
%
%   RESULT comes back with command (as run, --device included), status,
%   wait, background, device and launched (true) set.
%
%   See also EphysDataset.runKilosort, EphysDataset.runSpikeInterface,
%   EphysDataset.sortRunState, waitForSortingSlot.

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
if result.engine == "kilosort"
    what = "Kilosort4";
    title = 'Kilosort4';
else
    what = "SpikeInterface + Kilosort4";
    title = 'SpikeInterface-KS4';
end

% Clear any stale status / exit marker so they reflect this run only.
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
    bgCommand = backgroundCommand(command, result.stdoutLog, exitFile, title);
    fprintf('Launching %s (background):\n  %s\n', what, bgCommand);
    status = system(bgCommand);   % returns immediately
    if status ~= 0
        warning('EphysDataset:launchSorting:LaunchFailed', ...
            'Background launch returned status %d. See log: %s', status, result.stdoutLog);
    end
end

result.command    = command;
result.status     = status;
result.wait       = opts.Wait;
result.background = ~opts.Wait;
result.device     = opts.Device;
result.launched   = true;

if ~isempty(obj.Manifest) && isa(obj.Manifest, 'Manifest')
    obj.Manifest.add("launchSorting", "Spawned " + what, ...
        struct('command', command, 'status', status, 'wait', opts.Wait, ...
        'device', opts.Device, 'resultsDir', result.resultsDir));
end
end
