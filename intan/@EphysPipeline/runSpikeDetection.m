function runSpikeDetection(obj, opts)
%runSpikeDetection  Detected and/or sorted spikes .mat per dataset (spikesToMat).
%   Detection options come from EphysPipelineConfig.detectOptions, the
%   channels from Spikes.Channels (all / manifest exclusions removed / list),
%   artifact rejection from the manual periods plus the cached automatic
%   detection when Artifacts.ApplyToSpikes. Sorted units are read through
%   the dataset's sorting association. Output: <Spikes.OutputDir or output
%   folder>/<Name><Suffix>.mat.
%
%   Options: Datasets (indices), DryRun (log only).

arguments
    obj (1,1) EphysPipeline
    opts.Datasets (1,:) double = []
    opts.DryRun (1,1) logical = false
end

c = obj.Config;
K = c.Spikes;
dopt = EphysPipelineConfig.detectOptions(K);
ds = obj.selected(opts.Datasets);
n = numel(ds);

for k = 1:n
    d = ds(k);
    if obj.CancelRequested
        obj.addResult("spikes", d.Name, "cancelled", "not run");
        continue
    end
    t0 = tic;
    out = obj.outputPathFor("spikes", d);
    if d.NumFiles == 0 || d.RecordingFormat == "unknown"
        obj.addResult("spikes", d.Name, "skipped", "no recording files", out, toc(t0));
        continue
    end
    if K.Source ~= "detect" && ~d.hasKilosortResults()
        obj.addResult("spikes", d.Name, "skipped", "no sorting output for Source=" + K.Source, out, toc(t0));
        continue
    end
    if isfile(out) && ~K.Overwrite
        obj.addResult("spikes", d.Name, "skipped", "output exists (Overwrite is off)", out, toc(t0));
        continue
    end
    try
        channels = EphysPipelineConfig.spikeChannels(K, d);
        if opts.DryRun
            obj.log("[spikes] %s: dry run -> %s (%s)", d.Name, out, K.Source);
            obj.addResult("spikes", d.Name, "dry run", "would write source=" + K.Source, out, toc(t0));
            continue
        end
        args = {};
        if K.Source ~= "sorted" && K.RejectArtifacts
            obj.progress("spikes", d.Name, k, n, 0, 1, "artifact intervals");
            iv = obj.artifactIntervalsForStep(d, c.Artifacts.ApplyToSpikes);
            args = {'ArtifactIntervals', iv};
        end
        cb = @(done, total, msg) obj.progress("spikes", d.Name, k, n, done, total, msg);
        r = d.spikesToMat('File', out, 'Source', K.Source, 'DetectOptions', dopt, 'Channels', channels, ...
            'RejectArtifacts', K.RejectArtifacts, 'Groups', K.Groups, 'IncludeNoise', K.IncludeNoise, ...
            'Templates', K.Templates, 'MatVersion', K.MatVersion, ...
            'Overwrite', K.Overwrite, 'ProgressFcn', cb, args{:});
        msg = sprintf("%s: %d unit(s), %d detected event(s), %d rejected", K.Source, r.nUnits, ...
            sum(r.nDetected), sum(r.nRejectedArtifact));
        obj.log("[spikes] %s: wrote %s (%s)", d.Name, r.file, msg);
        obj.addResult("spikes", d.Name, "done", msg, r.file, toc(t0));
    catch ME
        if strcmp(ME.identifier, 'EphysPipeline:Cancelled')
            obj.log("[spikes] %s: cancelled (nothing written)", d.Name);
            obj.addResult("spikes", d.Name, "cancelled", "cancelled; nothing written", out, toc(t0));
            continue
        end
        obj.log("[spikes] %s: ERROR %s", d.Name, ME.message);
        obj.addResult("spikes", d.Name, "error", string(ME.message), out, toc(t0));
    end
end
if obj.CancelRequested
    error('EphysPipeline:Cancelled', 'Cancelled by user.');
end
end
