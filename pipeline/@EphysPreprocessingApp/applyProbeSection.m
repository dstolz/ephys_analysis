function applyProbeSection(obj, S)
%applyProbeSection  Probe section -> Probe tab.
S = EphysPipelineConfig.normalizeSection("Probe", S);
obj.ProbeDefaultField.Value = char(S.DefaultProbeFile);
obj.ProbeWriteDefaultCheckBox.Value = logical(S.WriteDefaultToManifest);
obj.ProbeAutoAssignCheckBox.Value = logical(S.AutoAssign);
n = min(numel(S.RuleSubjects), numel(S.RuleProbes));
obj.ProbeRulesTable.Data = cellstr([S.RuleSubjects(1:n); S.RuleProbes(1:n)].');
obj.ProbeRulesTable.UserData = [];
end
