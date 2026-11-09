function onDatasetsTableClicked(obj, evt)
%onDatasetsTableClicked  A click on a Project-table Tags or Variables cell: edit that one dataset's.
%   The table's ClickedFcn, so every click counts (a cell selected already
%   too); clicks on other cells are onDatasetCellSelection's alone. The
%   row's dataset becomes the active one, then the tag dialog opens on it
%   in single mode (onEditTags), or the variable dialog (onEditVariables),
%   never on the ticked datasets.
%   EVT.InteractionInformation's Row and Column are the cell in Data,
%   whatever the header sort shows; rows map to datasets through
%   DatasetIdx.
%
%   See also onEditTags, onEditVariables, onDatasetCellSelection, refreshDatasetsTable.
info = evt.InteractionInformation;
if isempty(info.Row) || isempty(info.Column); return; end
T = obj.DatasetsTable.Data;
if ~istable(T) || info.Row > height(T) || info.Column > width(T)
    return
end
col = string(T.Properties.VariableNames{info.Column});
if ~ismember(col, ["Tags" "Vars"]); return; end   % Vars: the Variables column
idx = T.DatasetIdx(info.Row);
if idx ~= obj.SelectedDatasetIdx
    obj.selectDataset(idx, FromTable=true);
end
if col == "Vars"
    obj.onEditVariables(idx);
else
    obj.onEditTags(idx);
end
end
