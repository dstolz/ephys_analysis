function onDatasetNoteClicked(obj, evt)
%onDatasetNoteClicked  A click on the Data tab's ✎ column: its dataset becomes the active one, and the notepad opens on it.
%   A click on a Variables cell opens the variable dialog on that dataset
%   alone (onEditVariables).
%   Every click counts (the table's ClickedFcn), so a cell selected already
%   opens the notepad again; clicks elsewhere are onDatasetCellSelection's.
%   EVT.InteractionInformation's Row and Column are the cell in Data,
%   whatever the sort shows.
%
%   See also onNoteButton, onDatasetCellSelection, refreshDatasetsTable.
info = evt.InteractionInformation;
if isempty(info.Row) || isempty(info.Column); return; end
T = obj.DatasetsTable.Data;
if ~istable(T) || info.Row > height(T) || info.Column > width(T); return; end
col = string(T.Properties.VariableNames{info.Column});
idx = T.Idx(info.Row);   % rows map to datasets through Idx: the table may be sorted
if col == "Vars"   % the Variables column
    obj.onEditVariables(idx);
    return
elseif col ~= "Note"
    return
end
if idx ~= obj.ActiveIdx
    obj.selectDataset(idx);
end
obj.onNoteButton("dataset");
end
