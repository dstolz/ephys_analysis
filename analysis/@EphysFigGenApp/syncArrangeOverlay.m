function [shown, why] = syncArrangeOverlay(obj, opts)
%syncArrangeOverlay  Arrange's overlay over the preview: a move and resize box per panel at its rect, made, followed or taken away.
%   [SHOWN, WHY] = syncArrangeOverlay(OBJ) makes the overlay match the
%   app: while Arrange is on (FigureArrange) and the preview shows the
%   selected figure laid out (previewShowsFigure: drawn or out of date,
%   not a probe figure), a transparent axes (Tag "arrangeOverlay",
%   HandleVisibility off, so a drawing over the preview leaves it alone)
%   covers the page the panels' rects are read in (appdata
%   FigureLayoutResult's page: the last layout's, also for a preview out
%   of date), its x and y limits [0 1], so a box's Position is its panel's
%   rect; it is put over the drawing again (uistack). It holds a widget per
%   panel (private/arrangeWidget: Tag "arrangeBox:<id>", at the panel's
%   rect as the config holds it, the selected panel's blue), and a dashed
%   one for a legend floating in free space (legendMode "float", no
%   legend panel: Tag "arrangeBox:legend"), which a drag makes a legend
%   panel (onArrangeMoved). The widgets are kept by id and moved, made
%   or deleted only as the panels change, since making one takes a tenth
%   of a second; locked while Set corners waits for clicks
%   (FigureArrangeMode "corners"). A click on the overlay's empty part,
%   or on a box, calls onArrangeClicked; a box's drag onArrangeMoving and
%   onArrangeMoved; its right-click menu is private/arrangeMenu's. The
%   smart guides (private/arrangeCues) live in the overlay too.
%   Arrange off, or the preview showing anything else, takes the overlay
%   away (with Set corners or a drag under way: cancelArrange); when it
%   was there with Arrange on, the status bar says why (WHY, from
%   previewShowsFigure: "Arrange: preview <id> first (Ctrl+P)."). While a
%   preview computes or draws nothing changes: the drawing calls this
%   again when done. SHOWN: the overlay shows now.
%   The Panels section's Set corners is on while the preview shows the
%   selected figure and a panel is selected.
%   Called by markFigurePanel (after a preview is drawn, laid out again in
%   place or drawn again; the selection, an edit: syncFigureEditor;
%   another figure's container: syncFigureView) and setFigurePreviewState
%   (a preview failed, out of date, ...), so it follows every place the
%   selected panel's outline follows.
%   syncArrangeOverlay(OBJ, Follow=true) only moves the overlay onto the
%   page as the canvas is now (figureLayout laid the figure out again at a
%   new size: the Position listener markFigurePanel keeps on the panels'
%   axes calls it), the page being the canvas inside the layout's margin.
%
%   See also EphysFigGenApp.onArrangeToggled, EphysFigGenApp.onArrangeMoving,
%   EphysFigGenApp.onArrangeMoved, EphysFigGenApp.markFigurePanel, previewShowsFigure.
arguments
    obj (1,1) EphysFigGenApp
    opts.Follow (1,1) logical = false
end
shown = false;
why = "";
O = obj.FigureArrangeOverlay;
if opts.Follow
    if isstruct(O) && isvalid(O.axes) && isvalid(O.panel); followCanvas(O.axes, O.panel); end
    shown = isstruct(O);
    return
end
if ismember(obj.FigurePreviewState, ["computing" "drawing"])   % called again once it is drawn
    shown = isstruct(O);
    return
end
[ok, why] = previewShowsFigure(obj);
k = obj.SelectedFigure;
E = obj.FigureEditor;
if isfield(E, 'setCorners') && isvalid(E.setCorners)
    hasPanel = k >= 1 && k <= numel(obj.Config.Figures) && obj.SelectedPanel >= 1 && obj.SelectedPanel <= numel(obj.Config.Figures(k).panels);
    E.setCorners.Enable = matlab.lang.OnOffSwitchState(ok && hasPanel);
end
if ~obj.FigureArrange || ~ok
    if isstruct(O)
        removeOverlay(obj);
        if obj.FigureArrange && why ~= ""; obj.setStatus(why); end
    end
    if ~obj.FigureArrange; why = ""; end
    return
end
P = obj.FigurePreviewPanel;
R = getappdata(P, 'FigureLayoutResult');
if isstruct(O) && (~isvalid(O.axes) || ~isvalid(O.panel) || O.panel ~= P)   % another figure's container shows
    removeOverlay(obj);
    O = [];
end
if ~isstruct(O); O = newOverlay(obj, P); end
ax = O.axes;
page = double(reshape(R.page, 1, 4));
if ~isequal(ax.Position, page); ax.Position = page; end
uistack(ax, 'top');   % over the drawing (a drawing kept in part reorders the canvas' children)

fig = obj.Config.Figures(k);
ids = strings(1, 0);
if ~isempty(fig.panels); ids = [fig.panels.id]; end
sel = "";
if obj.SelectedPanel >= 1 && obj.SelectedPanel <= numel(ids); sel = ids(obj.SelectedPanel); end
locked = obj.FigureArrangeMode == "corners";
W = O.widgets;
for key = string(W.keys)
    if ~any(ids == key) || ~isvalid(W(char(key)))
        w = W(char(key));
        if isvalid(w); delete(w); end
        W.remove(char(key));
    end
end
for i = 1:numel(ids)
    id = ids(i);
    r = double(fig.panels(i).rect);
    if numel(r) ~= 4 || ~all(isfinite(r)) || any(r(3:4) <= 0); continue; end   % (Validate reports a bad rect)
    r = reshape(r, 1, 4);
    if isKey(W, char(id))
        w = W(char(id));
        arrangeWidgetSet(w, r);
        arrangeWidgetSelect(w, id == sel);
    else
        w = arrangeWidget(ax, r, id, id == sel, callbacks(obj, id));
        W(char(id)) = w;
    end
    arrangeWidgetLock(w, locked);
end
% the legend floating in free space: a dashed box, which a drag makes a legend panel
lr = [];
if isfield(R, 'legendMode') && string(R.legendMode) == "float" && numel(R.legend) == 4 ...
        && (isempty(fig.panels) || ~any([fig.panels.type] == "legend"))
    pg = page(3:4);
    lr = [(R.legend(1:2) - page(1:2)) ./ pg, R.legend(3:4) ./ pg];
    lr(3:4) = min(max(lr(3:4), 0.01), 1);
    lr(1:2) = min(max(lr(1:2), 0), 1 - lr(3:4));
end
if isempty(lr)
    if ~isempty(O.legend) && isvalid(O.legend); delete(O.legend); end
    O.legend = [];
elseif isempty(O.legend) || ~isvalid(O.legend)
    cb = callbacks(obj, ":legend");
    cb.legend = true;
    O.legend = arrangeWidget(ax, lr, ":legend", false, cb);
    arrangeWidgetLock(O.legend, locked);
else
    arrangeWidgetSet(O.legend, lr);
    arrangeWidgetLock(O.legend, locked);
end
O.legendRect = lr;
O.widgets = W;
obj.FigureArrangeOverlay = O;
shown = true;
end


function O = newOverlay(obj, P)
%newOverlay  The overlay's axes in the preview container P, no widget yet.
ax = axes(P, 'Units', 'pixels', 'Position', [1 1 10 10], 'XLim', [0 1], 'YLim', [0 1], 'Color', 'none', ...
    'XColor', 'none', 'YColor', 'none', 'XTick', [], 'YTick', [], 'Box', 'off', 'HandleVisibility', 'off', ...
    'Tag', 'arrangeOverlay', 'PickableParts', 'all', 'HitTest', 'on', 'ButtonDownFcn', @(~, ~) obj.onArrangeClicked("", []));
disableDefaultInteractivity(ax);
ax.Toolbar.Visible = 'off';
O = struct('axes', ax, 'panel', P, 'widgets', containers.Map('KeyType', 'char', 'ValueType', 'any'), 'legend', [], ...
    'legendRect', [], 'guides', [], 'band', [], 'timer', []);
end


function cb = callbacks(obj, id)
%callbacks  What a widget calls: its drag's steps and end, a click, its right-click menu.
cb = struct('moving', @(i, e) obj.onArrangeMoving(i, e), 'moved', @(i, e) obj.onArrangeMoved(i, e), ...
    'clicked', @(i, e) obj.onArrangeClicked(i, e), 'menu', arrangeMenu(obj, id));
end


function removeOverlay(obj)
%removeOverlay  The overlay gone, with its widgets, guides and timer; Set corners or a drag under way ends first.
if obj.FigureArrangeMode ~= ""
    obj.cancelArrange("");
    obj.FigureArrangeMode = "";   % (a drag's box goes too: no release will come)
end
O = obj.FigureArrangeOverlay;
obj.FigureArrangeOverlay = [];
if ~isstruct(O); return; end
if ~isempty(O.timer) && isvalid(O.timer); stop(O.timer); end   % (it deletes itself when stopped)
if ~isempty(O.axes) && isvalid(O.axes); delete(O.axes); end   % its widgets, their menus and the guides with it
end


function followCanvas(ax, P)
%followCanvas  The overlay on the page of the canvas P as it is now: inside the layout's margin (as figureArea makes the page).
if ~isappdata(P, 'FigureLayout'); return; end
S = getappdata(P, 'FigureLayout');
if ~isstruct(S) || ~isfield(S, 'margin') || ~isfield(S, 'scale'); return; end
sz = getpixelposition(P);
m = S.margin * S.scale;
page = [m, m, max(sz(3:4) - 2 * m, 1)];
if ~isequal(ax.Position, page); ax.Position = page; end
end
