function copyAnalysisFilesAfterRun(obj, pipe)
%copyAnalysisFilesAfterRun  A Run is over: copy the files for the analysis app of the datasets it made them for.
%   obj.copyAnalysisFilesAfterRun(PIPE) (runPipeline, with the AnalysisCopy
%   section on, for a Run that ran to its end and was not a dry run) copies
%   the datasets the Run processed (copyAnalysisFiles: the copy window's
%   settings), except
%     - a dataset with an error among its results, whose files may be
%       incomplete: it is left out, and the Run log says so;
%     - a dataset whose background sort has not ended (its sorting row is
%       "launched" or "queued"): its copy waits for the end of that sort
%       (analysisCopySortEnded, AnalysisCopyWaiting). The wait is not kept
%       when the app is closed.
%
%   See also copyAnalysisFiles, analysisCopySortEnded.
arguments
    obj (1,1) EphysPipelineApp
    pipe (1,1) EphysPipeline
end
tag = "[analysis copy] ";
R = pipe.Results;
ds = pipe.Project.Datasets(pipe.DatasetIdx);
ready = true(1, numel(ds));
for k = 1:numel(ds)
    mine = R(R.Dataset == string(ds(k).Name), :);
    if any(startsWith(mine.Status, "error"))
        obj.runLog("%s", tag + ds(k).Name + ": not copied, a step ended with an error.");
        ready(k) = false;
        continue
    end
    pending = mine(mine.Step == "sorting" & ismember(mine.Status, ["launched" "queued"]), :);
    if ~isempty(pending)
        for r = 1:height(pending)
            obj.AnalysisCopyWaiting(end+1) = struct('dataset', ds(k), 'resultsDir', pending.Output(r));
        end
        obj.runLog("%s", tag + ds(k).Name + ": waits for its sort to end.");
        ready(k) = false;
    end
end
if any(ready)
    obj.copyAnalysisFiles(ds(ready));
end
end
