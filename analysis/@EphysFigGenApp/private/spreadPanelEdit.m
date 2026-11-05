function [cfg, label, msg] = spreadPanelEdit(obj, cfg, label)
%spreadPanelEdit  An edit of the selected panel, given to the other panels selected with it (Shift+click) too.
%   [CFG, LABEL, MSG] = spreadPanelEdit(OBJ, CFG, LABEL), CFG the config
%   an edit in the figure editor made (gathered, or edited by a window of
%   the editor's) and LABEL its name in the undo history ("Stack"). While
%   several panels of the selected figure are selected (selectedPanelIds:
%   the shown one, SelectedPanel, first), what the edit changed in the
%   shown panel -- its settings as figureEditChanges names them, its title
%   and axis labels too (Labels=true) -- goes to each of the others that
%   takes it, by the rule Apply to figures uses (changeTargets: an option
%   it has, of any type since the user selected them together, AnyType,
%   with a value its type takes, panelTakes; applyChanges: a field of an
%   alignment it does not have of its own starts from the one it uses).
%   The figure's own settings are the figure's already. LABEL then counts
%   the panels ("Stack (3 panels)"), one step of the undo history for all
%   of them, and MSG says where the edit went and which panel kept its own
%   value (a type that does not take it); "" with one panel selected, or
%   nothing of the shown panel's changed (a figure setting, a place).
%
%   See also selectedPanelIds, EphysFigGenApp.onConfigChanged, EphysAnalysisConfig.figureEditChanges,
%   EphysAnalysisConfig.changeTargets, EphysAnalysisConfig.applyChanges.
arguments
    obj (1,1) EphysFigGenApp
    cfg (1,1) EphysAnalysisConfig
    label (1,1) string = "Edit"
end
msg = "";
sel = selectedPanelIds(obj);
k = obj.SelectedFigure;
j = obj.SelectedPanel;
if numel(sel) < 2 || k < 1 || k > numel(cfg.Figures) || numel(cfg.Figures) ~= numel(obj.Config.Figures); return; end
before = obj.Config.Figures(k);
after = cfg.Figures(k);
changes = EphysAnalysisConfig.figureEditChanges(before, after, j, Labels=true);
if isempty(changes); return; end
changes = changes([changes.scope] == "panel");
if isempty(changes); return; end
T = EphysAnalysisConfig.changeTargets(cfg.Figures, cfg.Defaults, k, j, changes, AnyType=true);   % (the rows shown are those each has)
if ~isempty(T); T = T([T.figure] == k & ismember(string({T.panelId}), sel(2:end))); end
went = string({T.panelId});
kept = setdiff(sel(2:end), went, 'stable');
if ~isempty(T); T = T(~[T.same]); end   % (those with the values already need nothing)
if ~isempty(T)
    cfg.Figures = EphysAnalysisConfig.applyChanges(cfg.Figures, cfg.Defaults, T, changes);
end
n = 1 + numel(went);
if n > 1
    label = label + sprintf(" (%d panels)", n);
    msg = sprintf("%s went to %s.", label, strjoin([sel(1) went], ", "));
else
    msg = label + " went to " + sel(1) + " only.";
end
if ~isempty(kept)
    msg = msg + " " + strjoin(kept, ", ") + " kept " + plural(numel(kept), "its own", "their own") + ...
        ": " + plural(numel(kept), "its type does", "their types do") + " not take it.";
end
end


function t = plural(n, one, many)
%plural  ONE for a single one, else MANY.
t = many;
if n == 1; t = one; end
end
