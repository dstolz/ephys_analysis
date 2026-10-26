function onDatasetsTableClicked(obj, evt)
%onDatasetsTableClicked  A click on a Project-table Tags cell: tag that one dataset.
%   The table's ClickedFcn, so every click counts (a cell selected already
%   too); clicks on other cells are onDatasetCellSelection's alone. The
%   row's dataset becomes the active one, then the tag dialog opens on it
%   in single mode (onEditTags), never on the ticked datasets.
%   EVT.InteractionInformation's Row and Column are the cell in Data,
%   whatever the header sort shows; rows map to datasets through
%   DatasetIdx.
%
%   See also onEditTags, onDatasetCellSelection, refreshDatasetsTable.
info = evt.InteractionInformation;
if isempty(info.Row) || isempty(info.Column); return; end
T = obj.DatasetsTable.Data;
if ~istable(T) || info.Row > height(T) || info.Column > width(T) || T.Properties.VariableNames{info.Column} ~= "Tags"
    return
end
idx = T.DatasetIdx(info.Row);
if idx ~= obj.SelectedDatasetIdx
    obj.selectDataset(idx, FromTable=true);
end
obj.onEditTags(idx);
end
