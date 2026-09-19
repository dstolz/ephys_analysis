function syncSourceEnable(obj)
%syncSourceEnable  Project fields for a project source, the folder list for folders.
project = string(obj.SourceModeDropDown.Value) == "project";
on = matlab.lang.OnOffSwitchState(project);
off = matlab.lang.OnOffSwitchState(~project);
set([obj.RootField obj.OutputRootField obj.NamePatternField obj.RecordingsDropDown], 'Enable', on);
set([obj.BrowseRootButton obj.BrowseOutputButton], 'Enable', on);
obj.FoldersArea.Enable = off;
obj.AddFolderButton.Enable = off;
end
