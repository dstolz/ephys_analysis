function analysisCopySortEnded(obj, run, state)
%analysisCopySortEnded  A background sort ended: copy the files for the analysis app of the datasets that waited for it.
%   obj.analysisCopySortEnded(RUN, STATE) (pollKSRuns, for each run that
%   ended; STATE is "done", "error" or "canceled"). The datasets in
%   AnalysisCopyWaiting for the run's results folder are taken off the list:
%   after a finished sort they are copied (copyAnalysisFiles), after a failed
%   or stopped one they are not, and the Run log says so. Nothing happens for
%   a run no dataset waits for.
%
%   See also copyAnalysisFilesAfterRun, copyAnalysisFiles, pollKSRuns.
arguments
    obj (1,1) EphysPipelineApp
    run (1,1) struct
    state (1,1) string
end
if isempty(obj.AnalysisCopyWaiting); return; end
tag = "[analysis copy] ";
key = EphysDataset.pathKey(string(run.resultsDir));
hit = arrayfun(@(w) EphysDataset.pathKey(w.resultsDir) == key, obj.AnalysisCopyWaiting);
if ~any(hit); return; end
waiting = obj.AnalysisCopyWaiting(hit);
obj.AnalysisCopyWaiting(hit) = [];
ds = waiting(1).dataset;
for k = 2:numel(waiting)
    if ~any(ds == waiting(k).dataset); ds(end+1) = waiting(k).dataset; end %#ok<AGROW>
end
if state ~= "done"
    obj.runLog("%s", tag + strjoin([ds.Name], ", ") + ": not copied, its sort ended with " + state + ".");
    return
end
try
    obj.copyAnalysisFiles(ds);
catch ME
    obj.runLog("%s", tag + "not made: " + string(ME.message));
end
end
