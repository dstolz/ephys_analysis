function onPipelineProgress(obj, evt)
%onPipelineProgress  Update the Run-tab bars, results and diagram from an EphysPipeline event.
%   An event with dataset "" (index 0) marks the start of a step. The
%   results table (the Run's rows since runPipeline cleared it) takes the
%   running pipeline's Results (obj.Pipe) when the two have not as many
%   rows (the pipeline added one since), so each row shows at the next
%   event and the table is not rebuilt at every event; a row the Kilosort4
%   monitor restates reaches it through markKSResult. The Project table
%   scrolls to the dataset being processed and marks its row orange. Beside
%   the step's message, RunTimeLabel says the step's time left (timeText:
%   "about 3 min left in this step, then 2 more steps · 12 min elapsed").
if ~isvalid(obj.Fig); return; end
if ~isempty(obj.Pipe) && isvalid(obj.Pipe) && height(obj.Pipe.Results) ~= height(obj.RunResultsTable.Data)
    obj.showRunResults(obj.Pipe.Results);
end
frac = 0;
if evt.total > 0; frac = min(max(evt.done / evt.total, 0), 1); end
obj.setRunBar(obj.RunStepBar, frac);
obj.RunStepText.Text = sprintf('%d%%', round(100 * frac));
if evt.count > 0
    overall = (max(evt.index, 1) - 1 + frac) / evt.count;
    obj.setRunBar(obj.RunOverallBar, overall);
    obj.RunOverallText.Text = sprintf('%s %d/%d', evt.step, evt.index, evt.count);
end
if evt.dataset == ""
    obj.RunStepLabel.Text = char(evt.step + ": " + evt.message);
else
    obj.RunStepLabel.Text = char(evt.step + ": " + evt.dataset + " - " + evt.message);
end
obj.updateRunDiagram(evt);
obj.RunTimeLabel.Text = char(timeText(obj, evt, frac));
markRunningDataset(obj, evt.dataset);
drawnow limitrate;
end


function t = timeText(obj, evt, frac)
%timeText  The Run tab's time line: the step's time left, then the run's elapsed.
%   The step's time left (a ProgressClock, started again at each new step)
%   comes from how far it is through its datasets, as the diagram counts
%   it; it is the run's once the run's last step is under way. Before then
%   it says how many steps follow, since nothing tells how long they take.
key = extractBefore(evt.step + ":", ":");   % "export:chronux" -> "export"
if isempty(obj.RunStepClock) || obj.RunClockStep ~= key
    obj.RunStepClock = ProgressClock();
    obj.RunClockStep = key;
end
if evt.count > 0
    frac = (max(evt.index, 1) - 1 + frac) / evt.count;
end
left = obj.RunStepClock.update(frac);
M = obj.RunDiagram;
after = 0;
if isfield(M, 'steps')
    j = find([M.steps.key] == key, 1);
    if ~isempty(j); after = nnz([M.steps(j+1:end).inRun]); end
end
if left == ""
    t = "";
elseif after == 0
    t = replace(left, " left", " left in the run");
elseif after == 1
    t = replace(left, " left", " left in this step") + ", then 1 more step";
else
    t = replace(left, " left", " left in this step") + sprintf(", then %d more steps", after);
end
if isfield(M, 'started') && ~isnat(M.started)
    el = ProgressClock.elapsedText(seconds(datetime('now') - M.started));
    if t == ""; t = el; else; t = ProgressClock.join(t, el); end
end
end


function markRunningDataset(obj, name)
%markRunningDataset  Mark and scroll to the Project-table row of the dataset the run is on.
if name == "" || isempty(obj.Project); return; end   % a step's start event names no dataset
idx = 0;
for i = 1:obj.Project.NumDatasets
    if string(obj.Project.Datasets(i).Name) == name
        idx = i; break
    end
end
if idx == 0 || idx == obj.RunningDatasetIdx; return; end
obj.RunningDatasetIdx = idx;
obj.highlightDatasetRow(ScrollRunning=true);
end
