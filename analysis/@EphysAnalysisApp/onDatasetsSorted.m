function onDatasetsSorted(obj, evt)
%onDatasetsSorted  Remember a header click in the Data tab's datasets table.
%   The column and direction clicked (TableSort.fromEvent) become
%   DatasetsSort, which refreshDatasetsTable applies each time it fills the
%   table, so the sort holds through a tick or a new active dataset. An edit
%   (a Run tick) is not a sort and changes nothing.
arguments
    obj (1,1) EphysAnalysisApp
    evt
end
obj.DatasetsSort = TableSort.fromEvent(obj.DatasetsTable, evt, obj.DatasetsSort);
end
