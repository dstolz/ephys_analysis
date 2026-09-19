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
%   .bin. Background runs are appended to LaunchedRuns and the manifest is
%   rewritten after each launch / completion.
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

for k = 1:n
    d = ds(k);
    if obj.CancelRequested
        obj.addResult("sorting", d.Name, "cancelled", "not run");
        continue
    end
    t0 = tic;
    if d.NumFiles == 0 || d.RecordingFormat == "unknown"
        obj.addResult("sorting", d.Name, "skipped", "no recording files", "", toc(t0));
        continue
    end
    if d.ProbeFile == ""
        obj.addResult("sorting", d.Name, "skipped", "no probe", "", toc(t0));
        continue
    end
    if S.SkipExisting && d.hasKilosortResults()
        obj.addResult("sorting", d.Name, "skipped", "sorted output exists (SkipExisting)", ...
            string(d.sortingResultsDir()), toc(t0));
        continue
    end
    try
        obj.progress("sorting", d.Name, k, n, 0, 2, "artifact intervals");
        iv = obj.artifactIntervalsForStep(d, c.Artifacts.ApplyToSorting, ...   % a detection fills the first half
            @(done, total, msg) obj.progress("sorting", d.Name, k, n, done / max(total, 1), 2, "artifact intervals, " + msg));
        obj.progress("sorting", d.Name, k, n, 1, 2, ternary(dry, "writing run files", launchMsg));
        res = runFcn(d, ExtraSettings=ks4, ArtifactIntervals=iv, DryRun=dry, Wait=blocking);
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
            obj.LaunchedRuns(end+1) = struct('Name', d.Name, ...
                'statusFile', string(res.statusFile), 'resultsDir', string(res.resultsDir), ...
                'logFile', string(res.stdoutLog), 'logPos', 0, 'done', false);
            obj.addResult("sorting", d.Name, "launched", "background run; see LaunchedRuns", res.resultsDir, toc(t0));
        end
        obj.progress("sorting", d.Name, k, n, 2, 2, "done");
    catch ME
        if strcmp(ME.identifier, 'EphysPipeline:Cancelled')
            obj.addResult("sorting", d.Name, "cancelled", "cancelled before launch", "", toc(t0));
            continue
        end
        obj.log("[sorting] %s: ERROR %s", d.Name, ME.message);
        obj.addResult("sorting", d.Name, "error", string(ME.message), "", toc(t0));
    end
end
if obj.CancelRequested
    error('EphysPipeline:Cancelled', 'Cancelled by user.');
end
end


function out = ternary(cond, a, b)
if cond; out = string(a); else; out = string(b); end
end
