function pollKSRuns(obj)
%pollKSRuns  Timer callback: stream each background Kilosort4 run's log,
%   check for completion and start the queued runs.
%   Each background run redirects Kilosort4 stdout/stderr to a ks4_run.log and
%   writes a ks4_status.json (state "done" or "error") in its results dir when
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

if isempty(obj.KSRuns) && isempty(obj.KSQueue)
    obj.stopKSMonitor();
    syncStopButtons(obj, 0);
    return
end

pending = 0;
for i = 1:numel(obj.KSRuns)
    if obj.KSRuns(i).done
        continue
    end

    % Stream any new log output for this run into the status box.
    obj.KSRuns(i).logPos = tailLog(obj, obj.KSRuns(i));

    [state, msg] = EphysDataset.sortRunState(obj.KSRuns(i).statusFile);
    if state == "running"
        pending = pending + 1;
        continue
    end

    % Run finished: flush the tail of its log before reporting status.
    obj.KSRuns(i).logPos = tailLog(obj, obj.KSRuns(i));

    obj.KSRuns(i).done = true;
    run = obj.KSRuns(i);
    % Record the completed sort in the dataset's manifest.
    updateManifestFor(obj, run.Name);
    took = 0;
    if ~isnat(run.started); took = round(seconds(datetime('now') - run.started), 1); end
    if state == "done"
        obj.log("[done] %s - Kilosort4 complete (%s)", run.Name, run.resultsDir);
        obj.markKSResult(run.Name, run.resultsDir, "done", "Kilosort4 finished" + onDevice(run.device), took);
    elseif state == "cancelled"
        obj.log("[stopped] %s - Kilosort4 stopped by the user", run.Name);
        obj.markKSResult(run.Name, run.resultsDir, "cancelled", "stopped before it finished", took);
    else
        obj.log("[error] %s - Kilosort4 failed: %s", run.Name, msg);
        obj.markKSResult(run.Name, run.resultsDir, "error", "Kilosort4 failed: " + msg, took);
    end
end

% Start queued runs while there are free slots, unless a Run is waiting
% for slots itself (its PriorRuns are the runs already here).
ownSlots = obj.RunActive && ~isempty(obj.Pipe) && isvalid(obj.Pipe) && isempty(obj.Pipe.QueueFcn);
if ~isempty(obj.KSQueue) && ~ownSlots
    pending = pending + startQueued(obj, obj.Config.Sorting);
end

% Datasets still to start: queued here, or waiting in the running pipeline.
waiting = numel(obj.KSQueue);
if obj.RunActive && ~isempty(obj.Pipe) && isvalid(obj.Pipe)
    waiting = waiting + obj.Pipe.SortingWaiting;
end

nTot  = numel(obj.KSRuns);
nDone = nnz([obj.KSRuns.done]);
txt = sprintf("Background Kilosort4: %d of %d finished (%d running", nDone, nTot + waiting, pending);
if waiting > 0
    txt = txt + sprintf(", %d waiting to start", waiting);
end
obj.KSProgressLabel.Text = txt + ").";
if ~isempty(obj.RunKSLabel) && isvalid(obj.RunKSLabel)
    obj.RunKSLabel.Text = obj.KSProgressLabel.Text;
end
syncStopButtons(obj, pending);

% Refresh the datasets table so the Bin/results columns reflect new outputs.
obj.refreshDatasetsTable();
obj.ReviewDatasetIdx = -1;   % the Review tab reloads

if pending == 0 && waiting == 0
    obj.log("=== all %d background run(s) complete ===", nTot);
    obj.setStatus(sprintf("Kilosort4 finished: %d background run(s) complete.", nTot), ...
        "Open the Review tab to inspect sorted units.");
    obj.stopKSMonitor();
    obj.KSRuns(:) = [];   % clear the completed batch
end
end


%% ---- local helpers ----------------------------------------------------

function nStarted = startQueued(obj, S)
%startQueued  Start queued runs, first in first out, while a slot is free.
nStarted = 0;
while ~isempty(obj.KSQueue)
    running = obj.KSRuns(~[obj.KSRuns.done]);
    [free, device] = sortingSlot(running, max(1, S.MaxConcurrent), S.Devices);
    if ~free
        return
    end
    q = obj.KSQueue(1);
    obj.KSQueue(1) = [];
    try
        res = q.dataset.launchSorting(q.prepared, Wait=false, Device=device);
    catch ME
        obj.log("[error] %s - Kilosort4 did not start: %s", q.Name, ME.message);
        obj.markKSResult(q.Name, q.prepared.resultsDir, "error", "did not start: " + string(ME.message));
        continue
    end
    obj.KSRuns(end+1) = EphysPipeline.sortRun(q.Name, res);
    nStarted = nStarted + 1;
    obj.log("[sorting] %s: launched from the queue%s -> %s", q.Name, onDevice(device), res.resultsDir);
    obj.markKSResult(q.Name, res.resultsDir, "launched", "background run, started from the queue" + onDevice(device));
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


function t = onDevice(device)
%onDevice  " on cuda:1", or "" without a device.
t = "";
if device ~= ""; t = " on " + device; end
end


function updateManifestFor(obj, name)
%updateManifestFor  Refresh the manifest of the dataset named NAME (if scanned),
%   so a completed background sort is reflected on disk and in the table.
if isempty(obj.Project) || obj.Project.NumDatasets == 0; return; end
ix = find([obj.Project.Datasets.Name] == string(name), 1);
if isempty(ix); return; end
try
    obj.Project.Datasets(ix).writeManifest();
catch
end
end


function pos = tailLog(obj, run)
%tailLog  Append RUN's newly-written ks4_run.log lines to the status box.
%   Returns the byte offset consumed so the next tick resumes there. Only whole
%   (newline-terminated) lines are emitted; a partial trailing line is left for
%   the next tick. Carriage-return progress updates (e.g. tqdm) are collapsed to
%   their final state so they don't flood the box.
pos = run.logPos;
lf  = char(run.logFile);
if isempty(lf) || ~isfile(lf)
    return
end

fid = fopen(lf, 'r');   % MATLAB 'r' is binary: ftell == byte offset
if fid < 0
    return
end
try
    fseek(fid, pos, 'bof');
    chunk = fread(fid, inf, '*char').';
catch
    fclose(fid);
    return
end
fclose(fid);
if isempty(chunk)
    return
end

% Consume only up to the last newline; keep any partial line for next time.
nl = find(chunk == newline, 1, 'last');
if isempty(nl)
    return
end
pos   = pos + nl;
ready = chunk(1:nl);

parts = split(string(ready), newline);
parts(end) = [];   % drop the empty segment after the final newline
ts  = char(datetime('now', 'Format', 'HH:mm:ss'));
out = strings(0, 1);
for k = 1:numel(parts)
    ln = collapseCR(parts(k));
    if strlength(strip(ln)) == 0
        continue
    end
    out(end+1, 1) = sprintf("%s  %s | %s", ts, run.Name, ln); %#ok<AGROW>
end
obj.appendLogLines(out);
end


function s = collapseCR(s)
%collapseCR  Reduce a carriage-return-overwritten line to its final state.
%   The CR of a CRLF line ending goes first: Python on Windows writes CRLF
%   to a redirected stdout, and the segment after that CR is empty.
s = regexprep(string(s), '\r+$', '');
parts = split(s, sprintf('\r'));
s = parts(end);
end
