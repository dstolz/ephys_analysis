function T = plan(obj, opts)
%plan  What a run would do, per step and dataset, without writing anything.
%   T = pipe.plan() returns a table (Step, Dataset, Key, Output, Status, Note)
%   for every enabled step (or Steps=...) and selected dataset:
%     ready                        will run
%     ok / no probe / probe file missing / probe-channel mismatch
%                                  the probe check (probeFor: the dataset's
%                                  own probe, else the default)
%     associated                   the associated Epsych2 session is kept
%     behavior file missing        the associated session file is not there
%                                  (kept; nothing is paired or written)
%     no session                   none associated and Behavior.Search is off
%     exists: skip / overwrite     the output file exists (Overwrite decides)
%     exists: skip (SkipExisting)  sorted output exists and Sorting.SkipExisting
%     skip: Kilosort4 running / queued
%                                  a run for this dataset is going or waits
%                                  in a queue (PriorRuns, LaunchedRuns)
%     no recording files           the folder holds no readable recording
%     no sorting output            a step needs sorted units this dataset lacks
%     no extract file              export needs the Signals output (the files
%                                  of Export.Signals only, exportExtractFiles)
%     duplicate output             another dataset of the project, selected or
%                                  not, writes the same file (e.g. both in a
%                                  configured Signals / Spikes / Export
%                                  OutputDir under one name)
%     error: output folder shared with <key>
%                                  another dataset of the project has the same
%                                  name, so both would use <OutputRoot>/<Name>
%                                  and read or overwrite each other's outputs
%     error: sorting folder missing
%                                  a step reads sorted units but the dataset's
%                                  hand-picked sorted-output folder (SortingDir)
%                                  is not there (a disk or share not connected)
%     error: unit identity         a step reads sorted units but the dataset
%                                  name does not give the subject and
%                                  recording start (Project.NamePattern)
%     error: unit label collision  another sorted or selected dataset has the
%                                  same subject and recording start minute,
%                                  so their unit labels would be the same
%     error: ...                   a setting cannot apply to this dataset
%                                  (e.g. LFP_Fs above the recording rate)
%   Rows whose Status starts with "duplicate" or "error" stop run()
%   (checkRun). Only the selected datasets are planned; their output folders
%   and files are compared with those of every dataset in the project, from
%   names and folders alone (nothing is read).
%
%   See also EphysPipeline.run, EphysPipeline.checkRun, EphysPipelineConfig.validate.

arguments
    obj (1,1) EphysPipeline
    opts.Steps (1,:) string = string.empty(1,0)
end

c = obj.Config;
steps = opts.Steps;
if isempty(steps); steps = c.enabledSteps(); end
P = obj.Project;
allKeys = P.datasetKeys();
ds = obj.selected();
keys = allKeys(obj.DatasetIdx);

Step = strings(0, 1); Dataset = strings(0, 1); Key = strings(0, 1);
Output = strings(0, 1); Status = strings(0, 1); Note = strings(0, 1);
Idx = zeros(0, 1);      % the row's dataset: its index in Project.Datasets
Units = false(0, 1);    % the row reads sorted units (labelled from the dataset name)
    function add(step, k, out, st, note, units)
        if nargin < 6; units = false; end
        Step(end+1, 1) = step; Dataset(end+1, 1) = ds(k).Name; Key(end+1, 1) = keys(k);
        Output(end+1, 1) = out; Status(end+1, 1) = st; Note(end+1, 1) = note;
        Idx(end+1, 1) = obj.DatasetIdx(k); Units(end+1, 1) = units;
    end

for step = steps
    for k = 1:numel(ds)
        d = ds(k);
        hasFiles = d.NumFiles > 0 && d.RecordingFormat ~= "unknown";
        switch step
            case "probe"
                probe = obj.probeFor(d);
                [st, note] = EphysPipeline.probeStatus(probe, d);
                if d.ProbeFile == "" && probe ~= ""
                    note = "default probe" + ternary(c.Probe.WriteDefaultToManifest, ", will be saved to the manifest", "") ...
                        + ternary(note == "", "", "; " + note);
                end
                add(step, k, probe, st, note);

            case "behavior"
                note = "";
                if c.Behavior.WriteFile
                    note = "writes " + obj.outputPathFor("behavior", d) + " when associated";
                end
                if c.Behavior.PairTrials
                    pr = "pairs trials with " + c.Behavior.TrialLine;
                    if c.Behavior.AutoApprove
                        pr = pr + ", approving matching counts";
                    end
                    if ~isempty(d.TrialPairing)
                        pr = pr + " (recorded pairing: " + d.TrialPairing.status + ")";
                    end
                    note = strjoin([note(note ~= ""), pr], "; ");
                end
                keep = ~c.Behavior.Overwrite || ~c.Behavior.Search;
                if d.BehaviorFile == "" && ~c.Behavior.Search
                    add(step, k, "", "no session", "no session associated (Behavior.Search is off: associate one by hand)");
                elseif d.BehaviorFile ~= "" && keep && isfile(d.BehaviorFile)
                    add(step, k, d.BehaviorFile, "associated", note);
                elseif d.BehaviorFile ~= "" && keep
                    add(step, k, d.BehaviorFile, "behavior file missing", ...
                        "the association is kept (Behavior.Overwrite re-matches); nothing is paired or written");
                else
                    add(step, k, "", "ready", strjoin(["will search " + strjoin(c.Behavior.SearchDirs, "; "), note(note ~= "")], "; "));
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
                probe = obj.probeFor(d);
                run = obj.activeRun(d);
                if ~hasFiles
                    add(step, k, out, "no recording files", "");
                elseif ~isempty(run)
                    state = ternary(run.queued, "queued", "running");
                    add(step, k, out, "skip: Kilosort4 " + state, "a Kilosort4 run for this dataset is " + state);
                elseif probe == ""
                    add(step, k, out, "no probe", "");
                elseif ~isfile(probe)
                    add(step, k, out, "probe file missing", probe);
                elseif d.hasKilosortResults() && c.Sorting.SkipExisting
                    add(step, k, out, "exists: skip (SkipExisting)", string(d.sortingResultsDir()));
                elseif d.sortingMissing() && c.Sorting.SkipExisting
                    add(step, k, out, "exists: skip (SkipExisting)", d.SortingDir + " (not there now)");
                elseif d.hasKilosortResults()
                    add(step, k, out, "exists: will re-sort", string(d.sortingResultsDir()));
                else
                    add(step, k, out, "ready", ternary(c.Sorting.DryRun, "dry run", executionText(c.Sorting)));
                end

            case "signals"
                % One row per output file (per signal type when SeparateFiles).
                outs = obj.outputPathFor("signals", d);
                anyExists = any(isfile(outs));
                for out = outs
                    if ~hasFiles
                        add(step, k, out, "no recording files", "");
                    elseif c.Signals.LFP && ~isnan(d.Fs) && c.Signals.LFP_Fs > d.Fs
                        add(step, k, out, "error: LFP_Fs above the recording rate", sprintf("%g > %g Hz", c.Signals.LFP_Fs, d.Fs));
                    elseif c.Signals.MUA && ~isnan(d.Fs) && c.Signals.MUA_Fs > d.Fs
                        add(step, k, out, "error: MUA_Fs above the recording rate", sprintf("%g > %g Hz", c.Signals.MUA_Fs, d.Fs));
                    elseif anyExists && ~c.Signals.Overwrite
                        add(step, k, out, "exists: skip", ternary(isfile(out), "", "another output file of this dataset exists"));
                    elseif isfile(out)
                        add(step, k, out, "exists: overwrite", "");
                    else
                        add(step, k, out, "ready", "");
                    end
                end

            case "spikes"
                out = obj.outputPathFor("spikes", d);
                units = c.Spikes.Source ~= "detect";
                if ~hasFiles
                    add(step, k, out, "no recording files", "");
                elseif units && d.sortingMissing()
                    add(step, k, out, "error: sorting folder missing", missingSortNote(d));
                elseif units && ~d.hasKilosortResults()
                    add(step, k, out, "no sorting output", "Source = " + c.Spikes.Source);
                elseif isfile(out) && ~c.Spikes.Overwrite
                    add(step, k, out, "exists: skip", "", units);
                elseif isfile(out)
                    add(step, k, out, "exists: overwrite", "", units);
                else
                    add(step, k, out, "ready", "", units);
                end

            case "export"
                extract = obj.exportExtractFiles(d);
                units = c.Export.IncludeUnits && d.hasKilosortResults();
                for fmt = c.Export.Formats
                    out = obj.outputPathFor("export:" + fmt, d);
                    note = "";
                    if c.Export.IncludeUnits && ~d.hasKilosortResults()
                        note = "no sorted units (left out)";
                    end
                    if fmt == "epochs"
                        ep = sprintf("epochs [%g %g] s around ", c.Export.EpochWindow(1), c.Export.EpochWindow(2));
                        if c.Export.EpochSource == "behavior"
                            ep = ep + "the paired trials";
                            if isempty(d.TrialPairing)
                                ep = ep + " (no recorded pairing)";
                            elseif d.TrialPairing.status ~= "approved"
                                ep = ep + " (pairing " + d.TrialPairing.status + ")";
                            end
                        elseif c.Export.EpochLine == ""
                            ep = ep + "the trial line, or the only dig-in line";
                        else
                            ep = ep + c.Export.EpochLine;
                        end
                        note = strjoin([note(note ~= ""), ep], "; ");
                    end
                    if (isempty(extract) || ~all(isfile(extract))) && ~(c.Signals.Enabled && ismember("signals", steps))
                        add("export:" + fmt, k, out, "no extract file", "expected " + strjoin(extract(~isfile(extract)), ", "));
                    elseif c.Export.IncludeUnits && d.sortingMissing()
                        add("export:" + fmt, k, out, "error: sorting folder missing", missingSortNote(d));
                    elseif isfile(out) && ~c.Export.Overwrite
                        add("export:" + fmt, k, out, "exists: skip", note, units);
                    elseif isfile(out)
                        add("export:" + fmt, k, out, "exists: overwrite", note, units);
                    else
                        add("export:" + fmt, k, out, "ready", note, units);
                    end
                end
        end
    end
end

T = table(Step, Dataset, Key, Output, Status, Note);

% Two recordings with the same name map to the same <OutputRoot>/<Name>,
% where each would read or overwrite the other's outputs. Every dataset of
% the project counts, selected or not: a later run of the other one would
% collide just the same.
folderKey = strings(1, P.NumDatasets);
for i = 1:P.NumDatasets
    folderKey(i) = EphysDataset.pathKey(P.Datasets(i).outputFolder());
end
for k = 1:numel(ds)
    i = obj.DatasetIdx(k);
    others = find(folderKey == folderKey(i));
    others(others == i) = [];
    rows = Idx == i & T.Step ~= "probe";
    if isempty(others) || ~any(rows); continue; end
    T.Status(rows) = "error: output folder shared with " + strjoin(allKeys(others), ", ");
    T.Note(rows) = sprintf("%s is also the output folder of %s (the same name under Project.OutputRoot). " + ...
        "Rename one recording folder, or leave OutputRoot empty (outputs next to each recording).", ...
        ds(k).outputFolder(), strjoin(allKeys(others), ", "));
end

% Rows that read sorted units label them from the dataset name: the name must
% match the pattern, and no two recordings may share labels. Datasets that are
% neither selected nor sorted never get labels, so they cannot collide.
readsUnits = Units & startsWith(T.Status, ["ready" "exists: overwrite"]);
if any(readsUnits)
    sorted = false(1, P.NumDatasets);
    for i = 1:P.NumDatasets
        sorted(i) = isSorted(P.Datasets(i));
    end
    I = P.unitIdentities(Among=union(obj.DatasetIdx, find(sorted)));
    for r = find(readsUnits).'
        at = find(I.Key == T.Key(r), 1);
        if isempty(at) || I.Status(at) == "ok"; continue; end
        if I.Status(at) == "collision"
            T.Status(r) = "error: unit label collision";
        else
            T.Status(r) = "error: unit identity";
        end
        T.Note(r) = I.Message(at);
    end
end

% No two datasets may write one file (case-insensitive): each file a selected
% row writes is compared with what every dataset of the project writes for
% that step.
fileRows = find(~ismember(T.Step, ["probe" "behavior"]) & T.Output ~= "" & startsWith(T.Status, ["ready" "exists"]));
if ~isempty(fileRows)
    owners = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for step = unique(T.Step(fileRows)).'
        for i = 1:P.NumDatasets
            for f = obj.outputPathFor(step, P.Datasets(i))
                fk = char(EphysDataset.pathKey(f));
                if isKey(owners, fk); owners(fk) = [owners(fk) i]; else; owners(fk) = i; end
            end
        end
    end
    for r = fileRows.'
        others = setdiff(owners(char(EphysDataset.pathKey(T.Output(r)))), Idx(r));
        if isempty(others); continue; end
        T.Status(r) = "duplicate output";
        T.Note(r) = "also written by " + strjoin(allKeys(others), ", ");
    end
end
end


function tf = isSorted(d)
%isSorted  Whether dataset D has sorted units: its sorting folder holds them,
%   or a hand-picked folder is recorded - on D, or in its manifest when D was
%   not refreshed (the pipeline refreshes the selected datasets only).
tf = d.hasKilosortResults() || d.SortingDir ~= "";
if tf; return; end
m = EphysDataset.readManifest(d.manifestFile());
tf = isstruct(m) && isfield(m, 'sorting') && isstruct(m.sorting) && isfield(m.sorting, 'source') ...
    && string(m.sorting.source) == "manual";
end


function s = missingSortNote(d)
%missingSortNote  Why a step that reads D's sorted units cannot run.
s = d.SortingDir + " is not there (a disk or share not connected?); connect it, or choose another " + ...
    "sorted-output folder (a sort is never read from anywhere else)";
end


function out = ternary(cond, a, b)
if cond; out = string(a); else; out = string(b); end
end


function t = executionText(S)
%executionText  "blocking", or "background, N at a time", and the devices.
t = S.Execution;
if t == "background"
    t = t + ", " + S.MaxConcurrent + " at a time";
end
if ~isempty(S.Devices)
    t = t + ", on " + strjoin(S.Devices, " / ");
end
end
