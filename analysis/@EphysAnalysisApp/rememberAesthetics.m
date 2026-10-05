function rememberAesthetics(obj, id, rules)
%rememberAesthetics  Keep the aesthetics editor's rules with plot ID (its aesthetics field).
%   The preview's right-click editor (PlotAestheticsDialog) calls this when
%   its changes are remembered for "this plot": they go into the config, so
%   runs, reports and generated scripts draw the plot that way, and the
%   title shows unsaved changes. The editor redraws the preview itself.
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
cfg.Plots(k).aesthetics = PlotAesthetics.normalizeRules(rules);
obj.Config = cfg;
if ~isempty(obj.Runner)
    obj.Runner.Config = cfg;
end
n = numel(cfg.Plots(k).aesthetics);
obj.setStatus(sprintf("%s: %d remembered aesthetic setting(s), saved with the config.", id, n));
obj.updateTitle();
end
