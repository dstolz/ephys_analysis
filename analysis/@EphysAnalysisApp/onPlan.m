function T = onPlan(obj)
%onPlan  Which plot runs on which ticked dataset, and why one is skipped (EphysAnalysisRunner.plan).
T = table();
if isempty(obj.Runner)
    obj.setStatus("Scan first (Data tab).");
    return
end
obj.Runner.Config = obj.gatherConfig();
idx = obj.tickedDatasetIndices();
if isempty(idx)
    obj.setStatus("No dataset is ticked to run (Data tab).");
    return
end
obj.setStatus("Planning ...");
drawnow limitrate;
T = obj.Runner.plan(Datasets=idx);
obj.IssuesTable.Data = T;
obj.setStatus(sprintf("Plan: %d of %d plot run(s) will draw.", nnz(T.Enabled), height(T)));
end
