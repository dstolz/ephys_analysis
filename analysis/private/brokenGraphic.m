function S = brokenGraphic(ax, msg, opts)
%brokenGraphic  A "cannot draw" sign in a figure panel, in place of a message: the message shows on hover and on a click.
%   S = brokenGraphic(AX, MSG) draws, in the middle of AX, a light gray
%   square struck through by a red cross: a panel that cannot be drawn
%   says so at a glance, with no text to run over its neighbors. The sign
%   is two marker lines (S: the square, the cross; Tag ROLE), so it keeps
%   its size in pixels whatever AX's size and limits, and it is left out of
%   AX's automatic limits and of every legend. A listener on AX
%   (MarkedClean) keeps it where it belongs when AX's limits or size change
%   (a time panel's window, a y range, figureLayout).
%
%   MSG is the reason (a string array: one line each). It is kept on both
%   lines (appdata "LayerNote", the lines joined by newline) and shown
%     - in a window over the figure (uialert, titled TITLE) on a plain click
%       on the sign; a Ctrl+, Shift+ or right-click goes on to AX's own
%       ButtonDownFcn (a figure panel's selection: figurePickable);
%     - as the sign's data tip, where MATLAB shows data tips on hover;
%     - in a visible figure drawn in a panel or tab (the analysis app's
%       preview), on hover over the sign: brokenGraphicTips lays a
%       transparent image with MSG as its tooltip over it (renderFigure
%       and renderProbeFigure call it once the figure is laid out).
%
%   Options
%     Where     "center" (default): the sign in AX's middle (a panel or tile
%               with nothing drawn); "corner": smaller, at AX's bottom
%               left (a panel that drew some of its layers)
%     FontSize  the figure's font size, points (default 10): the sign's
%               size follows it (2x for "center", 1.1x for "corner")
%     Role      the lines' Tag (tagPart; default "layerNote")
%     Title     the alert's title (default "Cannot draw")
%
%   See also figLayerNotes, brokenGraphicTips, renderFigure, renderProbeFigure.
arguments
    ax (1,1) {mustBeA(ax, ["matlab.graphics.axis.Axes" "matlab.ui.control.UIAxes"])}
    msg string
    opts.Where (1,1) string {mustBeMember(opts.Where, ["center" "corner"])} = "center"
    opts.FontSize (1,1) double {mustBePositive} = 10
    opts.Role (1,1) string = "layerNote"
    opts.Title (1,1) string = "Cannot draw"
end
msg = reshape(msg(strtrim(msg) ~= ""), [], 1);
txt = strjoin(msg, newline);
if txt == ""; txt = "This panel cannot be drawn."; end
center = opts.Where == "center";
sz = opts.FontSize * (2 * center + 1.1 * ~center);   % the square's size, points
common = {'Parent', ax, 'XData', NaN, 'YData', NaN, 'LineStyle', 'none', 'Clipping', 'off'};
fr = matlab.graphics.chart.primitive.Line(common{:}, 'Marker', 's', 'MarkerSize', sz, ...
    'MarkerEdgeColor', [0.55 0.55 0.55], 'MarkerFaceColor', [0.96 0.96 0.96], 'LineWidth', 0.6 + 0.6 * center);
cr = matlab.graphics.chart.primitive.Line(common{:}, 'Marker', 'x', 'MarkerSize', 0.55 * sz, ...
    'MarkerEdgeColor', [0.80 0.25 0.20], 'LineWidth', 1.2 + 0.8 * center);
S = [fr cr];
lines = wrapLines(txt, 60);
rows = dataTipTextRow("", {char(lines(1))});
for k = 2:numel(lines)
    rows(end+1, 1) = dataTipTextRow("", {char(lines(k))}); %#ok<AGROW>
end
for s = S
    s.Annotation.LegendInformation.IconDisplayStyle = 'off';
    try
        set(s, 'XLimInclude', 'off', 'YLimInclude', 'off');   % (hidden properties: the sign never moves AX's automatic limits)
    catch
    end
    s.DataTipTemplate.DataTipRows = rows;
    s.DataTipTemplate.Interpreter = 'none';
    setappdata(s, 'LayerNote', txt);
    s.ButtonDownFcn = @(src, ~) onClick(src);
end
tagPart(S, opts.Role);
setappdata(cr, 'LayerNoteSquare', fr);
% what brokenGraphicTips needs: the wrapped lines, and how to place the image and show the message
U = struct('where', opts.Where, 'title', opts.Title, 'cross', cr, 'lines', lines, 'at', [0.5 0.5], 'overlay', [], ...
    'place', @() placeSign(fr), 'show', @() showMessage(fr));
setappdata(fr, 'LayerNoteSign', U);
setappdata(fr, 'LayerNoteListener', listener(ax, 'MarkedClean', @(~, ~) followAxes(fr)));   % (dies with the square)
fr.DeleteFcn = @(src, ~) dropOverlay(src);
placeSign(fr);
end


function out = wrapLines(txt, width)
%wrapLines  TXT's lines, each broken at spaces into lines of at most WIDTH characters (a longer word stays whole).
out = strings(0, 1);
for line = reshape(splitlines(string(txt)), 1, [])
    words = split(strtrim(line), " ");
    cur = "";
    for w = reshape(words, 1, [])
        if cur == ""
            cur = w;
        elseif strlength(cur) + 1 + strlength(w) <= width
            cur = cur + " " + w;
        else
            out(end+1, 1) = cur; %#ok<AGROW>
            cur = w;
        end
    end
    out(end+1, 1) = cur; %#ok<AGROW>
end
if isempty(out); out = ""; end
end


function followAxes(fr)
%followAxes  AX was drawn again: the sign back at its place (when its limits or size moved it) and its tooltip image with it.
if ~isvalid(fr); return; end
placeSign(fr);
end


function placeSign(fr)
%placeSign  Put the sign at its place in its axes' plot box: the middle, or the bottom left a few pixels in.
ax = fr.Parent;
if ~isgraphics(ax); return; end
U = getappdata(fr, 'LayerNoteSign');
at = [0.5 0.5];
px = axesPixels(ax);
if U.where == "corner"
    half = fr.MarkerSize * 96 / 72 / 2 + 3;   % its half-size and a margin, pixels
    at = min(half ./ max(px(3:4), 1), 0.5);
end
try
    x = toData(ax.XLim, ax.XScale, ax.XDir, at(1));
    y = toData(ax.YLim, ax.YScale, ax.YDir, at(2));
catch
    return   % (limits that are no numbers: left where it is)
end
if ~isequal([fr.XData fr.YData], [x y])
    set([fr U.cross], 'XData', x, 'YData', y);
end
U.at = at;
setappdata(fr, 'LayerNoteSign', U);
placeOverlay(fr, U, px);
end


function v = toData(lim, scale, dir, t)
%toData  The value at T (0-1) of an axis with limits LIM, its scale and direction.
lim = double(lim);
if strcmp(dir, 'reverse'); t = 1 - t; end
if strcmp(scale, 'log') && all(lim > 0)
    v = 10 ^ (log10(lim(1)) + t * (log10(lim(2)) - log10(lim(1))));
else
    v = lim(1) + t * (lim(2) - lim(1));
end
end


function p = axesPixels(ax)
%axesPixels  AX's plot box in pixels in its parent (figureLayout sets pixels).
if strcmp(ax.Units, 'pixels')
    p = ax.InnerPosition;
else
    p = getpixelposition(ax);
end
end


function placeOverlay(fr, U, px)
%placeOverlay  The sign's tooltip image (brokenGraphicTips) over it, at its size.
o = U.overlay;
if isempty(o) || ~isvalid(o); return; end
w = fr.MarkerSize * 96 / 72 + 6;
c = px(1:2) + U.at .* px(3:4);
o.Position = [c - w / 2, w, w];
end


function dropOverlay(fr)
%dropOverlay  The square is deleted (its panel drawn again, the figure emptied): its tooltip image goes with it.
if ~isappdata(fr, 'LayerNoteSign'); return; end
U = getappdata(fr, 'LayerNoteSign');
if ~isempty(U.overlay) && isvalid(U.overlay); delete(U.overlay); end
end


function onClick(src)
%onClick  A plain click on the sign shows its message; any other click goes on to the axes' own ButtonDownFcn.
fig = ancestor(src, 'figure');
if isempty(fig); return; end
if ~strcmp(fig.SelectionType, 'normal')
    ax = ancestor(src, 'axes');
    if ~isempty(ax) && isa(ax.ButtonDownFcn, 'function_handle'); ax.ButtonDownFcn(ax, []); end
    return
end
sq = src;
if isappdata(src, 'LayerNoteSquare'); sq = getappdata(src, 'LayerNoteSquare'); end   % the cross: its square holds the sign
showMessage(sq);
end


function showMessage(fr)
%showMessage  The sign's message in a window over its figure (uialert; a message box where that cannot go).
if ~isvalid(fr); return; end
fig = ancestor(fr, 'figure');
U = getappdata(fr, 'LayerNoteSign');
txt = getappdata(fr, 'LayerNote');
try
    uialert(fig, txt, U.title, 'Icon', 'warning');
catch
    msgbox(txt, U.title, 'warn');
end
end
