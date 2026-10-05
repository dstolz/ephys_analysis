function item = sortMenuItem(obj, menu, id)
%sortMenuItem  Add Clear sort to MENU, the context menu of sortable table ID.
%   Its text names the sort it clears ("Clear sort (SNR, descending)"); off
%   when the table has none.
s = obj.tableSort(id);
txt = "Clear sort";
if TableSort.isSorted(s)
    txt = txt + " (" + columnLabel(sortableTable(obj, id), string(s.column)) + ", " + s.direction + "ing)";
end
item = uimenu(menu, "Text", txt, "Separator", ~isempty(menu.Children), ...
    "Enable", matlab.lang.OnOffSwitchState(TableSort.isSorted(s)), ...
    "MenuSelectedFcn", @(~,~) obj.clearTableSort(id));
end


function name = columnLabel(tbl, column)
%columnLabel  The header shown for COLUMN, a table variable or a header.
%   A table variable is named by its header when the table sets one header
%   per column, else by itself, without a Param_ / Token_ prefix.
name = column;
D = tbl.Data;
if ~istable(D)
    return
end
headers = string(tbl.ColumnName);
k = find(string(D.Properties.VariableNames) == column, 1);
if ~isempty(k) && numel(headers) == width(D) && headers(k) ~= ""
    name = headers(k);
else
    name = regexprep(column, '^(Param|Token)_', '');
end
end
