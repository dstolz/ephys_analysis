function runSorting(obj, opts)
%runSorting  Kilosort4 for each selected dataset.
%   Sorting.Engine picks the route:
%     "spikeinterface"  EphysDataset.runSpikeInterface: SpikeInterface loads
%                       the recording, applies its preprocessing (already
%                       pushed onto each dataset) and runs Kilosort4.
%     "kilosort"        EphysDataset.runKilosort: the recording is written to
%                       a .bin and Kilosort4 runs natively on it.
%   Both get the config's typed Kilosort4 settings
%   (EphysPipelineConfig.ks4Settings) and the artifact intervals (manual
%   periods always; the cached automatic detection when
%   Artifacts.ApplyToSorting), silenced by SpikeInterface or blanked in the
%   .bin. The manifest is rewritten after each launch / completion.
%
%   Each dataset's run files (and the .bin for the native engine) are
%   written first (Launch=false), then the run starts
%   (EphysDataset.launchSorting):
%     blocking    (Sorting.Execution) at once; the step waits for each run
%                 to finish, so they go one at a time.
%     background  at most Sorting.MaxConcurrent at a time: the launch waits
%                 for a free slot. A slot frees when a run finishes, fails
%                 or its process exits (EphysDataset.sortRunState). Runs in
%                 PriorRuns take slots too. The step returns once the last
%                 dataset has started. Each launch is appended to
%                 LaunchedRuns and passed to LaunchFcn. SortingWaiting
%                 counts the datasets still to start.
%     queued      background with QueueFcn set: nothing starts here. Each
%                 prepared run goes to QueueFcn(d, res) and its row says
%                 "queued"; the owner of QueueFcn starts it with
%                 d.launchSorting(res, Wait=false, Device=...) when a slot
%                 frees. The step returns once the last dataset's files are
%                 written.
%   Sorting.Devices shares torch devices out: a background run gets the one
%   the fewest running runs use (sortingSlot), a blocking run the first.
%
%   Options: Datasets (indices), DryRun (write si_config.json + the driver
%   only).

arguments
    obj (1,1) EphysPipeline
    opts.Datasets (1,:) double = []
    opts.DryRun (1,1) logical = false
end

c = obj.Config;
S = c.Sorting;
[ks4, msg] = EphysPipelineConfig.ks4Settings(S);
if msg ~= ""
    error('EphysPipeline:KS4Settings', '%s', msg);
end
blocking = S.Execution == "blocking";
queued = ~blocking && ~isempty(obj.QueueFcn);
native = S.Engine == "kilosort";
if native
    runFcn = @(d, varargin) d.runKilosort(varargin{:});
    writeMsg = "writing the .bin and run files";
else
    runFcn = @(d, varargin) d.runSpikeInterface(varargin{:});
    writeMsg = "writing the run files";
end
dry = opts.DryRun || logical(S.DryRun);   % the config's DryRun applies to direct calls too
ds = obj.selected(opts.Datasets);
n = numel(ds);

% Decide the skips up front, so a background step can say how many
% datasets are still waiting to start.
why = strings(1, n);
whyOut = strings(1, n);
for k = 1:n
    [why(k), whyOut(k)] = skipReason(ds(k), S);
end
obj.SortingWaiting = nnz(why == "");

for k = 1:n
    d = ds(k);
    if obj.CancelRequested
        obj.addResult("sorting", d.Name, "cancelled", "not run");
        continue
    end
    t0 = tic;
    if why(k) ~= ""
        obj.addResult("sorting", d.Name, "skipped", why(k), whyOut(k), toc(t0));
        continue
    end
    try
        obj.progress("sorting", d.Name, k, n, 0, 2, "artifact intervals");
        iv = obj.artifactIntervalsForStep(d, c.Artifacts.ApplyToSorting, ...   % a detection fills the first half
            @(done, total, msg) obj.progress("sorting", d.Name, k, n, done / max(total, 1), 2, "artifact intervals, " + msg));
        obj.progress("sorting", d.Name, k, n, 1, 2, ternary(dry, "writing run files", writeMsg));
        res = runFcn(d, ExtraSettings=ks4, ArtifactIntervals=iv, DryRun=dry, Launch=false);
        if dry
            obj.log("[sorting] %s: dry run, wrote %s", d.Name, res.settingsPath);
            obj.addResult("sorting", d.Name, "dry run", "wrote " + ternary(native, "settings.json", "si_config.json") + ...
                " + driver", res.settingsPath, toc(t0));
        elseif blocking
            device = "";
            if ~isempty(S.Devices); device = S.Devices(1); end
            obj.progress("sorting", d.Name, k, n, 1, 2, "running Kilosort4" + onDevice(device));
            res = d.launchSorting(res, Wait=true, Device=device);
            if res.status == 0
                obj.log("[sorting] %s: done -> %s", d.Name, res.resultsDir);
                obj.addResult("sorting", d.Name, "done", "Kilosort4 finished", res.resultsDir, toc(t0));
            else
                obj.log("[sorting] %s: Kilosort4 exited with status %d", d.Name, res.status);
                obj.addResult("sorting", d.Name, "error", sprintf("exit status %d (see %s)", res.status, res.stdoutLog), ...
                    res.resultsDir, toc(t0));
            end
        elseif queued
            obj.QueueFcn(d, res);
            obj.log("[sorting] %s: queued, starts when a Kilosort4 slot is free -> %s", d.Name, res.resultsDir);
            obj.addResult("sorting", d.Name, "queued", "waiting for a free Kilosort4 slot", res.resultsDir, toc(t0));
        else
            device = waitForSlot(obj, S, d.Name, k, n);
            obj.progress("sorting", d.Name, k, n, 1, 2, "launching Kilosort4" + onDevice(device));
            res = d.launchSorting(res, Wait=false, Device=device);
            obj.log("[sorting] %s: launched in the background%s -> %s", d.Name, onDevice(device), res.resultsDir);
            run = EphysPipeline.sortRun(d.Name, res);
            obj.LaunchedRuns(end+1) = run;
            obj.addResult("sorting", d.Name, "launched", "background run" + onDevice(device), res.resultsDir, toc(t0));
            if ~isempty(obj.LaunchFcn)
                obj.LaunchFcn(run);
            end
        end
        obj.SortingWaiting = nnz(why(k+1:end) == "");
        d.writeManifest();
        obj.progress("sorting", d.Name, k, n, 2, 2, "done");
    catch ME
        obj.SortingWaiting = nnz(why(k+1:end) == "");   % whether or not it launched
        if strcmp(ME.identifier, 'EphysPipeline:Cancelled')
            obj.addResult("sorting", d.Name, "cancelled", "cancelled before launch", "", toc(t0));
            continue
        end
        obj.log("[sorting] %s: ERROR %s", d.Name, ME.message);
        obj.addResult("sorting", d.Name, "error", string(ME.message), "", toc(t0));
    end
end
obj.SortingWaiting = 0;
if obj.CancelRequested
    error('EphysPipeline:Cancelled', 'Cancelled by user.');
end
end


function [why, out] = skipReason(d, S)
%skipReason  Why dataset D is not sorted ("" = it is) and the output to show.
why = "";
out = "";
if d.NumFiles == 0 || d.RecordingFormat == "unknown"
    why = "no recording files";
elseif d.ProbeFile == ""
    why = "no probe";
elseif S.SkipExisting && d.hasKilosortResults()
    why = "sorted output exists (SkipExisting)";
    out = string(d.sortingResultsDir());
end
end


function device = waitForSlot(obj, S, name, k, n)
%waitForSlot  Wait for one of the Sorting.MaxConcurrent slots, reporting the
%   counts (a cancel ends the wait); the device the run is to use.
runs = [obj.PriorRuns(:); obj.LaunchedRuns(:)];
device = waitForSortingSlot(runs, S.MaxConcurrent, Devices=S.Devices, ...
    TickFcn=@(nRunning, nFinished) obj.progress("sorting", name, k, n, 1, 2, ...
    sprintf("waiting for a free Kilosort4 slot (%d at a time): %d running, %d finished, %d still to start", ...
    S.MaxConcurrent, nRunning, nFinished, obj.SortingWaiting)));
end


function t = onDevice(device)
%onDevice  " on cuda:1", or "" without a device.
t = "";
if device ~= ""; t = " on " + device; end
end


function out = ternary(cond, a, b)
if cond; out = string(a); else; out = string(b); end
end
