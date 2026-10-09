function rememberAesthetics(obj, id, rules)
%rememberAesthetics  Keep the aesthetics editor's rules with plot ID (its aesthetics field).
%   The preview's right-click editor (PlotAestheticsDialog) calls this when
%   its changes are remembered for "this plot": they go into the config, so
%   runs, reports and generated scripts draw the plot that way, and the
%   title shows unsaved changes. The editor redraws the preview itself.
%
%   When ID is the plot in the editor and others are selected with it, they
%   take the same change: the rules it gained (or whose value changed) are
%   merged into theirs, and the rules it forgot are dropped from theirs
%   (by role, group and property); their other rules stay.
arguments
    obj (1,1) EphysAnalysisApp
    id (1,1) string
    rules = []
end
cfg = obj.Config;
k = cfg.plotIndex(id);
if k < 1
    obj.setStatus("Plot " + id + " is gone: its aesthetics were not kept.");
    return
end
old = cfg.Plots(k).aesthetics;
new = PlotAesthetics.normalizeRules(rules);
cfg.Plots(k).aesthetics = new;
ks = obj.selectedPlots();
others = zeros(1, 0);
if ~isempty(ks) && ks(1) == k; others = ks(2:end); end
if ~isempty(others)
    added = new(~arrayfun(@(r) any(arrayfun(@(o) isequaln(o, r), old)), new));
    gone = old(~arrayfun(@(r) any(sameKey(new, r)), old));
    for j = others
        R = cfg.Plots(j).aesthetics;
        for r = gone
            R = R(~sameKey(R, r));
        end
        cfg.Plots(j).aesthetics = PlotAesthetics.mergeRules(R, added);
    end
end
obj.Config = cfg;
if ~isempty(obj.Runner)
    obj.Runner.Config = cfg;
end
n = numel(cfg.Plots(k).aesthetics);
if isempty(others)
    obj.setStatus(sprintf("%s: %d remembered aesthetic setting(s), saved with the config.", id, n));
else
    obj.setStatus(sprintf("%s: %d remembered aesthetic setting(s); the change also went to the %d other plots selected.", ...
        id, n, numel(others)));
end
obj.updateTitle();
end


function tf = sameKey(R, r)
%sameKey  Which rules of R set the same role, group and property as rule r.
if isempty(R)
    tf = false(1, 0);
else
    tf = [R.role] == r.role & [R.group] == r.group & [R.property] == r.property;
end
end
