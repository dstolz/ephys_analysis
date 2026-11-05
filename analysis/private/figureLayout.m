function figureLayout(canvas, S)
%figureLayout  Lay out a figure renderFigure drew on CANVAS: each panel's axes and note band at its rect, the title and the legend; again whenever CANVAS changes size.
%   figureLayout(CANVAS, S) measures the room each panel's labels take
%   (its axes' TightInset, on the sides where tick labels, an axis label or
%   a title sit, nothing on a side with none; and a color bar outside), its
%   note's band (the text as drawn, and the panel's labels on that side,
%   which the band holds) and the title; places the panels (figureArea: the
%   page inside the margin and the area under the title; figurePlace: each
%   panel at its rect, its plot area moved in as far as its labels need to
%   stay clear of its neighbors and the page's edge); sets every position
%   in pixels; measures again, since a new size can change the tick
%   labels, and places again when it did; then places the legend and the
%   notes (a note in a band in the part the panel's labels leave free; a
%   note over the panel in its axes, placeNote). S (renderFigure builds
%   it):
%     layout   boxesMean ("plot" | "outer": figurePlace's Mode) and
%              paddingPx (Figure.layout.padding in px at 96 dpi, times the
%              scale: figurePlace's Padding)
%     panels   one per panel drawn: id, axes (its axes, then its extra
%              axes, top to bottom), shares (their shares of its plot
%              area), rect (Panel.rect), fixed (a legend panel: no insets),
%              note (its note's settings), text (the note's text object; []
%              = none), band (the hidden axes holding the text beside the
%              panel; [] = in the axes), layout (optional; [] = the axes
%              stacked by shares; a trial scatter's struct('kind',
%              "marginals", 'size', F, 'xStrip', 'yStrip'): its axes are
%              the plot, its x strip and its y strip, figurePlace's
%              split, and its insets on each side are the largest of its
%              three axes' there: the strips' outer sides are the box's)
%     title    the hidden axes whose title and subtitle are the figure's
%              ([] = none)
%     legend   [] (none) or the figure's legend: handle, mode and, for a
%              legend panel, panel (its index) and options (its type's
%              options). Mode "panel": in the legend panel's box at its
%              natural size, aligned by options.align / valign;
%              options.orientation "auto" lays it out horizontally when the
%              box is wider than tall, options.columns 0 picks the columns
%              (all in a row, horizontal; one column, vertical; more when it
%              would run out of the box). Mode "float": centered in the
%              page's largest free space (EphysAnalysisConfig.freeRect over
%              the panels' rects and their plot areas grown by their
%              labels, in px) when that holds it and Padding round it (at
%              least 4 px), else inside its axes (Location "best"). Done
%              again at every layout, so it follows the panels.
%     margin   px round the figure
%     scale    renderFigure's Scale: the margin and the spacing round notes
%              and color bars times it (figureArea's Scale)
%   CANVAS keeps what was laid out for an editor's overlay (appdata
%   FigureLayoutResult): page, area, title (figureArea's), ids (the
%   panels'), panels (figurePlace's: outer, box, axes, band, nudged,
%   clipped), neighbors (figureNeighbors of the outer boxes), legend (the
%   legend's px box in a legend panel or floating; [] = none or inside a
%   panel) and legendMode ("panel" | "float" | "inside" | "").
%   CANVAS (the figure, panel or tab drawn into: figureCanvas) keeps S
%   (appdata FigureLayout) and lays itself out again from it whenever it
%   changes size: its SizeChangedFcn calls figureLayout(CANVAS), after the
%   callback it had (the app's preview panel centers its busy card with
%   one; kept, not replaced: appdata FigureLayoutFcn is the one set here,
%   so drawing again does not wrap it twice). So the figure follows a
%   panel or window that is resized (MATLAB runs a SizeChangedFcn in a
%   visible figure only); an export figure is laid out at its own size.
%   Once its axes are gone (another drawing in their place) the
%   callback lays out nothing. A canvas too small to hold a figure (under
%   40 px a side: not laid out yet) is left as it is.
%   S with a field layoutFcn (renderProbeFigure: its arithmetic layout) is
%   kept and chained alike, and laid out by calling S.layoutFcn(CANVAS)
%   in place of all this.
%
%   See also renderFigure, figurePlace, figureArea, placeNote.

if nargin < 2
    if ~isvalid(canvas) || ~isappdata(canvas, 'FigureLayout'); return; end
    S = getappdata(canvas, 'FigureLayout');
else
    setappdata(canvas, 'FigureLayout', S);
    fcn = canvas.SizeChangedFcn;
    if ~(isappdata(canvas, 'FigureLayoutFcn') && isequal(getappdata(canvas, 'FigureLayoutFcn'), fcn))
        own = @(c, e) relayout(c, e, fcn);   % a callback its owner set (the app's preview panel's) is kept: called first
        canvas.SizeChangedFcn = own;
        setappdata(canvas, 'FigureLayoutFcn', own);
    end
end
if isfield(S, 'layoutFcn')   % a drawing laid out its own way (renderProbeFigure): its function places it
    S.layoutFcn(canvas);
    return
end
for P = reshape(S.panels, 1, [])
    if any(~isgraphics(P.axes)); return; end   % drawn over since
end
sz = getpixelposition(canvas);
sz = sz(3:4);
if any(sz < 40); return; end

top = 0;
if ~isempty(S.title) && isgraphics(S.title)
    t = S.title.TightInset;   % (in pixels, as renderFigure made it)
    if written(S.title.Title) || written(S.title.Subtitle); top = t(4) + 2 * S.scale; end   % a text of several lines is a column
end
A = figureArea(sz, Top=top, Margin=S.margin, Scale=S.scale);
how = {'Mode', string(S.layout.boxesMean), 'Padding', S.layout.paddingPx};
[cells, deco, bars] = measure(S, {});
L = figurePlace(A, cells, how{:});
place(S, L);
[cells2, deco2] = measure(S, bars);   % the labels at the new sizes: tick labels can change with an axes' size
if ~isempty(cells2) && max([abs([cells2.inset] - [cells.inset]), abs([cells2.need] - [cells.need])]) > 1
    L = figurePlace(A, cells2, how{:});
    place(S, L);
    cells = cells2;
    deco = deco2;
end
[lg, mode] = placeFigureLegend(S, L, cells);
placeNotes(S, L, deco);
ids = strings(1, numel(S.panels));
for k = 1:numel(S.panels); ids(k) = string(S.panels(k).id); end
setappdata(canvas, 'FigureLayoutResult', struct('page', A.page, 'area', A.area, 'title', {A.title}, 'ids', ids, ...
    'panels', {L.panels}, 'neighbors', L.neighbors, 'legend', {lg}, 'legendMode', mode));
end


function relayout(c, e, before)
%relayout  CANVAS's SizeChangedFcn: the callback it had before, then the figure laid out again.
if isa(before, 'function_handle')
    before(c, e);
elseif iscell(before) && ~isempty(before) && isa(before{1}, 'function_handle')
    before{1}(c, e, before{2:end});
end
figureLayout(c);
end


function [cells, deco, bars] = measure(S, bars)
%measure  Each panel for figurePlace: its rect, its insets (the room its labels take) and its note band's need.
%   BARS (one per panel, a row per axes) is the room its color bars take
%   ({} = measure it: reading a color bar is slow, and its room does not
%   change with the axes' size). A legend panel (fixed) has no insets.
cells = struct('rect', {}, 'inset', {}, 'band', {}, 'need', {}, 'shares', {}, 'fixed', {}, 'layout', {});
n = numel(S.panels);
deco = zeros(1, n);   % px the panel's labels take in its band (on the band's side)
if isempty(bars)
    bars = cell(1, n);
    for k = 1:n
        bars{k} = zeros(numel(S.panels(k).axes), 4);
        if S.panels(k).fixed; continue; end
        for i = 1:numel(S.panels(k).axes); bars{k}(i, :) = colorbarRoom(S.panels(k).axes(i), S.scale); end
    end
end
for k = 1:n
    P = S.panels(k);
    side = "";
    need = 0;
    ins = [0 0 0 0];
    lay = [];
    if isfield(P, 'layout'); lay = P.layout; end
    if ~P.fixed
        ins = insetOf(P.axes, bars{k}, lay);
        if ~isempty(P.band) && isgraphics(P.band) && ~isempty(P.text) && isgraphics(P.text)
            side = string(P.note.placement);
            i = find(side == ["left" "below" "right" "above"], 1);
            deco(k) = ins(i);
            ins(i) = 0;   % the band holds the labels on its side
            e = P.text.Extent .* P.band.Position([3 4 3 4]);   % normalized in the band (pixels): its size in pixels
            along = e(4);
            if ismember(side, ["left" "right"]); along = e(3); end
            need = deco(k) + along + 12 * S.scale;
        end
    end
    cells(k) = struct('rect', P.rect, 'inset', ins, 'band', side, 'need', need, 'shares', P.shares, 'fixed', P.fixed, ...
        'layout', lay);
end
end


function ins = insetOf(axs, bars, lay)
%insetOf  The room a panel's labels take round its plot area, [left bottom right top] px: its axes stacked top to bottom.
%   Each side counts only where something sits (tick labels, an axis
%   label, a title, a color bar outside): a tick label that reaches past a
%   corner of the axes is no reason to keep its neighbor away. The top is
%   the first axes', the bottom the last's, the sides the widest. BARS:
%   the room each axes' color bar takes (colorbarRoom). LAY a scatter's
%   marginals (figurePlace): every side the largest of the plot's and its
%   strips' there (left: the plot's or the x strip's, bottom: the plot's
%   or the y strip's, right and top: the strips' (a title on the top
%   strip); the sides they face each other show nothing).
ins = [0 0 0 0];
n = numel(axs);
if isstruct(lay) && isfield(lay, 'kind') && string(lay.kind) == "marginals"
    for i = 1:n
        ax = axs(i);
        if ~strcmp(ax.Units, 'pixels'); ax.Units = 'pixels'; end
        ins = max(ins, max(ax.TightInset .* sidesOf(ax), bars(i, :)));
    end
    return
end
for i = 1:n
    ax = axs(i);
    if ~strcmp(ax.Units, 'pixels'); ax.Units = 'pixels'; end   % (a property set makes the next read lay the figure out again)
    t = ax.TightInset;
    has = sidesOf(ax);
    v = max(t .* has, bars(i, :));
    ins(1) = max(ins(1), v(1));
    ins(3) = max(ins(3), v(3));
    if i == 1; ins(4) = v(4); end
    if i == n; ins(2) = v(2); end
end
end


function has = sidesOf(ax)
%sidesOf  Which sides of an axes hold something, [left bottom right top]: tick labels, an axis label, a title (a color bar: colorbarRoom).
has = false(1, 4);
if ~strcmp(ax.Visible, 'on'); return; end
ys = ax.YAxis;
if numel(ys) > 1
    has(1) = shows(ys(1));
    has(3) = shows(ys(2));
elseif strcmp(ax.YAxisLocation, 'right')
    has(3) = shows(ys(1));
else
    has(1) = shows(ys(1));
end
xs = ax.XAxis(1);
if strcmp(ax.XAxisLocation, 'top')
    has(4) = shows(xs);
else
    has(2) = shows(xs);
end
has(4) = has(4) || written(ax.Title) || written(ax.Subtitle);
end


function r = colorbarRoom(ax, scale)
%colorbarRoom  The room a color bar outside the axes takes beyond its plot area, [left bottom right top] px (TightInset leaves it out).
%   The bar's own place (set by MATLAB beside the plot area) and its tick
%   labels and label, sized from their font (SCALE: the drawing's, for the px between).
r = [0 0 0 0];
cb = ax.Colorbar;
if isempty(cb) || ~isvalid(cb) || ~strcmp(cb.Visible, 'on') || ~endsWith(string(cb.Location), "outside"); return; end
u = cb.Units;
cb.Units = 'pixels';
p = cb.Position;
cb.Units = u;
if ~strcmp(ax.Units, 'pixels'); ax.Units = 'pixels'; end
a = ax.InnerPosition;
px = 96 / 72;
labels = strlength(string(cb.TickLabels));
ticks = 0.6 * cb.FontSize * px * max([0; labels(:)]) + 6 * scale;
label = 0;
lab = cb.Label;   % (read once: slow)
if written(lab); label = 1.5 * lab.FontSize * px; end
across = 1.5 * cb.FontSize * px;   % a bar above or below: its tick labels' height
switch extractBefore(string(cb.Location), "outside")
    case "east",  r(3) = p(1) + p(3) - a(1) - a(3) + ticks + label;
    case "west",  r(1) = a(1) - p(1) + ticks + label;
    case "north", r(4) = p(2) + p(4) - a(2) - a(4) + across + label;
    case "south", r(2) = a(2) - p(2) + across + label;
end
r = max(r, 0);
end


function tf = shows(r)
%shows  A ruler shows tick labels or a label.
tf = strcmp(r.Visible, 'on') && (any(strtrim(string(r.TickLabels)) ~= "") || written(r.Label));
end


function tf = written(t)
%written  A text (a title, an axis label) says something.
tf = strjoin(string(t.String), "") ~= "";
end


function place(S, L)
%place  Every axes, band and the title at its place in L (pixels).
for k = 1:numel(S.panels)
    P = S.panels(k);
    X = L.panels(k).axes;
    for i = 1:numel(P.axes)
        set(P.axes(i), 'Units', 'pixels', 'Position', [X(i, 1:2) max(X(i, 3:4), 1)]);
    end
    if ~isempty(P.band) && isgraphics(P.band) && ~isempty(L.panels(k).band)
        b = L.panels(k).band;
        set(P.band, 'Units', 'pixels', 'Position', [b(1:2) max(b(3:4), 1)]);
    end
end
if ~isempty(S.title) && isgraphics(S.title)
    if isempty(L.title)
        set(S.title, 'Units', 'pixels', 'Position', [L.area(1), L.area(2) + L.area(4), L.area(3), 1]);
    else
        set(S.title, 'Units', 'pixels', 'Position', [L.title(1:3) 1]);   % its title and subtitle sit over this line
    end
end
end


function [box, mode] = placeFigureLegend(S, L, cells)
%placeFigureLegend  The figure's legend where S.legend says: in its legend panel, floating in free space, or inside its axes.
%   BOX: its px box ([] when inside a panel or none); MODE "panel",
%   "float", "inside" or "".
box = [];
mode = "";
if ~isfield(S, 'legend') || ~isstruct(S.legend) || isempty(S.legend); return; end
G = S.legend;
lgd = G.handle;
if isempty(lgd) || ~isgraphics(lgd); return; end
switch string(G.mode)
    case "panel"
        box = legendInPanel(lgd, L.panels(G.panel).box, G.options);
        mode = "panel";
    case "float"
        if ~strcmp(lgd.Units, 'pixels'); lgd.Units = 'pixels'; end
        p = lgd.Position;   % its natural size (never set to another)
        pad = max(S.layout.paddingPx, 4 * S.scale);
        a = L.area;
        R = struct('rect', cell(1, numel(L.panels)));
        for k = 1:numel(L.panels)   % what each panel covers: its rect, and its plot area with its labels round it
            q = L.panels(k);
            in = cells(k).inset;
            lab = [q.box(1:2) - in(1:2), q.box(1:2) + q.box(3:4) + in(3:4)];
            if ~isempty(q.band); lab = [min(lab(1:2), q.band(1:2)), max(lab(3:4), q.band(1:2) + q.band(3:4))]; end
            o = [q.outer(1:2), q.outer(1:2) + q.outer(3:4)];
            e = [min(o(1:2), lab(1:2)), max(o(3:4), lab(3:4))];
            R(k).rect = [(e(1:2) - a(1:2)) ./ a(3:4), (e(3:4) - e(1:2)) ./ a(3:4)];
        end
        f = EphysAnalysisConfig.freeRect(struct('panels', R), MinSize=(p(3:4) + 2 * pad) ./ a(3:4));
        if isempty(f)
            if ~strcmp(lgd.Location, 'best'); lgd.Location = 'best'; end   % no room: inside its axes, where it hides the least
            mode = "inside";
        else
            c = a(1:2) + (f(1:2) + f(3:4) / 2) .* a(3:4);
            lgd.Location = 'none';
            lgd.Position = [c - p(3:4) / 2, p(3:4)];
            box = lgd.Position;
            mode = "float";
        end
    otherwise
        mode = "inside";
end
end


function box = legendInPanel(lgd, box0, o)
%legendInPanel  The legend at its natural size in a legend panel's box BOX0, by the panel's options O; BOX its px box.
%   orientation "auto": horizontal when the box is wider than tall;
%   columns 0: all entries in a row (horizontal) or one column (vertical),
%   more columns (vertical) or fewer (horizontal) when that runs out of
%   the box; else that many. align / valign: where it sits in the box.
lgd.Location = 'none';
if ~strcmp(lgd.Units, 'pixels'); lgd.Units = 'pixels'; end
n = max(1, numel(lgd.String));
orient = string(o.orientation);
if orient == "auto"
    orient = "vertical";
    if box0(3) > box0(4); orient = "horizontal"; end
end
lgd.Orientation = char(orient);
cols = round(double(o.columns));
if cols > 0
    nc = min(cols, n);
elseif orient == "horizontal"
    nc = n;
else
    nc = 1;
end
lgd.NumColumns = nc;
p = lgd.Position;
if cols <= 0 && n > 1
    if orient == "horizontal" && p(3) > box0(3)
        lgd.NumColumns = max(1, floor(nc * box0(3) / p(3)));
        p = lgd.Position;
    elseif orient == "vertical" && p(4) > box0(4)
        lgd.NumColumns = min(n, ceil(p(4) / max(box0(4), 1)));
        p = lgd.Position;
    end
end
x = box0(1) + (box0(3) - p(3)) * shareOf(o.align, ["left" "center" "right"]);
y = box0(2) + (box0(4) - p(4)) * shareOf(o.valign, ["bottom" "middle" "top"]);
lgd.Position = [x y p(3:4)];
box = lgd.Position;
end


function placeNotes(S, L, deco)
%placeNotes  The panels' notes: in a band, in the part its labels leave free; over a panel, in its axes (placeNote).
for k = 1:numel(S.panels)
    P = S.panels(k);
    if isempty(P.text) || ~isgraphics(P.text); continue; end
    if isempty(P.band) || ~isgraphics(P.band) || isempty(L.panels(k).band)
        placeNote(struct('text', P.text, 'host', [], 'layout', []), P.note);
        continue
    end
    b = L.panels(k).band;
    side = string(P.note.placement);
    thick = b(4);
    if ismember(side, ["left" "right"]); thick = b(3); end
    f = min(0.9, deco(k) / max(thick, 1));   % the band's share the panel's labels take, next to the axes
    switch side
        case "below", free = [0 0 1 1 - f];
        case "above", free = [0 f 1 1];
        case "left",  free = [0 0 1 - f 1];
        otherwise,    free = [f 0 1 1];
    end
    placeBandNote(P.text, P.note, free, S.scale);
end
end


function placeBandNote(t, note, fr, scale)
%placeBandNote  A note in the band beside its panel, in the band's free part FR ([x0 y0 x1 y1], normalized); its outline SCALE times 0.75 pt.
%   Along the band by its alignment (below / above: align across the
%   panel; left / right: valign up it), in the middle across it. A note
%   turned a quarter (|sin(rotation)| > 0.7) reads along y: its horizontal
%   alignment comes from valign (bottom / middle / top: left / center /
%   right at +90, mirrored at -90), its vertical alignment is middle, and
%   valign puts it up the band.
if note.box
    t.EdgeColor = t.Color;
    t.LineWidth = 0.75 * scale;
end
t.Units = 'normalized';
alongX = @(s) fr(1) + (fr(3) - fr(1)) * (0.02 + 0.96 * s);
alongY = @(s) fr(2) + (fr(4) - fr(2)) * (0.02 + 0.96 * s);
midX = (fr(1) + fr(3)) / 2;
midY = (fr(2) + fr(4)) / 2;
across = ismember(string(note.placement), ["below" "above"]);
sv = shareOf(note.valign, ["bottom" "middle" "top"]);
if abs(sind(note.rotation)) > 0.7
    order = ["left" "center" "right"];
    if sind(note.rotation) < 0; order = flip(order); end
    t.HorizontalAlignment = char(order(round(2 * sv) + 1));
    t.VerticalAlignment = 'middle';
    if across
        t.Position = [alongX(shareOf(note.align, ["left" "center" "right"])), alongY(sv), 0];
    else
        t.Position = [midX, alongY(sv), 0];
    end
elseif across
    t.Position = [alongX(shareOf(note.align, ["left" "center" "right"])), midY, 0];
    t.HorizontalAlignment = char(note.align);
    t.VerticalAlignment = 'middle';
else
    t.Position = [midX, alongY(sv), 0];
    t.HorizontalAlignment = 'center';
    t.VerticalAlignment = char(note.valign);
end
end


function s = shareOf(v, order)
%shareOf  0, 0.5 or 1 for the first, second or third of ORDER (0.5 when V is none of them).
s = (find(string(v) == order, 1) - 1) / 2;
if isempty(s); s = 0.5; end
end
