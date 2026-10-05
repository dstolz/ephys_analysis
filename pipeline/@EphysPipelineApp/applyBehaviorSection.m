function applyBehaviorSection(obj, B)
%applyBehaviorSection  Behavior section -> Project tab's panel.
B = EphysPipelineConfig.normalizeSection("Behavior", B);
obj.BehEnableCheckBox.Value = logical(B.Enabled);
obj.BehSearchCheckBox.Value = logical(B.Search);
obj.BehSearchDirsField.Value = char(strjoin(B.SearchDirs, "; "));
obj.setDropIfMember(obj.BehMatchDropDown, B.Match, "Behavior.Match");
obj.setControlValue(obj.BehMaxOffsetField, B.MaxStartOffsetMin, "Behavior.MaxStartOffsetMin");
obj.BehOverwriteCheckBox.Value = logical(B.Overwrite);
obj.BehWriteFileCheckBox.Value = logical(B.WriteFile);
obj.TrialsPairCheckBox.Value = logical(B.PairTrials);
obj.TrialsAutoApproveCheckBox.Value = logical(B.AutoApprove);
L = obj.TrialsLinesTable.Data;
names = string.empty(0, 1);
if istable(L); names = string(L.Name); end
obj.setTrialsLineItems(names, B.TrialLine);
end
