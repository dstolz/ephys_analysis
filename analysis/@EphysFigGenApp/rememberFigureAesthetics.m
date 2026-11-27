function rememberFigureAesthetics(obj, id, rules, opts)
%rememberFigureAesthetics  Keep the aesthetics editor's rules with figure ID (its aesthetics field).
%   The preview's right-click editor calls this (renderFigure's OnRemember)
%   when its changes are remembered for "this figure": they go into the
%   config (Figures(k).aesthetics), so the figure is drawn that way wherever
%   it is drawn, and the title shows unsaved changes. RULES [] forgets them
%   (the Design and looks section's Forget). The change is a step of the
%   undo history (recordFigureEdit: "Remember looks", "Forget looks").
%   The editor redraws the preview itself, after this call
%   (PlotAestheticsDialog's OK: its context's redraw), with the rules: a
%   preview that was the figure as it is now (figureViewFresh) is marked
%   current with them (FigurePreviewDrawn: figureViewKey), so an Undo of
%   the step finds the drawing out of date (it shows the looks undone)
%   and draws it again, or says Out of date. A drawing that was not
%   current says Out of date (markStaleDrawing).
%   Preview=false: the editor of a window of its own (onOpenFigureWindow)
%   called, which redraws only that window: the preview follows as after
%   any edit (autoFigurePreview: drawn again with the rules, or Out of
%   date), or, for a figure not shown, the tree marks its kept preview out
%   of date (markFigureTree).
%
%   See also renderFigure, PlotAesthetics, figureViewKey.
arguments
    obj (1,1) EphysFigGenApp
    id (1,1) string
    rules = []
    opts.Preview (1,1) logical = true
end
cfg = obj.Config;
id = followedFigureId(obj, id);   % renamed since the editor was opened (an automatic id that followed an edit)
k = cfg.figureIndex(id);
if k < 1
    obj.setStatus("Figure " + id + " is gone: its aesthetics were not kept.");
    return
end
fresh = opts.Preview && k == obj.SelectedFigure && figureViewFresh(obj, k);   % the preview the editor draws next is current but for the rules
cfg.Figures(k).aesthetics = PlotAesthetics.normalizeRules(rules);
if isempty(cfg.Figures(k).aesthetics)
    recordFigureEdit(obj, cfg, "Forget looks");
else
    recordFigureEdit(obj, cfg, "Remember looks");
end
obj.Config = cfg;
if ~isempty(obj.Runner)
    obj.Runner.Config = cfg;
end
if fresh
    obj.FigurePreviewDrawn = figureViewKey(obj, k);   % drawn with the rules next: the figure as it is now
elseif opts.Preview
    markStaleDrawing(obj);
elseif k == obj.SelectedFigure
    obj.autoFigurePreview();   % a window's look: the preview follows as after an edit
else
    markFigureTree(obj);   % its kept preview, drawn without the rules, out of date in the tree
end
n = numel(cfg.Figures(k).aesthetics);
obj.setStatus(sprintf("%s: %d remembered aesthetic setting(s), saved with the config.", id, n));
showLooksCount(obj, k);   % the editor's Design and looks line, when it shows this figure
obj.updateTitle();
end
