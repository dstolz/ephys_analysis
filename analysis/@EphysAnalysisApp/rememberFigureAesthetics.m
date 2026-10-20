function rememberFigureAesthetics(obj, id, rules)
%rememberFigureAesthetics  Keep the aesthetics editor's rules with figure ID (its aesthetics field).
%   The preview's right-click editor calls this (renderFigure's OnRemember)
%   when its changes are remembered for "this figure": they go into the
%   config (Figures(k).aesthetics), so the figure is drawn that way wherever
%   it is drawn, and the title shows unsaved changes. RULES [] forgets them
%   (the Looks section's Forget). The editor redraws the preview itself.
%
%   See also renderFigure, PlotAesthetics.
arguments
    obj (1,1) EphysAnalysisApp
    id (1,1) string
    rules = []
end
cfg = obj.Config;
id = followedFigureId(obj, id);   % renamed since the editor was opened (an automatic id that followed an edit)
k = cfg.figureIndex(id);
if k < 1
    obj.setStatus("Figure " + id + " is gone: its aesthetics were not kept.");
    return
end
cfg.Figures(k).aesthetics = PlotAesthetics.normalizeRules(rules);
obj.Config = cfg;
if ~isempty(obj.Runner)
    obj.Runner.Config = cfg;
end
n = numel(cfg.Figures(k).aesthetics);
obj.setStatus(sprintf("%s: %d remembered aesthetic setting(s), saved with the config.", id, n));
if k == obj.SelectedFigure
    E = obj.FigureEditor;
    E.looksText.Text = sprintf("%d remembered look(s); right-click the preview to edit.", n);
    E.looksForget.Enable = matlab.lang.OnOffSwitchState(n > 0);
end
obj.updateTitle();
end
