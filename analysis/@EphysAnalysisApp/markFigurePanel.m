function markFigurePanel(obj)
%markFigurePanel  Outline the selected panel in the figure preview: a colored frame round its axes and their labels, in the preview only.
%   The frame is four thin strips (uipanels, Tag "previewPanelMark") in the
%   preview panel, round the selected panel's axes (a coherence panel's
%   phase strip too) and the room their tick labels, axis labels and title
%   take (TightInset), 4 px out. It is drawn for the figure the preview
%   shows (the editing context renderFigure keeps: its id) and the panel
%   of that id there, so it is hidden while the preview shows another
%   figure, an older drawing without that panel, a probe figure (the
%   panel is drawn in every tile), or nothing. It is a part
%   of the app, not of the figure: renderFigure, exports, Open in window,
%   PlotDesign.capture, the aesthetics editor and the data tips never see
%   it, and the preview is not computed or drawn again for it. Called when
%   the selection changes (syncFigureEditor) and after a preview is drawn
%   (refreshFigurePreview); the preview's axes are followed (a listener on
%   each one's Position), so when figureLayout lays the figure out again
%   (the preview resized) the frame follows. A drawing over the preview
%   (renderFigure empties it) takes the strips with it; they are made
%   again here.
P = obj.FigurePreviewPanel;
if isempty(P) || ~isvalid(P); return; end
M = obj.FigurePanelMark;
[A, id] = selectedAxes(obj, P);
followAxes(obj, P);
if isempty(A)
    if ~isempty(M) && all(isvalid(M)); set(M, 'Visible', 'off'); end
    return
end
if isempty(M) || ~all(isvalid(M)) || ~all(M(1).Parent == P)
    if ~isempty(M); delete(M(isvalid(M))); end
    M = gobjects(1, 4);
    for s = 1:4
        M(s) = uipanel(P, 'BorderType', 'none', 'BackgroundColor', [0.05 0.45 0.95], 'Units', 'pixels', ...
            'Tag', 'previewPanelMark', 'AutoResizeChildren', 'off');
    end
    obj.FigurePanelMark = M;
end
box = [Inf Inf -Inf -Inf];   % x0 y0 x1 y1, pixels in the preview panel
for ax = reshape(A, 1, [])
    if ~strcmp(ax.Units, 'pixels'); continue; end   % (figureLayout sets pixels)
    p = ax.Position;
    t = ax.TightInset;
    box = [min(box(1), p(1) - t(1)), min(box(2), p(2) - t(2)), max(box(3), p(1) + p(3) + t(3)), max(box(4), p(2) + p(4) + t(4))];
end
if any(~isfinite(box)); set(M, 'Visible', 'off'); return; end
sz = P.InnerPosition(3:4);
w = 3;   % the frame's width, px
box = [max(box(1:2) - 4 - w, 1), min(box(3:4) + 4 + w, sz)];
x0 = box(1); y0 = box(2); W = max(box(3) - x0, 2 * w); H = max(box(4) - y0, 2 * w);
set(M(1), 'Position', [x0, y0, W, w]);           % bottom
set(M(2), 'Position', [x0, y0 + H - w, W, w]);   % top
set(M(3), 'Position', [x0, y0, w, H]);           % left
set(M(4), 'Position', [x0 + W - w, y0, w, H]);   % right
set(M, 'Visible', 'on', 'Tooltip', "The selected panel, " + id + ": Ctrl+] and Ctrl+[ step through the panels, Ctrl+Alt+arrows go across the grid.");
end


function [A, id] = selectedAxes(obj, P)
%selectedAxes  The preview's axes of the selected panel (its first axes and any further ones), when the preview shows the selected figure.
A = gobjects(1, 0);
id = "";
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
j = obj.SelectedPanel;
fig = obj.Config.Figures(k);
if j < 1 || j > numel(fig.panels); return; end
F = obj.FigurePreviewResult;
if isstruct(F) && isfield(F, 'kind') && string(F.kind) == "probeFigure"; return; end   % a probe figure: the panel is in every tile
ctx = [];
if isappdata(P, PlotAesthetics.ContextKey); ctx = getappdata(P, PlotAesthetics.ContextKey); end
if (isstruct(ctx) && isfield(ctx, 'id') && string(ctx.id) ~= fig.id) || ~isappdata(P, 'FigureLayout'); return; end   % another figure's drawing
L = getappdata(P, 'FigureLayout');
id = fig.panels(j).id;
for q = reshape(L.panels, 1, [])
    if isempty(q.axes) || ~all(isgraphics(q.axes)); continue; end
    if isappdata(q.axes(1), 'FigurePanel') && string(getappdata(q.axes(1), 'FigurePanel')) == id
        A = q.axes;
        return
    end
end
end


function followAxes(obj, P)
%followAxes  Listen to the Position of every axes the preview's figure lays out, so the frame follows a new layout.
A = gobjects(1, 0);
if isappdata(P, 'FigureLayout')
    L = getappdata(P, 'FigureLayout');
    for q = reshape(L.panels, 1, [])
        A = [A reshape(q.axes(isgraphics(q.axes)), 1, [])]; %#ok<AGROW>
    end
end
if isequal(obj.FigurePanelMarkAxes, A); return; end
delete(obj.FigurePanelMarkListeners);
obj.FigurePanelMarkListeners = [];
obj.FigurePanelMarkAxes = A;
if isempty(A); return; end
L = event.proplistener.empty;
for ax = A
    L(end+1) = listener(ax, 'Position', 'PostSet', @(~, ~) placeAgain(obj, ax)); %#ok<AGROW>
end
obj.FigurePanelMarkListeners = L;
end


function placeAgain(obj, ax)
%placeAgain  An axes of the preview moved (figureLayout): the frame follows it when it is the selected panel's.
%   Not while the preview is drawn: renderFigure keeps the axes of panels
%   an edit left alone (Reuse) and moves them, and the frame is drawn
%   once it is done (refreshFigurePreview).
if ~isvalid(obj) || ~isvalid(ax) || isempty(obj.FigurePanelMark) || obj.FigurePreviewState == "drawing"; return; end
P = obj.FigurePreviewPanel;
A = selectedAxes(obj, P);
if any(A == ax); obj.markFigurePanel(); end
end
