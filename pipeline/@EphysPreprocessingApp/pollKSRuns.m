function pollKSRuns(obj)
%pollKSRuns  Timer callback: stream each background Kilosort4 run's log and
%   check for completion.
%   Each background run redirects Kilosort4 stdout/stderr to a ks4_run.log and
%   writes a ks4_status.json (state "done" or "error") in its results dir when
%   it finishes (EphysDataset.sortRunState; a process that exits without one
%   counts as failed). Every tick this tails each run's log into the status
%   box so progress is visible live, then polls the runs, logs each
%   completion and updates the progress label: how many finished, are
%   running and, while the pipeline's sorting step waits for a free slot
%   (Sorting.MaxConcurrent), are still to start. The monitor stops once
%   every run has finished and none is left to start.

if isempty(obj.KSRuns)
    obj.stopKSMonitor();
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
    % Record the completed sort in the dataset's manifest.
    updateManifestFor(obj, obj.KSRuns(i).Name);
    if state == "done"
        obj.log("[done] %s - Kilosort4 complete (%s)", obj.KSRuns(i).Name, ...
            obj.KSRuns(i).resultsDir);
    else
        obj.log("[error] %s - Kilosort4 failed: %s", obj.KSRuns(i).Name, msg);
    end
end

% Datasets the running pipeline has yet to start (waiting for a free slot).
waiting = 0;
if obj.RunActive && ~isempty(obj.Pipe) && isvalid(obj.Pipe)
    waiting = obj.Pipe.SortingWaiting;
end

nTot  = numel(obj.KSRuns);
nDone = sum([obj.KSRuns.done]);
txt = sprintf("Background Kilosort4: %d of %d finished (%d running", nDone, nTot + waiting, pending);
if waiting > 0
    txt = txt + sprintf(", %d waiting to start", waiting);
end
obj.KSProgressLabel.Text = txt + ").";
if ~isempty(obj.RunKSLabel) && isvalid(obj.RunKSLabel)
    obj.RunKSLabel.Text = obj.KSProgressLabel.Text;
end

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
parts = split(string(s), sprintf('\r'));
s = parts(end);
end
