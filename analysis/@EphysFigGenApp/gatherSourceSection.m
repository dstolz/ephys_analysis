function S = gatherSourceSection(obj)
%gatherSourceSection  Config Source from the Data tab.
%   The Run ticks are the selection, in either mode: every dataset ticked
%   is Selection "all", otherwise "list" with the ticked keys (project
%   mode: root-relative keys; folders mode: the folders). They are taken
%   only while the datasets listed are the scan of the source the tab
%   shows (scanIsCurrent: what scannedSource reads, the ticks themselves
%   aside); otherwise -- before a scan, or after the root, output root,
%   name pattern, recordings or folders changed, or a config opened whose
%   source was not scanned -- the config's own selection is kept, so it
%   never takes another source's ticks. The keys a config opened without
%   its scan ticks that the datasets listed lack (TickedNotListed:
%   tickConfigSelection; the listing is older than the config) are kept
%   after the ticked ones until a scan, so a Save does not drop them. A change of Mode (project <->
%   folders) starts the selection again at "all": the other mode's keys
%   name nothing here. Filter is the filter above the datasets table as
%   set (each field "" when off: blank or "(any)").
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
if S.Mode ~= obj.Config.Source.Mode   % the other mode's selection means nothing in this one
    S.Selection = "all";
    S.Datasets = string.empty(1, 0);
end
if ~isempty(obj.Runner) && numel(obj.Ticked) == numel(obj.Runner.Keys) && ~isempty(obj.Ticked) && scanIsCurrent(obj, S)
    unlisted = obj.TickedNotListed;   % a config opened without its scan: its keys the old listing lacks (tickConfigSelection)
    if all(obj.Ticked) && isempty(unlisted)
        S.Selection = "all";
        S.Datasets = string.empty(1, 0);
    else
        S.Selection = "list";
        S.Datasets = [reshape(obj.Runner.Keys(obj.Ticked), 1, []) reshape(unlisted, 1, [])];
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
