function S = gatherProbeSection(obj)
%gatherProbeSection  Probe section from the Probe tab.
S = obj.Config.Probe;
S.DefaultProbeFile       = string(strtrim(obj.ProbeDefaultField.Value));
S.WriteDefaultToManifest = logical(obj.ProbeWriteDefaultCheckBox.Value);
S.AutoAssign             = logical(obj.ProbeAutoAssignCheckBox.Value);
rules = obj.ProbeRulesTable.Data;
S.RuleSubjects = reshape(strtrim(string(rules(:, 1))), 1, []);
S.RuleProbes   = reshape(strtrim(string(rules(:, 2))), 1, []);
end
