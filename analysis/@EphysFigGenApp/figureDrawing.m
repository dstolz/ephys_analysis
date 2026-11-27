function [P, look] = figureDrawing(obj, id)
%figureDrawing  The preview container that holds figure ID's drawing, and whether that drawing is current.
%   [P, LOOK] = figureDrawing(OBJ, ID) is the container the Figures tab
%   keeps for figure ID (syncFigureView: FigurePreviewPanel for the figure
%   shown, else its entry of FigureViews) when it holds a drawing of that
%   figure renderFigure made (its editing context names the figure:
%   PlotAesthetics.ContextKey), else []. LOOK is figureViewFresh's:
%   "fresh" (drawn and current), "stale" (drawn from the figure as it was
%   before an edit, another dataset or observation), "failed" or "none".
%   PlotAesthetics.components(P) lists what is drawn in it; the command
%   line's figures (OBJ.Plots) read their parts from it.
%
%   See also figureViewFresh, syncFigureView, PlotAesthetics.components, PlotConsole.
arguments
    obj (1,1) EphysFigGenApp
    id (1,1) string
end
P = [];
look = "none";
[k, id] = obj.figureIndexOf(id);
if k < 1; return; end
[~, look] = figureViewFresh(obj, k);
if id == obj.FigureViewId
    C = obj.FigurePreviewPanel;
else
    C = [];
    V = obj.FigureViews;
    if ~isempty(V)
        i = find([V.Id] == id, 1);
        if ~isempty(i); C = V(i).Panel; end
    end
end
if isempty(C) || ~isvalid(C) || ~isappdata(C, PlotAesthetics.ContextKey); return; end
ctx = getappdata(C, PlotAesthetics.ContextKey);
if ~isstruct(ctx) || ~isfield(ctx, 'id') || ~isfield(ctx, 'root') || ~all(isgraphics(ctx.root)); return; end
if followedFigureId(obj, ctx.id) ~= id; return; end   % another figure's drawing
P = C;
end
