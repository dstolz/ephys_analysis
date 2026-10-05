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
end
end
