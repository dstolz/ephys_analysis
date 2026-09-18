function B = gatherBehaviorSection(obj)
%gatherBehaviorSection  Behavior section from the Project tab's panel.
B = obj.Config.Behavior;
B.Enabled = logical(obj.BehEnableCheckBox.Value);
dirs = strtrim(split(string(obj.BehSearchDirsField.Value), ";"));
B.SearchDirs = reshape(dirs(dirs ~= ""), 1, []);
B.Match = string(obj.BehMatchDropDown.Value);
B.MaxStartOffsetMin = obj.BehMaxOffsetField.Value;
B.Overwrite = logical(obj.BehOverwriteCheckBox.Value);
B.WriteFile = logical(obj.BehWriteFileCheckBox.Value);
% Trial pairing (Trials tab; line polarity is Signals.InvertedLines, and the
% cuts that resolve a count mismatch belong to the dataset manifest).
B.PairTrials = logical(obj.TrialsPairCheckBox.Value);
B.AutoApprove = logical(obj.TrialsAutoApproveCheckBox.Value);
B.TrialLine = strtrim(string(obj.TrialsLineDropDown.Value));
end
