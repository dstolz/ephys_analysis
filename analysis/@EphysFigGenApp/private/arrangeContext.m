function C = arrangeContext(obj, id)
%arrangeContext  What Arrange needs to move, resize or place panel ID of the selected figure: its rect, the others', the snap step and reach.
%   C = arrangeContext(OBJ, ID), ID a panel's id, ":legend" (the floating
%   legend's box) or "" (a new panel: every panel is another), is a
%   struct ([] with no figure selected, or no panel ID):
%     k, j      the figure (index into Config.Figures) and the panel (into
%               its panels; 0 for ":legend" and "")
%     w         the panel's widget in the overlay ([] when none)
%     rect0     its rect as the config holds it (the legend's box as the
%               layout placed it; [] for "")
%     others    the other panels' rects, a row each, and names their ids
%     step      the snap step [x y], 0-1 of the page (FigureSnapStep,
%               converted on the figure's export page: figureRectConvert)
%     tol       how near snapping reaches [x y]: 6 preview px, 0-1 of the
%               page
%     pagePx    the page's size on the preview, px (the overlay's, else the
%               last layout's, else the export page at its dpi)
%     pageCm, dpi   the figure's export page and dpi (figurePage)
%     alt       Alt (Option) is held (the window's CurrentModifier): no
%               snapping
%
%   See also EphysFigGenApp.onArrangeMoving, EphysFigGenApp.nudgePanel, snapRect.
C = [];
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
fig = obj.Config.Figures(k);
n = numel(fig.panels);
ids = strings(1, n);
R = NaN(n, 4);
for q = 1:n
    ids(q) = fig.panels(q).id;
    v = double(fig.panels(q).rect);
    if numel(v) == 4; R(q, :) = reshape(v, 1, 4); end
end
O = obj.FigureArrangeOverlay;
hasO = isstruct(O) && ~isempty(O.axes) && isvalid(O.axes);
w = [];
j = 0;
switch id
    case ":legend"
        if ~hasO || isempty(O.legend) || ~isvalid(O.legend) || isempty(O.legendRect); return; end
        w = O.legend;
        rect0 = O.legendRect;
        others = R;
        names = ids;
    case ""
        rect0 = [];
        others = R;
        names = ids;
    otherwise
        j = find(ids == id, 1);
        if isempty(j); return; end
        rect0 = R(j, :);
        keep = [1:j-1, j+1:n];
        others = R(keep, :);
        names = ids(keep);
        if hasO && isKey(O.widgets, char(id)); w = O.widgets(char(id)); end
end
[pageCm, dpi] = figurePage(obj, fig);
pagePx = pageCm / 2.54 * dpi;
P = obj.FigurePreviewPanel;
if hasO
    pagePx = O.axes.Position(3:4);
elseif ~isempty(P) && isvalid(P) && isappdata(P, 'FigureLayoutResult')
    L = getappdata(P, 'FigureLayoutResult');
    if isstruct(L) && isfield(L, 'page') && numel(L.page) == 4; pagePx = L.page(3:4); end
end
pagePx = max(double(pagePx), 1);
st = obj.FigureSnapStep;
if ~(isstruct(st) && isfield(st, 'value') && isfield(st, 'units') && isnumeric(st.value) && isscalar(st.value) ...
        && st.value > 0 && ismember(string(st.units), EphysAnalysisConfig.RectUnits))
    st = struct('value', 0.5, 'units', "cm");   % (snapStepIn's default)
end
step = [figureRectConvert(double(st.value), string(st.units), "normalized", pageCm, dpi, "x"), ...
    figureRectConvert(double(st.value), string(st.units), "normalized", pageCm, dpi, "y")];
alt = false;
try
    alt = any(string(obj.Fig.CurrentModifier) == "alt");
catch
end
C = struct('k', k, 'j', j, 'w', w, 'rect0', rect0, 'others', others, 'names', names, 'step', step, ...
    'tol', 6 ./ pagePx, 'pagePx', pagePx, 'pageCm', pageCm, 'dpi', dpi, 'alt', alt);
end
