function markKSResult(obj, name, output, status, message, addSeconds)
%markKSResult  Restate the Run tab's result row of a background Kilosort4 run.
%   obj.markKSResult(NAME, OUTPUT, STATUS, MESSAGE, ADDSECONDS): the
%   "sorting" row of dataset NAME whose Output is OUTPUT (the run's results
%   dir) takes STATUS ("launched", "done", "error", "cancelled") and
%   MESSAGE, and ADDSECONDS (default 0) goes onto its Seconds. The row is
%   restated in the last Run's results (RunResults, kept while a Plan fills
%   the results table), in the table when it shows them, in the running
%   pipeline's Results (so the table the Run shows at its end has it too)
%   and in the run diagram's counts once the Run is over. A row no longer
%   there (a later Run replaced the results) is left alone.
%
%   See also EphysPipeline.restateResult, pollKSRuns.

if nargin < 6; addSeconds = 0; end
restate = @(T) EphysPipeline.restateResult(T, "sorting", name, output, status, message, addSeconds);
obj.RunResults = restate(obj.RunResults);
t = obj.RunResultsTable;
if ~isempty(t) && isvalid(t) && istable(t.Data) ...
        && all(ismember(["Step" "Dataset" "Status" "Message" "Output" "Seconds"], t.Data.Properties.VariableNames))
    t.Data = restate(t.Data);   % not a plan's table (Plan shows Key and Note instead)
end
if obj.RunActive && ~isempty(obj.Pipe) && isvalid(obj.Pipe)
    obj.Pipe.updateResult("sorting", name, output, status, message, addSeconds);
elseif isfield(obj.RunDiagram, 'results') && istable(obj.RunDiagram.results)
    obj.RunDiagram.results = restate(obj.RunDiagram.results);   % a Run under way takes its results from the pipeline
    obj.refreshRunDiagram();
end
end
