function [A, ids] = selectedPanelAxes(obj, P)
%selectedPanelAxes  The preview's axes of each selected panel (a cell each: its first axes and any further ones), when the preview shows the selected figure.
%   [A, IDS] = selectedPanelAxes(obj, P) looks in the preview container P.
%   IDS: their panel ids, the selected panel's first (selectedPanelIds); a
%   panel the drawing does not have is left out. Empty when P shows another
%   figure's drawing, a probe figure (the panel is in every tile) or a page
%   laid out its own way. markFigurePanel outlines them; onEditAesthetics
%   opens the editor on the first.
A = {};
ids = strings(1, 0);
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
fig = obj.Config.Figures(k);
sel = selectedPanelIds(obj);
if isempty(sel); return; end
F = obj.FigurePreviewResult;
if isstruct(F) && isfield(F, 'kind') && string(F.kind) == "probeFigure"; return; end   % a probe figure: the panel is in every tile
ctx = [];
if isappdata(P, PlotAesthetics.ContextKey); ctx = getappdata(P, PlotAesthetics.ContextKey); end
if (isstruct(ctx) && isfield(ctx, 'id') && string(ctx.id) ~= fig.id) || ~isappdata(P, 'FigureLayout'); return; end   % another figure's drawing
L = getappdata(P, 'FigureLayout');
if ~isstruct(L) || ~isfield(L, 'panels'); return; end   % a page laid out its own way (a probe figure's): no panel to outline
for id = sel
    for q = reshape(L.panels, 1, [])
        if isempty(q.axes) || ~all(isgraphics(q.axes)); continue; end
        if isappdata(q.axes(1), 'FigurePanel') && string(getappdata(q.axes(1), 'FigurePanel')) == id
            A{end+1} = q.axes; %#ok<AGROW>
            ids(end+1) = id; %#ok<AGROW>
            break
        end
    end
end
end
