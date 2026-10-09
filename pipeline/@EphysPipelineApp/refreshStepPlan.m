function refreshStepPlan(obj, step)
%refreshStepPlan  Fill a step tab's targets table from the pipeline plan.
%   The table gets Subject and Date columns after Dataset, and its rows come in
%   the order of the remembered header click (tableSort SignalsPlan,
%   ExportPlan or AnalysisPlan).
arguments
    obj (1,1) EphysPipelineApp
    step (1,1) string
end
switch step
    case "signals";  tbl = obj.ConvTargetsTable;  id = "SignalsPlan";  outputLabel = "Output file";
    case "export";   tbl = obj.ExpTargetsTable;   id = "ExportPlan";   outputLabel = "Output file";
    case "analysis"; tbl = obj.AnaTargetsTable;   id = "AnalysisPlan"; outputLabel = "Output";
    otherwise; return
end
if isempty(tbl) || ~isvalid(tbl); return; end
if obj.RunActive || isempty(obj.Project) || obj.Project.NumDatasets == 0
    tbl.Data = {};
    return
end
try
    pipe = obj.buildPipeline();
    T = pipe.plan(Steps=step);
catch
    tbl.Data = {};
    return
end
if step == "signals"
    T = T(:, {'Dataset', 'Output', 'Status', 'Note'});
else
    T = T(:, {'Step', 'Dataset', 'Output', 'Status', 'Note'});
end
[T, tbl.ColumnName, tbl.ColumnWidth] = identityTable(obj, id, T, outputLabel);
tbl.Data = T;
end
