function runSignals(obj, opts)
%runSignals  Derived LFP / MUA / SPIKE / AUX .mat for each selected dataset (toMat).
%   The options come from EphysPipelineConfig.signalOptions (with the
%   dataset's manifest exclusions applied per Signals.ExcludeHandling).
%   Behavior data is written by the behavior step, not here. Output:
%   <Signals.OutputDir or output folder>/
%   <Name><Suffix>.mat, or <Name><Suffix>_<TYPE>.mat per signal type when
%   Signals.SeparateFiles, skipped when any exists unless Signals.Overwrite.
%   One result row per output file.
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
        addRows("skipped", "no recording files");
        continue
    end
    if any(isfile(out)) && ~G.Overwrite
        addRows("skipped", "output exists (Overwrite is off)");
        continue
    end
    try
        sigOpts = EphysPipelineConfig.signalOptions(G, ExcludeChannels=d.ExcludeChannels, NumChannels=d.NumChannels);
        if isfield(sigOpts, 'badChannels')
            sigOpts.probeFile = obj.probeFor(d);   % the geometry for them: its own probe, else the default
        end
        if opts.DryRun
            obj.log("[signals] %s: dry run -> %s (%s)", d.Name, strjoin(out, ", "), strjoin(sigOpts.dataTypeOut, "+"));
            addRows("dry run", "would write " + strjoin(sigOpts.dataTypeOut, "+"));
            continue
        end
        cb = @(done, total, msg) obj.progress("signals", d.Name, k, n, done, total, msg);
        r = d.toMat(File=obj.outputPathFor("signals:base", d), SeparateFiles=G.SeparateFiles, ...
            SignalOptions=sigOpts, MatVersion=G.MatVersion, ...
            Overwrite=G.Overwrite, ProgressFcn=cb);
        if any(sigOpts.dataTypeOut == "AUX") && ~any(contains(r.types, "AUX"))
            obj.log("[signals] %s: no aux (accelerometer) inputs recorded; AUX not written", d.Name);
        end
        for j = 1:numel(r.file)
            what = r.types(min(j, numel(r.types)));
            obj.log("[signals] %s: wrote %s (%.1f MB, %.1f s)", d.Name, r.file(j), r.bytes(j) / 2^20, r.seconds);
            obj.addResult("signals", d.Name, "done", what + sprintf(", %.1f MB", r.bytes(j) / 2^20), ...
                r.file(j), toc(t0));
        end
    catch ME
        if strcmp(ME.identifier, 'EphysPipeline:Cancelled')
            obj.log("[signals] %s: cancelled (nothing written)", d.Name);
            addRows("cancelled", "cancelled; nothing written");
            continue
        end
        obj.log("[signals] %s: ERROR %s", d.Name, ME.message);
        addRows("error", string(ME.message));
    end
end
if obj.CancelRequested
    error('EphysPipeline:Cancelled', 'Cancelled by user.');
end

    function addRows(status, message)
        % One result row per output file of the current dataset.
        for jj = 1:numel(out)
            obj.addResult("signals", d.Name, status, message, out(jj), toc(t0));
        end
    end
end
