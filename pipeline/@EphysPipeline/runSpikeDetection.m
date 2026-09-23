function runSpikeDetection(obj, opts)
%runSpikeDetection  Detected and/or sorted spikes .mat per dataset (spikesToMat).
%   Detection options come from EphysPipelineConfig.detectOptions, the
%   channels from Spikes.Channels (all / manifest exclusions removed / list),
%   the artifact periods (Spikes.ArtifactMode "reject": the events inside
%   them dropped; "erase": erased before detection) from the manual periods
%   plus the cached automatic detection when Artifacts.ApplyToSpikes. Sorted units are read through
%   the dataset's sorting association; a dataset whose hand-picked
%   sorted-output folder is not there is skipped, never read from another
%   sort. Output: <Spikes.OutputDir or output folder>/<Name><Suffix>.mat.
%
%   Options: Datasets (indices), DryRun (log only).

arguments
    obj (1,1) EphysPipeline
    opts.Datasets (1,:) double = []
    opts.DryRun (1,1) logical = false
end

c = obj.Config;
K = c.Spikes;
dopt = EphysPipelineConfig.detectOptions(K, c.Parallel);
ds = obj.selected(opts.Datasets);
n = numel(ds);
if n > 0; obj.logParallel("spikes"); end

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
    if K.Source ~= "detect" && d.sortingMissing()
        obj.addResult("spikes", d.Name, "skipped", "the sorted-output folder is not there: " + d.SortingDir, out, toc(t0));
        continue
    elseif K.Source ~= "detect" && ~d.hasKilosortResults()
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
        lo = 0;   % share of this dataset's progress an artifact detection took
        if K.Source ~= "sorted" && K.ArtifactMode ~= "none"
            obj.progress("spikes", d.Name, k, n, 0, 1, "artifact intervals");
            [iv, src] = obj.artifactIntervalsForStep(d, c.Artifacts.ApplyToSpikes, ...   % a detection fills the first half
                @(done, total, msg) obj.progress("spikes", d.Name, k, n, done / max(total, 1) / 2, 1, "artifact intervals, " + msg));
            if src == "computed"; lo = 0.5; end
            args = {'ArtifactIntervals', iv};
        end
        cb = @(done, total, msg) obj.progress("spikes", d.Name, k, n, lo + (1 - lo) * done / max(total, 1), 1, msg);
        r = d.spikesToMat('File', out, 'Source', K.Source, 'DetectOptions', dopt, 'Channels', channels, ...
            'ArtifactMode', K.ArtifactMode, 'Groups', K.Groups, 'IncludeNoise', K.IncludeNoise, ...
            'Templates', K.Templates, 'MatVersion', K.MatVersion, ...
            'Overwrite', K.Overwrite, 'ProgressFcn', cb, args{:});
        msg = sprintf("%s: %d unit(s), %d detected event(s), %d rejected", K.Source, r.nUnits, ...
            sum(r.nDetected), sum(r.nRejectedArtifact));
        if K.Source ~= "sorted" && K.ArtifactMode == "erase"
            msg = msg + sprintf(", %d artifact period(s) erased before detection", size(iv, 1));
        end
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
