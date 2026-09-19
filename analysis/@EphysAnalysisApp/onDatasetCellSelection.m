function onDatasetCellSelection(obj, evt)
%onDatasetCellSelection  A click on a datasets-table row (not its Run box) makes it active.
if isempty(evt) || isempty(evt.Indices); return; end
row = evt.Indices(1, 1);
col = evt.Indices(1, 2);
if col == 1; return; end
if row ~= obj.ActiveIdx
    obj.selectDataset(row);
end
end
