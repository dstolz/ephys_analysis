function S = gatherSourceSection(obj)
%gatherSourceSection  Config Source from the Data tab.
%   In project mode the Run ticks are the selection: every dataset ticked
%   is Selection "all", otherwise "list" with the ticked keys. Before a scan
%   the saved selection is kept.
S = obj.Config.Source;
S.Mode = string(obj.SourceModeDropDown.Value);
S.Root = strtrim(string(obj.RootField.Value));
S.OutputRoot = strtrim(string(obj.OutputRootField.Value));
S.NamePattern = strtrim(string(obj.NamePatternField.Value));
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
end
