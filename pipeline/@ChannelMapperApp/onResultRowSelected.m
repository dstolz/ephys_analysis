function onResultRowSelected(obj, evt)
%onResultRowSelected  A row of the result table was selected: select its site.
%   With SelectionType 'row' the event has one index row per column, so
%   the row is unique(evt.Indices(:, 1)). Ignored while applySelection
%   sets the table's selection itself.
if obj.Syncing || isempty(evt.Indices)
    return
end
rows = unique(evt.Indices(:, 1));
obj.select("row", rows(1));
end
