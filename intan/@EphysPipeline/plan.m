function T = plan(obj, opts)
%plan  What a run would do, per step and dataset, without writing anything.
%   T = pipe.plan() returns a table (Step, Dataset, Key, Output, Status, Note)
%   for every enabled step (or Steps=...) and selected dataset:
%     ready                        will run
%     exists: skip / overwrite     the output file exists (Overwrite decides)
%     exists: skip (SkipExisting)  sorted output exists and Sorting.SkipExisting
%     no recording files           the folder holds no readable recording
%     no probe / probe-channel mismatch
%     no sorting output            a step needs sorted units this dataset lacks
%     no extract file              export needs the Signals output
%     duplicate output             two selected datasets would write one file
%     error: ...                   a setting cannot apply to this dataset
%                                  (e.g. LFP_Fs above the recording rate)
%   Rows whose Status starts with "duplicate" or "error" stop run().
%
%   See also EphysPipeline.run, EphysPipelineConfig.validate.

arguments
    obj (1,1) EphysPipeline
    opts.Steps (1,:) string = string.empty(1,0)
end

c = obj.Config;
steps = opts.Steps;
if isempty(steps); steps = c.enabledSteps(); end
ds = obj.selected();
keys = strings(1, numel(ds));
for k = 1:numel(ds)
    keys(k) = EphysProject.relativeKey(obj.Project.Root, ds(k).Folder);
end

Step = strings(0, 1); Dataset = strings(0, 1); Key = strings(0, 1);
Output = strings(0, 1); Status = strings(0, 1); Note = strings(0, 1);
    function add(step, k, out, st, note)
        Step(end+1, 1) = step; Dataset(end+1, 1) = ds(k).Name; Key(end+1, 1) = keys(k);
        Output(end+1, 1) = out; Status(end+1, 1) = st; Note(end+1, 1) = note;
    end

for step = steps
    for k = 1:numel(ds)
        d = ds(k);
        hasFiles = d.NumFiles > 0 && d.RecordingFormat ~= "unknown";
        switch step
            case "probe"
                if d.ProbeFile == "" && c.Probe.DefaultProbeFile ~= ""
                    add(step, k, c.Probe.DefaultProbeFile, "ready", "default probe will be assigned");
                elseif d.ProbeFile == ""
                    add(step, k, "", "no probe", "");
                elseif ~isfile(d.ProbeFile)
                    add(step, k, d.ProbeFile, "probe file missing", "");
                else
                    pm = DatasetTracker.probeMeta(readJsonFile(d.ProbeFile, ErrorOnFail=false));
                    if isfinite(pm.nChan) && ~isnan(d.NumChannels) && pm.nChan > d.NumChannels
                        add(step, k, d.ProbeFile, "probe-channel mismatch", ...
                            sprintf("probe has %d sites, recording %d channels", pm.nChan, d.NumChannels));
                    else
                        add(step, k, d.ProbeFile, "ok", "");
                    end
                end

            case "behavior"
                if d.BehaviorFile ~= "" && isfile(d.BehaviorFile) && ~c.Behavior.Overwrite
                    add(step, k, d.BehaviorFile, "associated", "");
                else
                    add(step, k, "", "ready", "will search " + strjoin(c.Behavior.SearchDirs, "; "));
                end

            case "artifacts"
                out = obj.outputPathFor("artifacts", d);
                if ~hasFiles
                    add(step, k, out, "no recording files", "");
                elseif ~c.Artifacts.Enabled
                    add(step, k, out, "ready", "manual periods only (auto-detection off)");
                elseif isfile(out)
                    add(step, k, out, "ready", "cache present (reused when the settings match)");
                else
                    add(step, k, out, "ready", "");
                end

            case "sorting"
                out = obj.outputPathFor("sorting", d);
                if ~hasFiles
                    add(step, k, out, "no recording files", "");
                elseif d.ProbeFile == "" && c.Probe.DefaultProbeFile == ""
                    add(step, k, out, "no probe", "");
                elseif d.hasKilosortResults() && c.Sorting.SkipExisting
                    add(step, k, out, "exists: skip (SkipExisting)", string(d.sortingResultsDir()));
                elseif d.hasKilosortResults()
                    add(step, k, out, "exists: will re-sort", string(d.sortingResultsDir()));
                else
                    add(step, k, out, "ready", ternary(c.Sorting.DryRun, "dry run", c.Sorting.Execution));
                end

            case "signals"
                out = obj.outputPathFor("signals", d);
                if ~hasFiles
                    add(step, k, out, "no recording files", "");
                elseif c.Signals.LFP && ~isnan(d.Fs) && c.Signals.LFP_Fs > d.Fs
                    add(step, k, out, "error: LFP_Fs above the recording rate", sprintf("%g > %g Hz", c.Signals.LFP_Fs, d.Fs));
                elseif c.Signals.MUA && ~isnan(d.Fs) && c.Signals.MUA_Fs > d.Fs
                    add(step, k, out, "error: MUA_Fs above the recording rate", sprintf("%g > %g Hz", c.Signals.MUA_Fs, d.Fs));
                elseif isfile(out) && ~c.Signals.Overwrite
                    add(step, k, out, "exists: skip", "");
                elseif isfile(out)
                    add(step, k, out, "exists: overwrite", "");
                else
                    add(step, k, out, "ready", "");
                end

            case "spikes"
                out = obj.outputPathFor("spikes", d);
                if ~hasFiles
                    add(step, k, out, "no recording files", "");
                elseif c.Spikes.Source ~= "detect" && ~d.hasKilosortResults()
                    add(step, k, out, "no sorting output", "Source = " + c.Spikes.Source);
                elseif isfile(out) && ~c.Spikes.Overwrite
                    add(step, k, out, "exists: skip", "");
                elseif isfile(out)
                    add(step, k, out, "exists: overwrite", "");
                else
                    add(step, k, out, "ready", "");
                end

            case "export"
                extract = obj.outputPathFor("signals", d);
                for fmt = c.Export.Formats
                    out = obj.outputPathFor("export:" + fmt, d);
                    note = "";
                    if c.Export.IncludeUnits && ~d.hasKilosortResults()
                        note = "no sorted units (left out)";
                    end
                    if ~isfile(extract) && ~(c.Signals.Enabled && ismember("signals", steps))
                        add("export:" + fmt, k, out, "no extract file", "expected " + extract);
                    elseif isfile(out) && ~c.Export.Overwrite
                        add("export:" + fmt, k, out, "exists: skip", note);
                    elseif isfile(out)
                        add("export:" + fmt, k, out, "exists: overwrite", note);
                    else
                        add("export:" + fmt, k, out, "ready", note);
                    end
                end
        end
    end
end

T = table(Step, Dataset, Key, Output, Status, Note);

% Two selected datasets must never write the same file (case-insensitive).
fileSteps = ~ismember(T.Step, ["probe" "behavior"]) & T.Output ~= "" & startsWith(T.Status, ["ready" "exists"]);
for step = unique(T.Step(fileSteps)).'
    rows = find(fileSteps & T.Step == step);
    keyOut = lower(T.Output(rows));
    [~, ~, g] = unique(keyOut);
    counts = accumarray(g, 1);
    dup = rows(counts(g) > 1);
    T.Status(dup) = "duplicate output";
    T.Note(dup) = "another selected dataset writes the same file (same name?)";
end
end


function out = ternary(cond, a, b)
if cond; out = string(a); else; out = string(b); end
end
