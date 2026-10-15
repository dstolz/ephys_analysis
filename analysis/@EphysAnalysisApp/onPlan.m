function T = onPlan(obj)
%onPlan  Which plot or figure runs on which ticked dataset, and why one is skipped (EphysAnalysisRunner.plan).
%   The table has a row per dataset and plot, then per dataset and figure
%   (Kind "figure", Source what it is drawn for), then per session plot;
%   the status bar counts the plot runs and the figure runs that will draw.
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
isFig = T.Kind == "figure";
msg = sprintf("Plan: %d of %d plot run(s)", nnz(T.Enabled & ~isFig), nnz(~isFig));
if any(isFig)
    msg = msg + sprintf(" and %d of %d figure run(s)", nnz(T.Enabled & isFig), nnz(isFig));
end
obj.setStatus(msg + " will draw.");
end
