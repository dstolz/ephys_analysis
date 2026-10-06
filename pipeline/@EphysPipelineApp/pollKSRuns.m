function pollKSRuns(obj)
%pollKSRuns  Timer callback: stream each background sort run's log,
%   check for completion and start the queued runs.
%   Each background run (Kilosort4, or a SpikeInterface sorter) redirects
%   the sorter's stdout/stderr to its log (ks4_run.log, si_run.log) and
%   writes its status (ks4_status.json, si_status.json: state "done" or
%   "error") in its results dir when
%   it finishes (EphysDataset.sortRunState; a process that exits without one
%   counts as failed). Every tick this tails each run's log into the status
%   box so progress is visible live, then polls the runs. A finished run is
%   logged, its dataset's manifest rewritten and its row in the Run tab's
%   results restated as "done", "error" or, for a run stopped with Stop
%   runs (stopKSRuns), "cancelled" (markKSResult), with the time it ran
%   added to its Seconds.
%   Then, while fewer than Sorting.MaxConcurrent runs are going, the queued
%   runs (KSQueue, see queueKSRun) start in order, each on the GPU of
%   Sorting.Devices that the fewest running runs use (sortingSlot), and
%   their rows turn "launched". Both limits are read from the working
%   config at each tick. The queue is held while a Run that waits for its
%   own slots is under way: its launches go first.
%   The progress label says how many runs finished, are running and are
%   still to start (queued, or waiting in the pipeline's sorting step). The
%   monitor stops once every run has finished and none is left to start.
%   Only a tick in which a run started or finished refreshes the Project
%   table, and then only those datasets' rows. An error in one run's
%   handling, or in starting the queue, is logged and the others go on.

if isempty(obj.Fig) || ~isvalid(obj.Fig)   % the app went without onClose
    obj.stopKSMonitor();
    return
end
if isempty(obj.KSRuns) && isempty(obj.KSQueue)
    obj.stopKSMonitor();
    syncStopButtons(obj, 0);
    return
end

pending = 0;
changed = zeros(1, 0);   % KSRuns indices that started or finished this tick
for i = 1:numel(obj.KSRuns)
    if obj.KSRuns(i).done
        continue
    end
    try
        % Stream any new log output for this run into the status box.
        obj.KSRuns(i).logPos = tailLog(obj, obj.KSRuns(i));
        [state, msg] = EphysDataset.sortRunState(obj.KSRuns(i).statusFile);
    catch ME
        obj.log("[error] %s - could not read how the run stands: %s", obj.KSRuns(i).Name, ME.message);
        pending = pending + 1;   % asked again next tick
        continue
    end
    if state == "running"
        pending = pending + 1;
        continue
    end
    obj.KSRuns(i).done = true;
    changed(end+1) = i; %#ok<AGROW>
    try
        obj.KSRuns(i).logPos = tailLog(obj, obj.KSRuns(i));   % flush the tail of its log first
        reportFinished(obj, obj.KSRuns(i), state, msg);
    catch ME
        obj.log("[error] %s - the run ended (%s) but recording it failed: %s", obj.KSRuns(i).Name, state, ME.message);
    end
end

% Start queued runs while there are free slots, unless a Run is waiting
% for slots itself (its PriorRuns are the runs already here).
ownSlots = obj.RunActive && ~isempty(obj.Pipe) && isvalid(obj.Pipe) && isempty(obj.Pipe.QueueFcn);
if ~isempty(obj.KSQueue) && ~ownSlots
    n0 = numel(obj.KSRuns);
    try
        startQueued(obj, obj.Config.Sorting);
    catch ME
        obj.log("[error] starting the queued Kilosort4 runs failed: %s", ME.message);
    end
    started = n0 + 1:numel(obj.KSRuns);
    pending = pending + numel(started);
    changed = [changed, started];
end

% Datasets still to start: queued here, or waiting in the running pipeline.
waiting = numel(obj.KSQueue);
if obj.RunActive && ~isempty(obj.Pipe) && isvalid(obj.Pipe)
    waiting = waiting + obj.Pipe.SortingWaiting;
end

nTot  = numel(obj.KSRuns);
nDone = nnz([obj.KSRuns.done]);
txt = sprintf("Background %s: %d of %d finished (%d running", runsLabel(obj.KSRuns), nDone, nTot + waiting, pending);
if waiting > 0
    txt = txt + sprintf(", %d waiting to start", waiting);
end
obj.KSProgressLabel.Text = txt + ").";
if ~isempty(obj.RunKSLabel) && isvalid(obj.RunKSLabel)
    obj.RunKSLabel.Text = obj.KSProgressLabel.Text;
end
syncStopButtons(obj, pending);

% The Project table follows the datasets whose run started or finished.
if ~isempty(changed)
    ix = unique(arrayfun(@(k) runDataset(obj, obj.KSRuns(k)), changed));
    ix = ix(ix > 0);
    if ~isempty(ix)
        obj.refreshDatasetsTable(Datasets=ix);
        if ismember(obj.SelectedDatasetIdx, ix)
            obj.ReviewDatasetIdx = -1;   % its sorted output changed: the Review tab reloads
        end
    end
end

if pending == 0 && waiting == 0
    obj.log("=== all %d background run(s) complete ===", nTot);
    obj.setStatus(sprintf("%s finished: %d background run(s) complete.", runsLabel(obj.KSRuns), nTot), ...
        "Open the Review tab to inspect sorted units.");
    obj.stopKSMonitor();
    obj.KSRuns(:) = [];   % clear the completed batch
end
end


%% ---- local helpers ----------------------------------------------------

function reportFinished(obj, run, state, msg)
%reportFinished  Record a run that ended: its manifest, the log, its result row.
ix = runDataset(obj, run);
if ix > 0
    lastwarn("");
    if ~obj.Project.Datasets(ix).writeManifest()   % the completed sort, on disk and in the table
        obj.log("[error] %s - its manifest was not rewritten: %s", run.Name, lastwarn());
    end
end
took = 0;
if ~isnat(run.started); took = round(seconds(datetime('now') - run.started), 1); end
what = EphysDataset.sorterLabel(EphysDataset.sorterOfRunDir(run.resultsDir));
if state == "done"
    obj.log("[done] %s - %s complete (%s)", run.Name, what, run.resultsDir);
    obj.markKSResult(run.Name, run.resultsDir, "done", what + " finished" + onDevice(run.device), took);
elseif state == "cancelled"
    obj.log("[stopped] %s - %s stopped by the user", run.Name, what);
    obj.markKSResult(run.Name, run.resultsDir, "cancelled", "stopped before it finished", took);
else
    obj.log("[error] %s - %s failed: %s", run.Name, what, msg);
    obj.markKSResult(run.Name, run.resultsDir, "error", what + " failed: " + msg, took);
end
end


function startQueued(obj, S)
%startQueued  Start queued runs, first in first out, while a slot is free.
while ~isempty(obj.KSQueue)
    running = obj.KSRuns(~[obj.KSRuns.done]);
    [free, device] = sortingSlot(running, max(1, S.MaxConcurrent), S.Devices);
    if ~free
        return
    end
    q = obj.KSQueue(1);
    obj.KSQueue(1) = [];
    try
        res = q.dataset.launchSorting(q.prepared, Wait=false, Device=device);   % LaunchFailed / SetAsideFailed throw
    catch ME
        obj.log("[error] %s - %s did not start: %s", q.Name, ...
            EphysDataset.sorterLabel(EphysDataset.sorterOfRunDir(q.prepared.resultsDir)), ME.message);
        obj.markKSResult(q.Name, q.prepared.resultsDir, "error", "did not start: " + string(ME.message));
        continue
    end
    obj.KSRuns(end+1) = EphysPipeline.sortRun(q.Name, res);
    aside = "";
    if res.previousDir ~= ""; aside = "; the earlier sort's curation moved to " + res.previousDir; end
    obj.log("[sorting] %s: launched from the queue%s -> %s%s", q.Name, onDevice(device), res.resultsDir, aside);
    obj.markKSResult(q.Name, res.resultsDir, "launched", "background run, started from the queue" + onDevice(device) + aside);
end
end


function syncStopButtons(obj, nRunning)
%syncStopButtons  Stop runs is on while runs are going, Stop queue while
%   runs are queued.
b = obj.RunKSStopRunsButton;
if ~isempty(b) && isvalid(b)
    b.Enable = matlab.lang.OnOffSwitchState(nRunning > 0);
end
b = obj.RunKSStopQueueButton;
if ~isempty(b) && isvalid(b)
    b.Enable = matlab.lang.OnOffSwitchState(~isempty(obj.KSQueue));
end
end


function t = runsLabel(runs)
%runsLabel  What sorts RUNS: "Kilosort4", "<sorter> (SpikeInterface)" when
%   they all are by that sorter, else "sorts".
t = "Kilosort4";
if isempty(runs); return; end
who = unique(arrayfun(@(r) EphysDataset.sorterLabel(EphysDataset.sorterOfRunDir(r.resultsDir)), runs));
if isscalar(who)
    t = who;
else
    t = "sorts";
end
end


function t = onDevice(device)
%onDevice  " on cuda:1", or "" without a device.
t = "";
if device ~= ""; t = " on " + device; end
end


function ix = runDataset(obj, run)
%runDataset  Index of the scanned dataset RUN sorts (0 when none): the one
%   whose output folder holds the run's results folder (kilosort4 or
%   si_<sorter>), else the first of its name.
ix = 0;
if isempty(obj.Project) || obj.Project.NumDatasets == 0; return; end
dirs = arrayfun(@(d) string(d.outputFolder()), obj.Project.Datasets);
ix = find(EphysDataset.pathKey(dirs) == EphysDataset.pathKey(string(fileparts(char(run.resultsDir)))), 1);
if isempty(ix)
    ix = find([obj.Project.Datasets.Name] == string(run.Name), 1);
end
if isempty(ix); ix = 0; end
end


function pos = tailLog(obj, run)
%tailLog  Append RUN's newly written ks4_run.log lines to the status box.
%   Returns the byte offset consumed, so the next tick resumes there
%   (readNewLines: whole lines only, carriage-return progress collapsed).
[lines, pos] = readNewLines(run.logFile, run.logPos);
if isempty(lines); return; end
ts = char(datetime('now', 'Format', 'HH:mm:ss'));
obj.appendLogLines(string(ts) + "  " + string(run.Name) + " | " + lines);
end
