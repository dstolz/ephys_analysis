function onDatasetCellSelection(obj, evt)
%onDatasetCellSelection  A click on a datasets-table row (not its Run box) makes its dataset active.
if isempty(evt) || isempty(evt.Indices); return; end
row = evt.Indices(1, 1);
col = evt.Indices(1, 2);
if col == 1; return; end
T = obj.DatasetsTable.Data;
if ~istable(T) || row > height(T); return; end
idx = T.Idx(row);   % rows map to datasets through Idx: the table may be sorted
if idx ~= obj.ActiveIdx
    obj.selectDataset(idx);
end
end
