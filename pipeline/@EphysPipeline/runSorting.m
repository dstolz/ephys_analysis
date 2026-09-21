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
%   Background runs (Sorting.Execution "background") go at most
%   Sorting.MaxConcurrent at a time. The next dataset's run files (and
%   .bin) are written first, then its launch waits for a free slot. A slot
%   frees when a run finishes, fails or its process exits
%   (EphysDataset.sortRunState). Runs in PriorRuns take slots too. The step
%   returns once the last dataset has started. Each launch is appended to
%   LaunchedRuns and passed to LaunchFcn. SortingWaiting counts the datasets
%   still to start. Blocking runs go one at a time.
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
native = S.Engine == "kilosort";
if native
    runFcn = @(d, varargin) d.runKilosort(varargin{:});
    launchMsg = "writing the .bin, launching Kilosort4";
else
    runFcn = @(d, varargin) d.runSpikeInterface(varargin{:});
    launchMsg = "launching Kilosort4";
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
    launchOpts = {};
    if ~blocking
        launchOpts = {'BeforeLaunchFcn', @() waitForSlot(obj, S.MaxConcurrent, d.Name, k, n)};
    end
    try
        obj.progress("sorting", d.Name, k, n, 0, 2, "artifact intervals");
        iv = obj.artifactIntervalsForStep(d, c.Artifacts.ApplyToSorting, ...   % a detection fills the first half
            @(done, total, msg) obj.progress("sorting", d.Name, k, n, done / max(total, 1), 2, "artifact intervals, " + msg));
        obj.progress("sorting", d.Name, k, n, 1, 2, ternary(dry, "writing run files", launchMsg));
        res = runFcn(d, launchOpts{:}, ExtraSettings=ks4, ArtifactIntervals=iv, DryRun=dry, Wait=blocking);
        obj.SortingWaiting = nnz(why(k+1:end) == "");
        d.writeManifest();
        if dry
            obj.log("[sorting] %s: dry run, wrote %s", d.Name, res.settingsPath);
            obj.addResult("sorting", d.Name, "dry run", "wrote " + ternary(native, "settings.json", "si_config.json") + ...
                " + driver", res.settingsPath, toc(t0));
        elseif blocking
            if res.status == 0
                obj.log("[sorting] %s: done -> %s", d.Name, res.resultsDir);
                obj.addResult("sorting", d.Name, "done", "Kilosort4 finished", res.resultsDir, toc(t0));
            else
                obj.log("[sorting] %s: Kilosort4 exited with status %d", d.Name, res.status);
                obj.addResult("sorting", d.Name, "error", sprintf("exit status %d (see %s)", res.status, res.stdoutLog), ...
                    res.resultsDir, toc(t0));
            end
        else
            obj.log("[sorting] %s: launched in the background -> %s", d.Name, res.resultsDir);
            run = struct('Name', d.Name, ...
                'statusFile', string(res.statusFile), 'resultsDir', string(res.resultsDir), ...
                'logFile', string(res.stdoutLog), 'logPos', 0, 'done', false);
            obj.LaunchedRuns(end+1) = run;
            obj.addResult("sorting", d.Name, "launched", "background run; see LaunchedRuns", res.resultsDir, toc(t0));
            if ~isempty(obj.LaunchFcn)
                obj.LaunchFcn(run);
            end
        end
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


function waitForSlot(obj, maxRunning, name, k, n)
%waitForSlot  BeforeLaunchFcn of a background run: wait for one of the
%   MAXRUNNING slots, reporting the counts (a cancel ends the wait).
files = [obj.PriorRuns(:); reshape(string({obj.LaunchedRuns.statusFile}), [], 1)];
waitForSortingSlot(files, maxRunning, TickFcn=@(nRunning, nFinished) obj.progress("sorting", name, k, n, 1, 2, ...
    sprintf("waiting for a free Kilosort4 slot (%d at a time): %d running, %d finished, %d still to start", ...
    maxRunning, nRunning, nFinished, obj.SortingWaiting)));
end


function out = ternary(cond, a, b)
if cond; out = string(a); else; out = string(b); end
end
