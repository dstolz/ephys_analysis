function syncTokenFilters(obj, tokenNames, values)
%syncTokenFilters  One filter dropdown per name-pattern token.
%   TOKENNAMES are the pattern's tokens, VALUES (datasets x tokens) their
%   parsed values ("-" = the name does not match). The dropdowns are
%   recreated only when the token set changes (a filter keeps its text by
%   token name); otherwise just their value lists are refreshed. Each
%   dropdown is editable: a typed value may hold wildcards (* ?) and several
%   comma-separated alternatives.
tokenNames = reshape(string(tokenNames), 1, []);
current = string.empty(1, 0);
if ~isempty(obj.NameTokenFilters)
    current = string({obj.NameTokenFilters.UserData});
end

if ~isequal(current, tokenNames)
    kept = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for k = 1:numel(obj.NameTokenFilters)
        kept(char(current(k))) = obj.NameTokenFilters(k).Value;
    end
    delete(obj.NameTokenFilterGrid.Children);
    obj.NameTokenFilters = matlab.ui.control.DropDown.empty;
    obj.NameTokenFilterGrid.ColumnWidth = [{'fit'}, repmat({'fit', 140}, 1, numel(tokenNames))];
    if ~isempty(tokenNames)
        uilabel(obj.NameTokenFilterGrid, "Text", "Filter:", "Tooltip", ...
            "Show only datasets whose name tokens match. Pick a value or type one; * and ? are wildcards, commas separate alternatives.");
    end
    for k = 1:numel(tokenNames)
        uilabel(obj.NameTokenFilterGrid, "Text", tokenNames(k), "HorizontalAlignment", "right");
        v = '(any)';
        if isKey(kept, char(tokenNames(k))); v = kept(char(tokenNames(k))); end
        obj.NameTokenFilters(k) = uidropdown(obj.NameTokenFilterGrid, ...
            "Items", {'(any)'}, "Editable", "on", "Value", '(any)', ...
            "UserData", char(tokenNames(k)), ...
            "Tooltip", "Filter by " + tokenNames(k) + ": * and ? are wildcards, commas separate alternatives.", ...
            "ValueChangedFcn", @(~,~) obj.refreshDatasetsTable());
        obj.NameTokenFilters(k).Value = v;
    end
end

for k = 1:numel(obj.NameTokenFilters)
    dd = obj.NameTokenFilters(k);
    v = dd.Value;
    items = [{'(any)'}, cellstr(unique(values(:, k)', 'stable'))];
    items = [items(1), sort(items(2:end))];
    dd.Items = items;
    dd.Value = v;   % a typed (non-item) value is kept by the editable dropdown
end
end
