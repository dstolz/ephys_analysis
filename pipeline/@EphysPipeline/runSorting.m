function runSorting(obj, opts)
%runSorting  Kilosort4 for each selected dataset.
%   EphysDataset.runKilosort writes the recording to a .bin and Kilosort4
%   runs on it, with the config's typed Kilosort4 settings
%   (EphysPipelineConfig.ks4Settings), the dataset's probe (probeFor: its
%   own, else Probe.DefaultProbeFile) and the artifact intervals (manual
%   periods always; the cached automatic detection when
%   Artifacts.ApplyToSorting) blanked in the .bin. The manifest is rewritten
%   after each launch / completion.
%
%   Each dataset's run files and .bin are written first (Launch=false), then
%   the run starts
%   (EphysDataset.launchSorting):
%     blocking    (Sorting.Execution) at once; the step waits for each run
%                 to finish, so they go one at a time.
%     background  at most Sorting.MaxConcurrent at a time: the launch waits
%                 for a free slot. A slot frees when a run finishes, fails
%                 or its process exits (EphysDataset.sortRunState). Runs in
%                 PriorRuns take slots too (queued ones do not). The step
%                 returns once the last dataset has started. Each launch is
%                 appended to LaunchedRuns and passed to LaunchFcn.
%                 SortingWaiting counts the datasets still to start.
%     queued      background with QueueFcn set: nothing starts here. Each
%                 prepared run goes to QueueFcn(d, res) and its row says
%                 "queued"; the owner of QueueFcn starts it with
%                 d.launchSorting(res, Wait=false, Device=...) when a slot
%                 frees. The step returns once the last dataset's files are
%                 written.
%   Sorting.Devices shares torch devices out: a background run gets the one
%   the fewest running runs use (sortingSlot), a blocking run the first.
%
%   Skipped ("skipped" rows): a dataset without recording files, one with a
%   Kilosort4 run queued or still going (activeRun: PriorRuns or
%   LaunchedRuns), so its .bin is never rewritten under a running sort,
%   one without a probe or whose probe file is not there, and with
%   Sorting.SkipExisting one already sorted (also when its hand-picked
%   sorted-output folder is not there now). A cancel stops the datasets not
%   started yet; a run already launched, queued or finished carries on and
%   keeps its row.
%
%   Options: Datasets (indices), DryRun (write settings.json + the driver
%   only; no .bin, so no artifact detection).

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
dry = opts.DryRun || logical(S.DryRun);   % the config's DryRun applies to direct calls too
ds = obj.selected(opts.Datasets);
n = numel(ds);

% Decide the skips up front, so a background step can say how many
% datasets are still waiting to start.
why = strings(1, n);
whyOut = strings(1, n);
for k = 1:n
    [why(k), whyOut(k)] = skipReason(obj, ds(k), S);
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
        if dry
            iv = [];   % a dry run writes no .bin: nothing to blank, so nothing to detect
        else
            obj.progress("sorting", d.Name, k, n, 0, 2, "artifact intervals");
            iv = obj.artifactIntervalsForStep(d, c.Artifacts.ApplyToSorting, ...   % a detection fills the first half
                @(done, total, msg) obj.progress("sorting", d.Name, k, n, done / max(total, 1), 2, "artifact intervals, " + msg));
        end
        obj.progress("sorting", d.Name, k, n, 1, 2, ternary(dry, "writing run files", "writing the .bin and run files"));
        res = d.runKilosort(ProbeFile=obj.probeFor(d), ExtraSettings=ks4, ArtifactIntervals=iv, ...
            DryRun=dry, Launch=false);
        if dry
            obj.log("[sorting] %s: dry run, wrote %s", d.Name, res.settingsPath);
            obj.addResult("sorting", d.Name, "dry run", "wrote settings.json + driver", res.settingsPath, toc(t0));
        elseif blocking
            device = "";
            if ~isempty(S.Devices); device = S.Devices(1); end
            obj.progress("sorting", d.Name, k, n, 1, 2, "running Kilosort4" + onDevice(device));
            res = d.launchSorting(res, Wait=true, Device=device);
            if res.status == 0
                obj.log("[sorting] %s: done -> %s%s", d.Name, res.resultsDir, asideNote(res));
                obj.addResult("sorting", d.Name, "done", "Kilosort4 finished" + asideNote(res), res.resultsDir, toc(t0));
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
            obj.log("[sorting] %s: launched in the background%s -> %s%s", d.Name, onDevice(device), ...
                res.resultsDir, asideNote(res));
            run = EphysPipeline.sortRun(d.Name, res);
            obj.LaunchedRuns(end+1) = run;
            obj.addResult("sorting", d.Name, "launched", "background run" + onDevice(device) + asideNote(res), ...
                res.resultsDir, toc(t0));
            if ~isempty(obj.LaunchFcn)
                obj.LaunchFcn(run);
            end
        end
        obj.SortingWaiting = nnz(why(k+1:end) == "");
        d.writeManifest();
        try
            obj.progress("sorting", d.Name, k, n, 2, 2, "done");
        catch
            % The run has started (or finished, or is queued) and carries on:
            % its row stands. A cancel raised here stops the datasets still
            % to start (CancelRequested).
        end
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


function [why, out] = skipReason(obj, d, S)
%skipReason  Why dataset D is not sorted ("" = it is) and the output to show.
why = "";
out = "";
probe = obj.probeFor(d);
run = obj.activeRun(d);
if d.NumFiles == 0 || d.RecordingFormat == "unknown"
    why = "no recording files";
elseif ~isempty(run)
    why = "Kilosort4 is already " + ternary(run.queued, "queued", "running") + " for this dataset";
    out = run.resultsDir;
elseif probe == ""
    why = "no probe";
elseif ~isfile(probe)
    why = "probe file missing";
    out = probe;
elseif S.SkipExisting && d.hasKilosortResults()
    why = "sorted output exists (SkipExisting)";
    out = string(d.sortingResultsDir());
elseif S.SkipExisting && d.sortingMissing()
    why = "sorted output recorded (SkipExisting), its folder is not there now";
    out = d.SortingDir;
end
end


function device = waitForSlot(obj, S, name, k, n)
%waitForSlot  Wait for one of the Sorting.MaxConcurrent slots, reporting the
%   counts (a cancel ends the wait); the device the run is to use. Queued
%   runs in PriorRuns are not going, so they take no slot.
runs = [obj.PriorRuns(:); obj.LaunchedRuns(:)];
runs = runs(~[runs.queued]);
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


function t = asideNote(res)
%asideNote  "; the earlier sort's curation moved to <folder>" when launchSorting
%   set it aside (res.previousDir), else "".
t = "";
if isfield(res, 'previousDir') && res.previousDir ~= ""
    t = "; the earlier sort's curation moved to " + res.previousDir;
end
end


function out = ternary(cond, a, b)
if cond; out = string(a); else; out = string(b); end
end
