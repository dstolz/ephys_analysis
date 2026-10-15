function T = onPlan(obj)
%onPlan  Which figure runs on which ticked dataset, and why one is skipped (EphysAnalysisRunner.plan).
%   The table has a row per dataset and figure (Kind "figure", Source what
%   it is drawn for), then per session figure and facet (Dataset
%   "sessions: <facet>"); the status bar counts the figure runs, and the
%   session figure runs, that will draw.
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
obj.IssuesTable.Data = withSubjectDate(obj, T);
across = startsWith(T.Dataset, "sessions: ");
msg = sprintf("Plan: %d of %d figure run(s)", nnz(T.Enabled & ~across), nnz(~across));
if any(across)
    msg = msg + sprintf(" and %d of %d session figure run(s)", nnz(T.Enabled & across), nnz(across));
end
obj.setStatus(msg + " will draw.");
end
