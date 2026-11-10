function applySourceSection(obj, S)
%applySourceSection  Show config Source on the Data tab.
%   Its Filter sets the filter above the datasets table ("" shows as
%   '(any)'); when that changes it, the table (when there is one) is
%   filtered again (only then: each fill checks every dataset's files).
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
F = S.Filter;
before = filterState(obj);
setDrop(obj.SubjectFilterDropDown, F.Subjects);
setDrop(obj.NotSubjectFilterDropDown, F.ExcludeSubjects);
setDrop(obj.TagFilterDropDown, F.Tags);
setDrop(obj.NotTagFilterDropDown, F.ExcludeTags);
if ismember(F.TagMode, string(obj.TagFilterModeDropDown.ItemsData))
    obj.TagFilterModeDropDown.Value = char(F.TagMode);
end
obj.SearchFilterField.Value = char(F.Search);
obj.syncSourceEnable();
obj.showDownsample(sourceRates(S));   % the Signals row: the rates in words
obj.showSignalFilter(sourceFilters(S));   % the Filters row: the filters in words
if ~isempty(obj.Runner) && ~isequal(filterState(obj), before); obj.refreshDatasetsTable(); end
end


function s = filterState(obj)
%filterState  What the filter controls hold, to tell whether they changed.
s = string({obj.SubjectFilterDropDown.Value, obj.NotSubjectFilterDropDown.Value, obj.TagFilterDropDown.Value, ...
    obj.TagFilterModeDropDown.Value, obj.NotTagFilterDropDown.Value, obj.SearchFilterField.Value});
end


function setDrop(dd, text)
%setDrop  A filter drop-down's value: TEXT, or '(any)' when blank (the drop-downs are editable: any text stays).
if text == ""; text = "(any)"; end
dd.Value = char(text);
end
