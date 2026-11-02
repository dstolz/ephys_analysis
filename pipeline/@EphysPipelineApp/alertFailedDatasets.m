function alertFailedDatasets(obj, R)
%alertFailedDatasets  End a run that had failures: which datasets failed and why, and a way to the results and the log.
%   obj.alertFailedDatasets(R) reads the run's results R (Step, Dataset,
%   Status, Message, ...) and, when rows have a Status that starts with
%   "error", shows an alert
%       2 of 5 datasets failed:
%       recA (sorting: no GPU found)
%       recC (export: ...)
%   with Show results (the Run tab's results table), Show log (the Run
%   tab's log) and Close. At most six datasets are named; the rest are
%   counted. The first error of each dataset is the one named.
arguments
    obj (1,1) EphysPipelineApp
    R table
end
if isempty(R) || ~any(startsWith(R.Status, "error")); return; end
bad = R(startsWith(R.Status, "error"), :);
names = bad.Dataset;
names(names == "") = "(the whole run)";
[failed, first] = unique(names, 'stable');
nAll = numel(unique(R.Dataset(R.Dataset ~= ""), 'stable'));
nAll = max(nAll, numel(failed));
lines = strings(0, 1);
for k = 1:min(numel(failed), 6)
    msg = strtrim(strrep(string(bad.Message(first(k))), newline, " "));
    if strlength(msg) > 140; msg = extractBefore(msg, 138) + "..."; end
    status = strtrim(erase(string(bad.Status(first(k))), "error"));
    if msg == ""; msg = status; end
    lines(end+1, 1) = failed(k) + " (" + bad.Step(first(k)) + ": " + msg + ")"; %#ok<AGROW>
end
if numel(failed) > 6
    lines(end+1, 1) = sprintf("... and %d more: the Results table lists them.", numel(failed) - 6);
end
noun = "datasets";
if nAll == 1; noun = "dataset"; end
text = sprintf("%d of %d %s failed:", numel(failed), nAll, noun) + newline + strjoin(lines, newline);
AppDialog.alert(obj.Fig, text, "Run finished with errors", "Icon", "warning", ...
    "Options", ["Show results", "Show log", "Close"], "DefaultOption", 1, "CancelOption", 3, ...
    "CloseFcn", @(~, evt) goTo(obj, string(evt.SelectedOption)));
end


function goTo(obj, picked)
%goTo  The alert's buttons: the results table or the log of the Run tab.
if ~isvalid(obj) || isempty(obj.Fig) || ~isvalid(obj.Fig); return; end
if picked == "Show results"
    obj.selectTab(obj.TabRun);
    target = obj.RunResultsTable;
elseif picked == "Show log"
    obj.selectTab(obj.TabRun);
    target = obj.RunLogArea;
else
    return
end
try
    focus(target);
catch
end
end
