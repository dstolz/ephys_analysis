function onNameTokensChanged(obj)
%onNameTokensChanged  Name pattern or a token-column tick changed.
%   Rebuilds the token checkboxes (ticks kept by token name) when the
%   pattern parses; an invalid pattern keeps the previous checkboxes and is
%   reported next to them (and by validate).
checks = obj.NameTokenChecks;
current = string({checks.Text});
shown = current(logical([checks.Value]));
try
    [~, names] = parseNameTokens("", string(obj.NamePatternField.Value));
catch
    names = [];   % refreshDatasetsTable shows the pattern error
end
if isstring(names) && ~isequal(names, reshape(current, 1, []))
    obj.setNameTokenChecks(names, shown);
end
obj.refreshDatasetsTable();
obj.onConfigChanged();
end
