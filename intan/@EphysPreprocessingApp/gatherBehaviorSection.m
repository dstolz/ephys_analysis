function B = gatherBehaviorSection(obj)
%gatherBehaviorSection  Behavior section from the Project tab's panel.
B = obj.Config.Behavior;
B.Enabled = logical(obj.BehEnableCheckBox.Value);
dirs = strtrim(split(string(obj.BehSearchDirsField.Value), ";"));
B.SearchDirs = reshape(dirs(dirs ~= ""), 1, []);
B.Match = string(obj.BehMatchDropDown.Value);
B.MaxStartOffsetMin = obj.BehMaxOffsetField.Value;
B.Overwrite = logical(obj.BehOverwriteCheckBox.Value);
end
