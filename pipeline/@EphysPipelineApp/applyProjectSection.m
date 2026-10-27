function applyProjectSection(obj, P)
%applyProjectSection  Project section -> Project tab (root, recursive, save script,
%   output root, tags for new datasets, name pattern + token columns, ticks).
P = EphysPipelineConfig.normalizeSection("Project", P);
obj.RootPathField.Value   = char(P.Root);
obj.RecursiveCheckBox.Value = P.Recursive;
obj.SaveScriptCheckBox.Value = P.SaveScript;
obj.OutputRootField.Value = char(P.OutputRoot);
obj.AutoTagCheckBox.Value = P.AutoTag;
obj.AutoTagField.Value = char(TagSet.toText(TagSet.parse(P.NewDatasetTags), TagSet.DisplayDelimiter));
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
