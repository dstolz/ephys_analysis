function onDatasetCellSelection(obj, evt)
%onDatasetCellSelection  Clicking a Project-table row makes its dataset the active one.
%   Rows map to datasets through DatasetIdx: sorting and the token filters
%   reorder and hide rows independently of obj.Project.Datasets.
if isempty(evt.Indices)
    return
end
T = obj.DatasetsTable.Data;
row = evt.Indices(1);
if ~istable(T) || row > height(T)
    return
end
obj.selectDataset(T.DatasetIdx(row), FromTable=true);
end
