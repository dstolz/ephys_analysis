function onPlan(obj)
%onPlan  Show what a run would do (writes nothing) on the Run tab.
if isempty(obj.Project) || obj.Project.NumDatasets == 0
    uialert(obj.Fig, "Scan a project root first (Project tab).", "Plan");
    return
end
try
    pipe = obj.buildPipeline();
    T = pipe.plan();
catch ME
    uialert(obj.Fig, "Plan failed:" + newline + string(ME.message), "Plan");
    return
end
obj.Tabs.SelectedTab = obj.TabRun;
obj.RunResultsTable.ColumnName = {'Step', 'Dataset', 'Key', 'Output', 'Status', 'Note'};
obj.RunResultsTable.Data = T;
nBlock = nnz(startsWith(T.Status, "duplicate") | startsWith(T.Status, "error"));
obj.setStatus(sprintf("Plan: %d row(s), %d blocking.", height(T), nBlock), "");
end
