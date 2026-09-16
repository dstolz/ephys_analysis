function runSignals(obj, opts)
%runSignals  Derived LFP / MUA / SPIKE .mat for each selected dataset (toMat).
%   The options come from EphysPipelineConfig.signalOptions (with the
%   dataset's manifest exclusions applied per Signals.ExcludeHandling); the
%   behavior data is attached when Signals.IncludeBehavior and the dataset
%   has an Epsych2 session. Output: <Signals.OutputDir or output folder>/
%   <Name><Suffix>.mat, skipped when it exists unless Signals.Overwrite.
%
%   Options: Datasets (indices), DryRun (log only).

arguments
    obj (1,1) EphysPipeline
    opts.Datasets (1,:) double = []
    opts.DryRun (1,1) logical = false
end

c = obj.Config;
G = c.Signals;
ds = obj.selected(opts.Datasets);
n = numel(ds);

for k = 1:n
    d = ds(k);
    if obj.CancelRequested
        obj.addResult("signals", d.Name, "cancelled", "not run");
        continue
    end
    t0 = tic;
    out = obj.outputPathFor("signals", d);
    if d.NumFiles == 0 || d.RecordingFormat == "unknown"
        obj.addResult("signals", d.Name, "skipped", "no recording files", out, toc(t0));
        continue
    end
    if isfile(out) && ~G.Overwrite
        obj.addResult("signals", d.Name, "skipped", "output exists (Overwrite is off)", out, toc(t0));
        continue
    end
    try
        sigOpts = EphysPipelineConfig.signalOptions(G, ExcludeChannels=d.ExcludeChannels, NumChannels=d.NumChannels);
        if opts.DryRun
            obj.log("[signals] %s: dry run -> %s (%s)", d.Name, out, strjoin(sigOpts.dataTypeOut, "+"));
            obj.addResult("signals", d.Name, "dry run", "would write " + strjoin(sigOpts.dataTypeOut, "+"), out, toc(t0));
            continue
        end
        behavior = [];
        if G.IncludeBehavior
            behavior = d.behaviorStruct();
        end
        cb = @(done, total, msg) obj.progress("signals", d.Name, k, n, done, total, msg);
        r = d.toMat(File=out, SignalOptions=sigOpts, MatVersion=G.MatVersion, ...
            Overwrite=G.Overwrite, ProgressFcn=cb, Behavior=behavior);
        obj.log("[signals] %s: wrote %s (%.1f MB, %.1f s)", d.Name, r.file, r.bytes / 2^20, r.seconds);
        obj.addResult("signals", d.Name, "done", strjoin(sigOpts.dataTypeOut, "+") + ...
            sprintf(", %.1f MB", r.bytes / 2^20), r.file, toc(t0));
    catch ME
        if strcmp(ME.identifier, 'EphysPipeline:Cancelled')
            obj.log("[signals] %s: cancelled (nothing written)", d.Name);
            obj.addResult("signals", d.Name, "cancelled", "cancelled; nothing written", out, toc(t0));
            continue
        end
        obj.log("[signals] %s: ERROR %s", d.Name, ME.message);
        obj.addResult("signals", d.Name, "error", string(ME.message), out, toc(t0));
    end
end
if obj.CancelRequested
    error('EphysPipeline:Cancelled', 'Cancelled by user.');
end
end
