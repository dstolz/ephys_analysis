function clearTableSort(obj, id)
%clearTableSort  Forget sortable table ID's sort and show its rows in the app's own order.
%   The preference is saved at once. The app's order: the project's datasets
%   (Project), trial order (Trials), cluster id (Review), Remove rows first,
%   largest first (Clean up), the chosen method's statistic, highest first
%   (the Artifacts tab's per-channel Selection table).
arguments
    obj (1,1) EphysPipelineApp
    id (1,1) string
end
if isfield(obj.TableSorts, id)
    obj.TableSorts = rmfield(obj.TableSorts, id);
end
saveTableSorts(obj);
switch id
    case "Datasets";     obj.refreshDatasetsTable();
    case "Trials";       obj.refreshTrialsTable();
    case "Review";       obj.showReviewUnits();
    case "Cleanup";      obj.refreshCleanupTable();
    case "ArtSelection"; obj.measureArtifactSelection();
    case "Copy";         clearCopySort(obj);
    case "RunResults";   clearRunResultsSort(obj);
    case "SignalsPlan";  obj.refreshStepPlan("signals");
    case "ExportPlan";   obj.refreshStepPlan("export");
    case "AnalysisPlan"; obj.refreshStepPlan("analysis");
end
end


function clearRunResultsSort(obj)
%clearRunResultsSort  Show the Run tab's results as the pipeline lists them (the Order column).
T = obj.RunResultsTable.Data;
if istable(T) && ismember("Order", string(T.Properties.VariableNames))
    obj.showRunResults(sortrows(T, "Order"));
end
end


function clearCopySort(obj)
%clearCopySort  Put the Copy tab's sessions back in time order, as Find sessions lists them.
if isempty(obj.CopyJob) && height(obj.CopySessions) > 1
    T = obj.CopySessions;
    t = T.RecordingTime;
    t(isnat(t)) = T.EpsychTime(isnat(t));
    [~, o] = sort(t);
    obj.CopySessions = T(o, :);
    obj.CopyTicked = obj.CopyTicked(o);
    obj.CopyStatus = obj.CopyStatus(o);
    obj.CopyMessage = obj.CopyMessage(o);
end
obj.refreshCopyTable();
end
