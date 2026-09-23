function runSignals(obj, opts)
%runSignals  Derived LFP / MUA / SPIKE / AUX .mat for each selected dataset (toMat).
%   The options come from EphysPipelineConfig.signalOptions (with the
%   dataset's manifest exclusions applied per Signals.ExcludeHandling).
%   Behavior data is written by the behavior step, not here. The common
%   reference of Artifacts.Reference (CAR / CMR; the datasets'
%   ArtifactConfig) is subtracted, once, from the signals whose
%   Signals.<TYPE>_Reference is on (MUA and SPIKE by default, not the LFP;
%   see deriveSignals' referenceSignals). With
%   Signals.BlankArtifacts the dataset's artifact periods (the manual ones,
%   plus the automatic detection when Artifacts.ApplyToSignals, as Sorting
%   and Spikes take them: artifactIntervalsForStep) are erased before any
%   signal is derived and recorded in every file (info.artifacts). Output:
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
            what = "would write " + strjoin(sigOpts.dataTypeOut, "+");
            if c.Artifacts.Reference ~= "none" && ~isempty(sigOpts.referenceSignals)
                what = what + ", " + strjoin(sigOpts.referenceSignals, "+") + " " + upper(c.Artifacts.Reference) + " referenced";
            end
            if G.BlankArtifacts
                what = what + ", artifact periods erased (" + ...
                    ternary(c.Artifacts.ApplyToSignals && c.Artifacts.Enabled, "manual + automatic", "manual") + ")";
            end
            obj.log("[signals] %s: dry run -> %s (%s)", d.Name, strjoin(out, ", "), what);
            addRows("dry run", what);
            continue
        end
        lo = 0;   % share of this dataset's progress an artifact detection took
        if G.BlankArtifacts
            obj.progress("signals", d.Name, k, n, 0, 1, "artifact intervals");
            [iv, src] = obj.artifactIntervalsForStep(d, c.Artifacts.ApplyToSignals, ...   % a detection fills the first half
                @(done, total, msg) obj.progress("signals", d.Name, k, n, done / max(total, 1) / 2, 1, "artifact intervals, " + msg));
            if src == "computed"; lo = 0.5; end
            sigOpts.artifactIntervals = iv;
        end
        cb = @(done, total, msg) obj.progress("signals", d.Name, k, n, lo + (1 - lo) * done / max(total, 1), 1, msg);
        r = d.toMat(File=obj.outputPathFor("signals:base", d), SeparateFiles=G.SeparateFiles, ...
            SignalOptions=sigOpts, MatVersion=G.MatVersion, ...
            Overwrite=G.Overwrite, ProgressFcn=cb);
        if any(sigOpts.dataTypeOut == "AUX") && ~any(contains(r.types, "AUX"))
            obj.log("[signals] %s: no aux (accelerometer) inputs recorded; AUX not written", d.Name);
        end
        if r.reference.mode ~= "none"
            obj.log("[signals] %s: common %s reference over %d channel(s), subtracted from %s", d.Name, ...
                upper(r.reference.mode), numel(r.reference.channels), strjoin(r.reference.signals, ", "));
        end
        erased = "";
        if G.BlankArtifacts
            nIv = size(r.artifacts.intervals, 1);
            obj.log("[signals] %s: %d artifact period(s) erased before deriving (%s, %d samples)", ...
                d.Name, nIv, src, r.artifacts.nSamples);
            erased = sprintf(", %d artifact period(s) erased", nIv);
        end
        for j = 1:numel(r.file)
            what = r.types(min(j, numel(r.types)));
            obj.log("[signals] %s: wrote %s (%.1f MB, %.1f s)", d.Name, r.file(j), r.bytes(j) / 2^20, r.seconds);
            obj.addResult("signals", d.Name, "done", what + sprintf(", %.1f MB", r.bytes(j) / 2^20) + erased, ...
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


function out = ternary(cond, a, b)
if cond; out = a; else; out = b; end
end
