function markKSResult(obj, name, output, status, message, addSeconds)
%markKSResult  Restate the Run tab's result row of a background Kilosort4 run.
%   obj.markKSResult(NAME, OUTPUT, STATUS, MESSAGE, ADDSECONDS): the
%   "sorting" row of dataset NAME whose Output is OUTPUT (the run's results
%   dir) takes STATUS ("launched", "done", "error", "canceled") and
%   MESSAGE, and ADDSECONDS (default 0) goes onto its Seconds. The row is
%   restated in the last Run's results (RunResults, kept while a Plan fills
%   the results table), in the running pipeline's Results (so the table the
%   Run shows at its end has it too), in the table when it shows a Run's
%   rows (while a Run is under way it takes the pipeline's Results at once,
%   with the rows added since the last progress event) and in the run
%   diagram's counts once the Run is over. A row no longer there (a later
%   Run replaced the results) is left alone.
%
%   See also EphysPipeline.restateResult, pollKSRuns, onPipelineProgress.

if nargin < 6; addSeconds = 0; end
restate = @(T) EphysPipeline.restateResult(T, "sorting", name, output, status, message, addSeconds);
obj.RunResults = restate(obj.RunResults);
running = obj.RunActive && ~isempty(obj.Pipe) && isvalid(obj.Pipe);
if running
    obj.Pipe.updateResult("sorting", name, output, status, message, addSeconds);
end
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
    obj.RunDiagram.results = restate(obj.RunDiagram.results);   % a Run under way takes its results from the pipeline
    obj.refreshRunDiagram();
end
end
