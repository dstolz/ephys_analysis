function order = trialsColumnOrder(obj, shown)
%trialsColumnOrder  The Trials-table column order to remember.
%   ORDER = obj.trialsColumnOrder() is TrialsColumnOrder updated with the
%   order on screen when a column was dragged since the last refresh.
%   ORDER = obj.trialsColumnOrder(SHOWN) updates it with SHOWN (table
%   variables in display order) instead. Remembered columns that are not
%   shown now (a parameter this dataset's session lacks) keep their place
%   right after the column they followed, so the order holds across
%   datasets.
arguments
    obj (1,1) EphysPreprocessingApp
    shown (1,:) string = draggedOrder(obj.TrialsTable)
end
order = shown;
old = obj.TrialsColumnOrder;
for k = find(~ismember(old, shown))
    at = find(ismember(order, old(1:k-1)), 1, 'last');
    if isempty(at); at = 0; end
    order = [order(1:at), old(k), order(at+1:end)];
end
end


function shown = draggedOrder(tbl)
%draggedOrder  Table variables in display order; empty unless dragged since the last refresh.
shown = string.empty(1, 0);
T = tbl.Data;
dco = tbl.DisplayColumnOrder;
if istable(T) && width(T) > 0 && numel(dco) == width(T)
    shown = string(T.Properties.VariableNames(dco));
end
end
