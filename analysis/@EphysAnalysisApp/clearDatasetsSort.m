function clearDatasetsSort(obj)
%clearDatasetsSort  Forget the datasets table's sort: the rows come in the order the scan found them.
arguments
    obj (1,1) EphysAnalysisApp
end
obj.DatasetsSort = TableSort.none();
obj.refreshDatasetsTable();
end
