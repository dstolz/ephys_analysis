function X = transferOutputs(obj, opts)
%transferOutputs  Copy or move the outputs of the Results rows to Transfer.Destination.
%   X = pipe.transferOutputs() queues, for every Results row, the files and
%   folders it names (Output) on the pipeline's OutputTransfer (Transfer,
%   made from the config's Transfer section when there is none or it is
%   closed), adds each dataset's manifest, closes the transfer and waits
%   for it. run() calls it with Transfer.Enabled; a script that calls the
%   step methods one by one calls it last. The Transfer section's Enabled
%   is not read here, its Destination must be set.
%
%   Each dataset's files go to <Destination>/<key> (transferKey: its folder
%   below the project root, the raw data's subject/session), with their
%   paths below its output folder; IfExists decides what happens when that
%   folder is already there (OutputTransfer). Which rows count:
%     done                       the outputs it wrote
%     skipped, output exists     the outputs already there (Overwrite off,
%                                Sorting.SkipExisting): still the dataset's
%     launched / queued sorting  the sort folder, once the background run
%                                has ended (a run that fails is not copied)
%   of the steps behavior:file, artifacts (the cache), sorting (the sort
%   folder; never the .bin), signals, spikes, export:<format> and
%   analysis:<plot> / analysis:report of one dataset. The association and
%   pairing rows of the behavior step, the probe check and the analysis
%   report over every dataset name nothing to copy. The manifest
%   (<Name>_manifest.json, in the recording folder) is copied with them,
%   last, and never removed by a move. A sort folder a move took becomes
%   the dataset's sorting folder (repointMovedSort).
%
%   Each dataset has one "transfer" result row (Output: its folder in the
%   destination), restated as its batches go (OutputTransfer.statusOf).
%
%   Options
%     Rows    the Results rows to copy (default all)
%     Close   true (default): add the manifests and close the transfer
%             (no more batches; a move removes what it copied)
%     Wait    true (default): wait until the transfer is done, logging
%             where it is every 30 s
%
%   See also OutputTransfer, EphysPipeline.run, EphysPipelineConfig.defaults.

arguments
    obj (1,1) EphysPipeline
    opts.Rows (1,:) double = 1:height(obj.Results)
    opts.Close (1,1) logical = true
    opts.Wait (1,1) logical = true
end

if isempty(obj.Transfer) || (obj.Transfer.Closed && ~obj.Transfer.Canceled)   % a stopped one stays stopped
    obj.Transfer = newTransfer(obj);
    if ~isempty(obj.TransferFcn)
        obj.TransferFcn(obj.Transfer);
    end
end
X = obj.Transfer;
R = obj.Results;
for r = opts.Rows
    if startsWith(R.Step(r), "transfer"); continue; end
    [d, paths, waitFor, since] = rowOutputs(obj, R(r, :));
    if isempty(paths); continue; end
    onMoved = [];
    if startsWith(R.Step(r), "sorting")
        onMoved = @(folder, newFolder) EphysPipeline.repointMovedSort(d, folder, newFolder);
    end
    try
        X.add(EphysPipeline.transferKey(d), paths, Base=string(d.outputFolder()), Dataset=d.Name, ...
            Label=R.Step(r), WaitFor=waitFor, Since=since, OnMoved=onMoved);
    catch ME
        obj.log("[transfer] %s: %s not queued: %s", d.Name, R.Step(r), ME.message);
    end
end
if opts.Close
    addManifests(obj, X);
    X.close();
end
X.poll();
if opts.Wait
    X.wait(LogEvery=30);
end
end


function X = newTransfer(obj)
%newTransfer  An OutputTransfer for the config's Transfer section; it restates the "transfer" rows.
T = obj.Config.Transfer;
if strtrim(T.Destination) == ""
    error('EphysPipeline:NoTransferDestination', 'Transfer.Destination is not set: the outputs have nowhere to go.');
end
X = OutputTransfer(T.Destination, Method=T.Method, IfExists=T.IfExists, Verify=T.Verify, ...
    LogFcn=@(msg) obj.log("[transfer] %s", msg));
X.BatchFcn = @(b) restate(obj, X, b);
end


function restate(obj, X, b)
%restate  The dataset's "transfer" result row, made at its first batch and restated after.
[st, msg, folder] = X.statusOf(b.Key);
R = obj.Results;
if any(R.Step == "transfer" & R.Dataset == b.Dataset & R.Output == folder)
    obj.updateResult("transfer", b.Dataset, folder, st, msg);
else
    obj.addResult("transfer", b.Dataset, st, msg, folder, 0);
end
end


function [d, paths, waitFor, since] = rowOutputs(obj, row)
%rowOutputs  The dataset of a Results row and the outputs it names that are there to copy.
%   WAITFOR is the status file of a background sort to wait for, SINCE when
%   a queued one was handed over (a status file older than that is an
%   earlier run's; a launched run deleted its own).
d = [];
paths = strings(1, 0);
waitFor = "";
since = NaT;
step = row.Step;
kind = extractBefore(step + ":", ":");
if row.Dataset == "" || ismember(step, ["behavior" "behavior:pairing" "analysis"]) ...
        || ~ismember(kind, ["behavior" "artifacts" "sorting" "signals" "spikes" "export" "analysis"])
    return
end
switch row.Status
    case "done"
    case {"launched", "queued"}
        if kind ~= "sorting"; return; end
    case "skipped"
        if ~contains(row.Message, "exists"); return; end   % kept because it is there
    otherwise
        return
end
out = strtrim(split(row.Output, "; ")).';
out = out(out ~= "");
paths = out(isfile(out) | isfolder(out));
if isempty(paths); return; end
d = datasetOf(obj, row.Dataset, paths(1));
if isempty(d)
    paths = strings(1, 0);
    return
end
if ismember(row.Status, ["launched" "queued"])
    waitFor = sortStatusFile(obj, paths(1));
    if row.Status == "queued"; since = datetime('now'); end
end
end


function f = sortStatusFile(obj, resultsDir)
%sortStatusFile  The status file of the background sort writing into RESULTSDIR.
runs = obj.LaunchedRuns;
for k = numel(runs):-1:1
    if EphysDataset.pathKey(runs(k).resultsDir) == EphysDataset.pathKey(resultsDir)
        f = string(runs(k).statusFile);
        return
    end
end
[~, leaf] = fileparts(resultsDir);
if startsWith(leaf, "si_")
    f = string(fullfile(resultsDir, "si_status.json"));
else
    f = string(fullfile(resultsDir, "ks4_status.json"));
end
end


function d = datasetOf(obj, name, path)
%datasetOf  The selected dataset NAME (of two with that name, the one whose output folder holds PATH).
d = [];
ds = obj.Project.Datasets(obj.DatasetIdx);
if isempty(ds); return; end
cand = ds([ds.Name] == name);
if numel(cand) > 1
    p = EphysDataset.pathKey(path);
    k = find(arrayfun(@(c) startsWith(p, EphysDataset.pathKey(c.outputFolder()) + "/"), cand), 1);
    if isempty(k); k = 1; end
    cand = cand(k);
end
if ~isempty(cand); d = cand(1); end
end


function addManifests(obj, X)
%addManifests  Each dataset with a batch: its manifest, copied last and never removed.
if isempty(X.Batches); return; end
keys = unique(lower([X.Batches.Key]), 'stable');
for d = obj.Project.Datasets(obj.DatasetIdx)
    key = EphysPipeline.transferKey(d);
    f = string(d.manifestFile());
    if ~ismember(lower(key), keys) || ~isfile(f); continue; end
    try
        X.add(key, f, Base=string(d.outputFolder()), Dataset=d.Name, Label="manifest", Keep=f);
    catch ME
        obj.log("[transfer] %s: manifest not queued: %s", d.Name, ME.message);
    end
end
end
