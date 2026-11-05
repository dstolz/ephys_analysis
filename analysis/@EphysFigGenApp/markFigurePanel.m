function markFigurePanel(obj)
%markFigurePanel  Outline the selected panels in the figure preview: a colored frame round each one's axes and their labels, in the preview only.
%   A frame is four thin strips (uipanels, Tag "previewPanelMark") in the
%   preview panel, round a selected panel's axes (a coherence panel's
%   phase strip too) and the room their tick labels, axis labels and title
%   take (TightInset), 4 px out: one round the selected panel (3 px wide),
%   and with several selected (Shift+click: selectedPanelIds) one round
%   each of the others too (2 px). The strips are kept in FigurePanelMark,
%   a 4 x n array, a column per frame (the primary's first); those not
%   needed are hidden. A frame is drawn for the figure the preview shows
%   (the editing context renderFigure keeps: its id) and the panel of that
%   id there, so it is hidden while the preview shows another figure, an
%   older drawing without that panel, a probe figure (the panel is drawn
%   in every tile), or nothing. It is a part
%   of the app, not of the figure: renderFigure, exports, Open in window,
%   PlotDesign.capture, the aesthetics editor and the data tips never see
%   it, and the preview is not computed or drawn again for it. Called when
%   the selection changes (syncFigureEditor) and after a preview is drawn
%   (refreshFigurePreview); the preview's axes are followed (a listener on
%   each one's Position), so when figureLayout lays the figure out again
%   (the preview resized) the frames follow. A drawing over the preview
%   (renderFigure empties it) takes the strips with it; they are made
%   again here.
%   While Arrange is on (FigureArrange) the strips are hidden: the
%   selected panels' boxes over the preview are blue instead. Each call also
%   brings Arrange's overlay up to date (syncArrangeOverlay: made, its
%   boxes at the panels' rects, or taken away), and the listeners on the
%   axes move the overlay with a new layout.
obj.syncArrangeOverlay();
P = obj.FigurePreviewPanel;
if isempty(P) || ~isvalid(P); return; end
M = obj.FigurePanelMark;
followAxes(obj, P);
if obj.FigureArrange   % the selected panels' boxes show them
    hideMarks(M);
    return
end
[A, ids] = selectedAxes(obj, P);
if isempty(A)
    hideMarks(M);
    return
end
n = numel(A);
if isempty(M) || ~all(isvalid(M(:))) || ~all([M(1, :).Parent] == P) || size(M, 2) < n
    if ~isempty(M); delete(M(isvalid(M))); end
    M = gobjects(4, n);
    for c = 1:n
        for s = 1:4
            M(s, c) = uipanel(P, 'BorderType', 'none', 'BackgroundColor', [0.05 0.45 0.95], 'Units', 'pixels', ...
                'Tag', 'previewPanelMark', 'AutoResizeChildren', 'off');
        end
    end
    obj.FigurePanelMark = M;
end
sz = P.InnerPosition(3:4);
for c = 1:n
    w = 3 - (c > 1);   % the frame's width, px: the primary's wider
    if c == 1 && n == 1
        tip = "The selected panel, " + ids(c) + ": Ctrl+] and Ctrl+[ step through the panels, Ctrl+Alt+arrows go to the one " + ...
            "above, below, left or right; Shift+click another panel to select it too.";
    else
        tip = sprintf("One of the %d panels selected, %s: an edit in the editor goes to all of them. Shift+click a panel to " + ...
            "add it or take it out; Esc keeps %s alone.", n, ids(c), ids(1));
    end
    frameAround(M(:, c), A{c}, sz, w, tip);
end
hideMarks(M(:, n+1:end));
end


function frameAround(M, A, sz, w, tip)
%frameAround  Place the four strips M round the axes A and their labels (pixels in a preview of size SZ), W px wide.
box = [Inf Inf -Inf -Inf];   % x0 y0 x1 y1, pixels in the preview panel
for ax = reshape(A, 1, [])
    if ~strcmp(ax.Units, 'pixels'); continue; end   % (figureLayout sets pixels)
    p = ax.Position;
    t = ax.TightInset;
    box = [min(box(1), p(1) - t(1)), min(box(2), p(2) - t(2)), max(box(3), p(1) + p(3) + t(3)), max(box(4), p(2) + p(4) + t(4))];
end
if any(~isfinite(box)); set(M, 'Visible', 'off'); return; end
box = [max(box(1:2) - 4 - w, 1), min(box(3:4) + 4 + w, sz)];
x0 = box(1); y0 = box(2); W = max(box(3) - x0, 2 * w); H = max(box(4) - y0, 2 * w);
set(M(1), 'Position', [x0, y0, W, w]);           % bottom
set(M(2), 'Position', [x0, y0 + H - w, W, w]);   % top
set(M(3), 'Position', [x0, y0, w, H]);           % left
set(M(4), 'Position', [x0 + W - w, y0, w, H]);   % right
set(M, 'Visible', 'on', 'Tooltip', tip);
end


function hideMarks(M)
%hideMarks  Hide the strips M (those still there).
if isempty(M); return; end
M = M(isvalid(M));
if ~isempty(M); set(M, 'Visible', 'off'); end
end


function [A, ids] = selectedAxes(obj, P)
%selectedAxes  The preview's axes of each selected panel (a cell each: its first axes and any further ones), when the preview shows the selected figure.
%   IDS: their panel ids, the selected panel's first (selectedPanelIds); a
%   panel the drawing does not have is left out.
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


function followAxes(obj, P)
%followAxes  Listen to the Position of every axes the preview's figure lays out, so the frame follows a new layout.
A = gobjects(1, 0);
if isappdata(P, 'FigureLayout')
    L = getappdata(P, 'FigureLayout');
    if ~isstruct(L) || ~isfield(L, 'panels'); L = struct('panels', []); end   % a probe page: nothing to follow
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
%placeAgain  An axes of the preview moved (figureLayout): the frames follow it when it is a selected panel's.
%   Not while the preview is drawn: renderFigure keeps the axes of panels
%   an edit left alone (Reuse) and moves them, and the frame is drawn
%   once it is done (refreshFigurePreview). While Arrange is on, its
%   overlay follows the page instead (syncArrangeOverlay, Follow).
%   Not during an Arrange drag either (FigureArrangeMode "drag", or
%   "canceled": a step, or Escape, moves the dragged panel's axes, the
%   page stays where it is), nor while the app lays the preview out itself
%   (FigureLayingOut: inPlaceFigurePreview, layoutPreview), which marks
%   the panels once after; else every axes the layout moves would follow
%   the page again.
if ~isvalid(obj) || ~isvalid(ax) || obj.FigurePreviewState == "drawing" || obj.FigureLayingOut ...
        || ismember(obj.FigureArrangeMode, ["drag" "canceled"])
    return
end
if obj.FigureArrange
    obj.syncArrangeOverlay(Follow=true);
    return
end
if isempty(obj.FigurePanelMark); return; end
P = obj.FigurePreviewPanel;
A = selectedAxes(obj, P);
if any(cellfun(@(a) any(a == ax), A)); obj.markFigurePanel(); end
end
