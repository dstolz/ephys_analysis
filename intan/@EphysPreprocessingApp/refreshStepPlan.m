function refreshStepPlan(obj, step)
%refreshStepPlan  Fill a step tab's targets table from the pipeline plan.
arguments
    obj (1,1) EphysPreprocessingApp
    step (1,1) string
end
switch step
    case "signals"; tbl = obj.ConvTargetsTable;
    case "export";  tbl = obj.ExpTargetsTable;
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
    tbl.Data = T(:, {'Dataset', 'Output', 'Status', 'Note'});
else
    tbl.Data = T(:, {'Step', 'Dataset', 'Output', 'Status', 'Note'});
end
end
