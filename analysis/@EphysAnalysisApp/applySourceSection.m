function applySourceSection(obj, S)
%applySourceSection  Show config Source on the Data tab.
obj.SourceModeDropDown.Value = char(S.Mode);
obj.RootField.Value = char(S.Root);
obj.OutputRootField.Value = char(S.OutputRoot);
obj.NamePatternField.Value = char(S.NamePattern);
if ismember(S.Recordings, string(obj.RecordingsDropDown.ItemsData))
    obj.RecordingsDropDown.Value = S.Recordings;
end
if isempty(S.Folders)
    obj.FoldersArea.Value = {''};
else
    obj.FoldersArea.Value = cellstr(S.Folders(:));
end
obj.syncSourceEnable();
end
