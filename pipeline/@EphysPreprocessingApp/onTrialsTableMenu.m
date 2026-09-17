function onTrialsTableMenu(obj, menu, evt)
%onTrialsTableMenu  Build the Trials table's context menu as it opens.
%   Remove "<name>" when a parameter column was right-clicked; Parameter
%   columns: one checked item per Epsych2 parameter of the loaded session
%   (TrialIndex is always a column), then the chosen parameters this
%   session lacks, which can be unticked, each list in alphabetical order
%   ignoring case; Reset column order. The choices
%   (TrialsParamColumns, TrialsColumnOrder) are preferences, so they hold
%   for every dataset and the next session.
delete(menu.Children);
shown = obj.TrialsParamColumns;

T = obj.TrialsTable.Data;
col = evt.InteractionInformation.Column;   % a Data column (not its place on screen)
if isscalar(col) && istable(T) && col <= width(T)
    var = string(T.Properties.VariableNames{col});
    if startsWith(var, "Param_")
        name = extractAfter(var, "Param_");
        uimenu(menu, "Text", "Remove """ + name + """", ...
            "MenuSelectedFcn", @(~,~) setParams(obj, shown(shown ~= name)));
    end
end

sub = uimenu(menu, "Text", "Parameter columns", "Separator", ~isempty(menu.Children));
params = string.empty(1, 0);
if istable(obj.TrialsSession)
    params = string(obj.TrialsSession.Properties.VariableNames);
    params = alphabetical(params(params ~= "TrialIndex"));
end
for p = params
    uimenu(sub, "Text", p, "Checked", ismember(p, shown), ...
        "MenuSelectedFcn", @(~,~) setParams(obj, setxor(shown, p, 'stable')));
end
missing = alphabetical(shown(~ismember(shown, params)));
for k = 1:numel(missing)
    uimenu(sub, "Text", missing(k) + " (not in this session)", "Checked", true, "Separator", k == 1 && ~isempty(params), ...
        "MenuSelectedFcn", @(~,~) setParams(obj, shown(shown ~= missing(k))));
end
if isempty(sub.Children)
    uimenu(sub, "Text", "Load a dataset to list its Epsych2 parameters", "Enable", "off");
end

uimenu(menu, "Text", "Reset column order", "Separator", "on", ...
    "MenuSelectedFcn", @(~,~) resetOrder(obj));
end


function names = alphabetical(names)
[~, i] = sort(lower(names));
names = names(i);
end


function setParams(obj, names)
obj.TrialsParamColumns = names;
obj.refreshTrialsTable();
end


function resetOrder(obj)
obj.TrialsColumnOrder = string.empty(1, 0);
obj.TrialsTable.DisplayColumnOrder = [];   % or the dragged order would be read back
obj.refreshTrialsTable();
end
