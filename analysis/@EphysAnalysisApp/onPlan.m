function T = onPlan(obj)
%onPlan  Which figure runs on which ticked dataset, and why one is skipped (EphysAnalysisRunner.plan).
%   The table has a row per dataset and figure (Kind "figure", Source what
%   it is drawn for), then per session figure and facet (Dataset
%   "sessions: <facet>"); the status bar counts the figure runs, and the
%   session figure runs, that will draw. A figure that cannot run has a
%   "What to do" column beside its Reason (figureSkipRemedy), and a double
%   click on a row shows the figure on the Figures tab (onIssueActivated).
%   With no project scanned an alert says so, with a "Go to Data tab"
%   button; with no dataset ticked it takes the Data tab (AppDialog,
%   stopAction).
T = table();
if isempty(obj.Runner)
    obj.setStatus("No project is loaded: choose the project root on the Data tab and press Scan.");
    AppDialog.alertNoProject(obj.Fig, @() obj.selectTab(obj.TabData), Where="Data");
    return
end
obj.Runner.Config = obj.gatherConfig();
idx = obj.tickedDatasetIndices();
if isempty(idx)
    stopAction(obj, "Plan", "No dataset is ticked to run. On the Data tab, tick Run for at least one dataset.", Tab=obj.TabData);
    return
end
obj.setStatus("Planning ...");
drawnow limitrate;
T = obj.Runner.plan(Datasets=idx);
obj.IssuesTable.Data = withSubjectDate(obj, addRemedy(T));
across = startsWith(T.Dataset, "sessions: ");
msg = sprintf("Plan: %d of %d figure run(s)", nnz(T.Enabled & ~across), nnz(~across));
if any(across)
    msg = msg + sprintf(" and %d of %d session figure run(s)", nnz(T.Enabled & across), nnz(across));
end
obj.setStatus(msg + " will draw.");
end


function T = addRemedy(T)
%addRemedy  A "What to do" column after Reason: figureSkipRemedy of each reason that is not empty.
what = strings(height(T), 1);
for k = reshape(find(T.Reason ~= ""), 1, [])
    what(k) = figureSkipRemedy(T.Reason(k));
end
T = addvars(T, what, 'After', "Reason", 'NewVariableNames', "WhatToDo");
end
