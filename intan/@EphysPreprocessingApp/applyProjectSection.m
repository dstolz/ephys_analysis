function applyProjectSection(obj, P)
%applyProjectSection  Project section -> Project tab (root, output root, ticks).
P = EphysPipelineConfig.normalizeSection("Project", P);
obj.RootPathField.Value   = char(P.Root);
obj.OutputRootField.Value = char(P.OutputRoot);
obj.applySelectionToTable(P);
end
