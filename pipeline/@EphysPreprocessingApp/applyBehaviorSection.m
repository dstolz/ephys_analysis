function applyBehaviorSection(obj, B)
%applyBehaviorSection  Behavior section -> Project tab's panel.
B = EphysPipelineConfig.normalizeSection("Behavior", B);
obj.BehEnableCheckBox.Value = logical(B.Enabled);
obj.BehSearchDirsField.Value = char(strjoin(B.SearchDirs, "; "));
obj.setDropIfMember(obj.BehMatchDropDown, B.Match);
obj.BehMaxOffsetField.Value = B.MaxStartOffsetMin;
obj.BehOverwriteCheckBox.Value = logical(B.Overwrite);
obj.BehWriteFileCheckBox.Value = logical(B.WriteFile);
obj.TrialsPairCheckBox.Value = logical(B.PairTrials);
L = obj.TrialsLinesTable.Data;
names = string.empty(0, 1);
if istable(L); names = string(L.Line); end
obj.setTrialsLineItems(names, B.TrialLine);
end
