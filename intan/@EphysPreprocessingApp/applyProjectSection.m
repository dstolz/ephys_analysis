function applyProjectSection(obj, P)
%applyProjectSection  Project section -> Project tab (root, output root,
%   name pattern + token columns, ticks).
P = EphysPipelineConfig.normalizeSection("Project", P);
obj.RootPathField.Value   = char(P.Root);
obj.OutputRootField.Value = char(P.OutputRoot);
obj.NamePatternField.Value = char(P.NamePattern);
try
    [~, names] = parseNameTokens("", P.NamePattern);
catch
    names = string.empty(1, 0);
end
obj.setNameTokenChecks(names, EphysPipelineConfig.parseTokenColumns(P.TokenColumns));
obj.refreshDatasetsTable();
obj.applySelectionToTable(P);
end
