function rememberSessionAesthetics(obj, id, rules)
%rememberSessionAesthetics  Keep the aesthetics editor's rules with session plot ID (its aesthetics field).
%   The session preview's right-click editor calls this when its changes
%   are remembered for "this plot": renderPlot hands back the session
%   plot's own rules (the spec's sessionAesthetics, applied after the base
%   plot's), so they go to the session plot and never to its base plot.
%   Runs and scripts then draw the session figures that way; the
%   per-dataset figures of the base plot keep their look. The results the
%   preview holds take the rules too, so flipping pages and figures keeps
%   them. The title shows unsaved changes.
arguments
    obj (1,1) EphysAnalysisApp
    id (1,1) string
    rules = []
end
cfg = obj.Config;
k = cfg.sessionPlotIndex(id);
if k < 1
    obj.setStatus("Session plot " + id + " is gone: its aesthetics were not kept.");
    return
end
new = PlotAesthetics.normalizeRules(rules);
cfg.SessionPlots(k).aesthetics = new;
obj.Config = cfg;
if ~isempty(obj.Runner)
    obj.Runner.Config = cfg;
end
res = obj.SessionPreviewResults;
for i = 1:numel(res)
    if ~isempty(res(i).R) && isfield(res(i).R, 'spec') && string(res(i).R.spec.id) == id
        res(i).R.spec.sessionAesthetics = new;
    end
end
obj.SessionPreviewResults = res;
obj.setStatus(sprintf("%s: %d remembered aesthetic setting(s), saved with the config (the base plot keeps its own).", id, numel(new)));
obj.updateTitle();
end
