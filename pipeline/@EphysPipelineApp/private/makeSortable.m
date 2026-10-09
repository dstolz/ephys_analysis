function makeSortable(obj, tbl, id)
%makeSortable  Let a header click sort table TBL; with ID, keep the sort (tableSort ID).
%   Without ID the table only sorts its display (a fresh fill of its Data
%   shows the app's own order again). With ID, a sortable-table id of
%   sortableTable, the click is remembered (onTableSorted), the app puts
%   each fill of the table in that order, and a right-click offers Clear sort.
arguments
    obj (1,1) EphysPipelineApp
    tbl (1,1) matlab.ui.control.Table
    id (1,1) string = ""
end
tbl.ColumnSortable = true;
if id == ""; return; end
tbl.DisplayDataChangedFcn = @(~, evt) obj.onTableSorted(id, evt);
tbl.ContextMenu = uicontextmenu(obj.Fig, "ContextMenuOpeningFcn", @(m, ~) obj.onTableSortMenu(m, id));
end
