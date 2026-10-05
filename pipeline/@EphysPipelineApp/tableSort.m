function s = tableSort(obj, id)
%tableSort  The remembered sort of one of the app's sortable tables.
%   S = obj.tableSort(ID) is a TableSort state (TableSort.none() when the
%   table has none). ID names the table: "Datasets" (Project), "Trials",
%   "Review" (units), "Cleanup" and "ArtSelection" (the Artifacts tab's
%   per-channel Selection table). A header click in one of them is
%   remembered (onTableSorted) and applied each time the app fills the
%   table again, so the sort holds for every dataset and, as the TableSorts
%   preference, the next session. Right-click the table to clear it
%   (clearTableSort).
arguments
    obj (1,1) EphysPipelineApp
    id (1,1) string
end
s = TableSort.none();
if isfield(obj.TableSorts, id)
    s = TableSort.fromPref(obj.TableSorts.(id));
end
end
