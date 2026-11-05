function S = gatherSourceSection(obj)
%gatherSourceSection  Config Source from the Data tab.
%   In project mode the Run ticks are the selection: every dataset ticked
%   is Selection "all", otherwise "list" with the ticked keys. Before a scan
%   the saved selection is kept. Filter is the filter above the datasets
%   table as set (each field "" when off: blank or "(any)").
S = obj.Config.Source;
S.Mode = string(obj.SourceModeDropDown.Value);
S.Root = strtrim(string(obj.RootField.Value));
S.OutputRoot = strtrim(string(obj.OutputRootField.Value));
S.NamePattern = strtrim(string(obj.NamePatternField.Value));
S.Recordings = string(obj.RecordingsDropDown.Value);
lines = strtrim(string(obj.FoldersArea.Value));
lines = lines(lines ~= "");
if isempty(lines); lines = string.empty(1, 0); end
S.Folders = reshape(lines, 1, []);
if S.Mode == "project" && ~isempty(obj.Runner) && numel(obj.Ticked) == numel(obj.Runner.Keys) && ~isempty(obj.Ticked)
    if all(obj.Ticked)
        S.Selection = "all";
        S.Datasets = string.empty(1, 0);
    else
        S.Selection = "list";
        S.Datasets = obj.Runner.Keys(obj.Ticked);
    end
end
S.Filter = struct('Subjects', filterText(obj.SubjectFilterDropDown), ...
    'ExcludeSubjects', filterText(obj.NotSubjectFilterDropDown), ...
    'Tags', filterText(obj.TagFilterDropDown), ...
    'TagMode', string(obj.TagFilterModeDropDown.Value), ...
    'ExcludeTags', filterText(obj.NotTagFilterDropDown), ...
    'Search', filterText(obj.SearchFilterField));
end


function t = filterText(control)
%filterText  A filter control's value as config text: trimmed, "" for '(any)'.
t = strtrim(string(control.Value));
if t == "(any)"; t = ""; end
end
