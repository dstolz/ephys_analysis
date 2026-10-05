function onTrialsPlotMenu(obj)
%onTrialsPlotMenu  Rebuild the Trials plot's "Trial labels" list as its context menu opens.
%   One checked item per trial parameter of the loaded trials (TrialIndex
%   included), then the chosen parameters this session lacks, which can be
%   unticked, each list in alphabetical order ignoring case; No labels. A
%   ticked parameter labels every paired trial with its value above the
%   trial line (refreshTrialsPlot). The choice (TrialsLabelParams) is a
%   preference, so it holds for every dataset and the next session.
sub = obj.TrialsLabelsMenu;
delete(sub.Children);
shown = obj.TrialsLabelParams;

params = string.empty(1, 0);
if istable(obj.TrialsSession)
    params = alphabetical(string(obj.TrialsSession.Properties.VariableNames));
end
for p = params
    uimenu(sub, "Text", p, "Checked", ismember(p, shown), ...
        "MenuSelectedFcn", @(~,~) setLabels(obj, setxor(shown, p, 'stable')));
end
missing = alphabetical(shown(~ismember(shown, params)));
for k = 1:numel(missing)
    uimenu(sub, "Text", missing(k) + " (not in these trials)", "Checked", true, "Separator", k == 1 && ~isempty(params), ...
        "MenuSelectedFcn", @(~,~) setLabels(obj, shown(shown ~= missing(k))));
end
if isempty(sub.Children)
    uimenu(sub, "Text", "Load a dataset to list its trial parameters", "Enable", "off");
elseif ~isempty(shown)
    uimenu(sub, "Text", "No labels", "Separator", "on", ...
        "MenuSelectedFcn", @(~,~) setLabels(obj, string.empty(1, 0)));
end
end


function names = alphabetical(names)
[~, i] = sort(lower(names));
names = names(i);
end


function setLabels(obj, names)
obj.TrialsLabelParams = names;
obj.refreshTrialsPlot();
end
