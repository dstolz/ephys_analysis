function setNameTokenChecks(obj, tokenNames, shown)
%setNameTokenChecks  One "show as column" checkbox per name-pattern token.
delete(obj.NameTokenGrid.Children);
obj.NameTokenChecks = matlab.ui.control.CheckBox.empty;
obj.NameTokenGrid.ColumnWidth = [{'fit'}, repmat({'fit'}, 1, numel(tokenNames))];
uilabel(obj.NameTokenGrid, "Text", "Columns:", ...
    "Tooltip", "Tokens shown as columns in the datasets table.");
for k = 1:numel(tokenNames)
    obj.NameTokenChecks(k) = uicheckbox(obj.NameTokenGrid, "Text", tokenNames(k), ...
        "Value", any(shown == tokenNames(k)), ...
        "ValueChangedFcn", @(~,~) obj.onNameTokensChanged());
end
end
