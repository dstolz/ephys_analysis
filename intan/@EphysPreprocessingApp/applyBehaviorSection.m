function applyBehaviorSection(obj, B)
%applyBehaviorSection  Behavior section -> Project tab's panel.
B = EphysPipelineConfig.normalizeSection("Behavior", B);
obj.BehEnableCheckBox.Value = logical(B.Enabled);
obj.BehSearchDirsField.Value = char(strjoin(B.SearchDirs, "; "));
obj.setDropIfMember(obj.BehMatchDropDown, B.Match);
obj.BehMaxOffsetField.Value = B.MaxStartOffsetMin;
obj.BehOverwriteCheckBox.Value = logical(B.Overwrite);
end
