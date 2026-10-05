function onTableSorted(obj, id, evt)
%onTableSorted  Remember a header click in sortable table ID (its DisplayDataChangedFcn).
%   The column clicked and the direction shown (TableSort.fromEvent) become
%   the table's sort (TableSorts) and are saved as a preference at once.
%   The table already shows the click; the app applies the sort each time
%   it fills the table again (tableSort). An edit is not a sort and changes
%   nothing.
arguments
    obj (1,1) EphysPipelineApp
    id (1,1) string
    evt
end
prev = obj.tableSort(id);
s = TableSort.fromEvent(sortableTable(obj, id), evt, prev);
if isequal(s, prev)
    return
end
obj.TableSorts.(id) = s;
saveTableSorts(obj);
end
