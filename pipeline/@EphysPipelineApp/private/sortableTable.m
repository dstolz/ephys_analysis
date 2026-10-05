function tbl = sortableTable(obj, id)
%sortableTable  The uitable of sortable-table id ID (see tableSort).
switch string(id)
    case "Datasets";     tbl = obj.DatasetsTable;
    case "Trials";       tbl = obj.TrialsTable;
    case "Review";       tbl = obj.ReviewUnitsTable;
    case "Cleanup";      tbl = obj.CleanupTable;
    case "ArtSelection"; tbl = obj.ArtSelectionTable;
    otherwise
        error('EphysPipelineApp:UnknownTable', 'No sortable table "%s".', id);
end
end
