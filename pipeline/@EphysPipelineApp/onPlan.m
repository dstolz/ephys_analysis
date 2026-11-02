function onPlan(obj)
%onPlan  Show what a run would do (writes nothing) on the Run tab: the Show plan button.
%   Without a scanned project, the one "No project is loaded" alert; a plan
%   that cannot be made says why and what to try (reportFailure).
if isempty(obj.Project) || obj.Project.NumDatasets == 0
    obj.alertNoProject("Show plan");
    return
end
try
    pipe = obj.buildPipeline();
    T = pipe.plan();
catch ME
    obj.reportFailure("Show plan", "work out the plan", "", ME, "fix what the message names, then press Show plan again");
    return
end
obj.selectTab(obj.TabRun);
obj.showRunResults(T);
nBlock = nnz(startsWith(T.Status, "duplicate") | startsWith(T.Status, "error"));
obj.setStatus(sprintf("Plan: %d row(s), %d blocking.", height(T), nBlock), "");
end
