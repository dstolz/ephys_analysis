function markTransferResult(obj, X, b)
%markTransferResult  Restate the Run tab's "transfer" row of batch B's dataset.
%   obj.markTransferResult(X, B): the dataset's row (Output: its folder in
%   the destination) takes the status and message X.statusOf gives now, in
%   the last Run's results (RunResults), in the table when it shows a Run's
%   rows (while the Run that made X is under way: the pipeline's Results,
%   which it restates itself) and in the run diagram's results once the
%   Run is over. A row no longer there (a later Run replaced the results)
%   is left alone. See markKSResult, the same for background sorts.
[st, msg, folder] = X.statusOf(b.Key);
if st == ""; return; end
restate = @(T) EphysPipeline.restateResult(T, "transfer", b.Dataset, folder, st, msg, 0);
running = obj.RunActive && ~isempty(obj.Pipe) && isvalid(obj.Pipe) && ~isempty(obj.Pipe.Transfer) && obj.Pipe.Transfer == X;
obj.RunResults = restate(obj.RunResults);
t = obj.RunResultsTable;
if ~isempty(t) && isvalid(t) && istable(t.Data) ...
        && all(ismember(["Step" "Dataset" "Status" "Message" "Output" "Seconds"], t.Data.Properties.VariableNames))
    % not a plan's table (Plan shows Key and Note instead)
    if running
        obj.showRunResults(obj.Pipe.Results);
    else
        obj.showRunResults(restate(t.Data));
    end
end
if ~running && isfield(obj.RunDiagram, 'results') && istable(obj.RunDiagram.results)
    obj.RunDiagram.results = restate(obj.RunDiagram.results);
end
end
