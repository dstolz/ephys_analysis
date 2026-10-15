function onSaveDesign(obj, name, description)
%onSaveDesign  Keep the figure preview's look as a design of yours, and draw in it.
%   PlotDesign.capture reads every property of every component of the
%   Figures tab's preview (with the rules it is drawn with), its ground and
%   its group colors; the design is saved in your designs folder and
%   chosen. The panel types come from the editing context renderFigure
%   recorded for the panels it drew (not the config, which may have
%   changed since), so the axes of heat map, probe map, correlation map
%   and spectrogram panels give rules for those panel types only and the
%   other panels the common rules. Nothing is saved while the preview is
%   Out of date (the drawing is not the figure any more): the status bar
%   says to preview first. Asks for the NAME and DESCRIPTION unless given
%   (given: one of yours of that name is replaced). The Save look as
%   design button beside the Design list on the Figures tab and the Design
%   menu call it.
arguments
    obj (1,1) EphysAnalysisApp
    name (1,1) string = missing
    description (1,1) string = ""
end
P = obj.FigurePreviewPanel;
k = obj.SelectedFigure;
if ~isappdata(P, PlotAesthetics.ContextKey) || isempty(obj.FigurePreviewResult) || k < 1 || k > numel(obj.Config.Figures)
    uialert(obj.Fig, "Preview a figure first (Figures tab): its look is what the design keeps.", "Save design");
    return
end
if obj.FigurePreviewState == "stale"
    obj.setStatus("Save design: preview first: the drawing is out of date.");
    return
end
if ismissing(name)
    [name, description, ok] = PlotDesign.askName(obj.Fig, "", "");
    if ~ok; return; end
end
try
    D = PlotDesign.capture(P, Name=name, Description=description);
    PlotDesign.save(D, name, Overwrite=true);
    name = PlotDesign.checkName(name);
    PlotDesign.use(name);
catch ME
    uialert(obj.Fig, ME.message, "Save design");
    return
end
nKind = sum(structfun(@numel, D.kinds));
obj.setStatus(sprintf("Saved design %s (%d settings, %d of them for one panel type) in %s, and chose it.", ...
    name, numel(D.rules) + nKind, nKind, PlotDesign.folder()));
end
