function hidden = figureTimeStack(axs, panels, isTime, labelSize, sided)
%figureTimeStack  One time axis for the time panels stacked flush on the page.
%   HIDDEN = figureTimeStack(AXS, PANELS, ISTIME, LABELSIZE) reads the
%   stacks from the panels' rects (PANELS: the figure spec's panels, with
%   rect; AXS(k): panel k's axes, not drawn where it is no graphics object;
%   ISTIME(k): panel k's x axis is time from the event, panelTypes().
%   SharesTime). For each drawn time panel it takes the panels that touch
%   it on the side of its x axis (PANELS(k).xSide: those below it for
%   "bottom", above it for "top"; figureNeighbors' below / above at
%   EphysAnalysisConfig.RectTol: an edge within RectTol of the panel's, and
%   at least half the narrower one's width shared), of any type:
%     there is one, and every one of them is drawn, a time panel showing
%         the same x limits (above it: one whose x axis is on top too)
%         the panel's x tick labels and x label go (the panel there tells
%         the time); a raster panel also drops its y ticks in its tenth on
%         that side, which would run into the tick label of the panel it
%         sits against (clearRasterEdge), unless its ticks name its blocks
%     otherwise (nothing touching it there -- a gap between two panels
%         keeps both their tick labels --, a panel of another kind of x
%         axis such as waveforms, a legend panel, or another time span)
%         the panel keeps its ticks and is labeled PANELS(k).xLabel,
%         "Time (s)" when that is ""
%   So a stack sharing the figure's time axis is labeled once, at its
%   bottom (at its top when every x axis of it is on top), and a panel with
%   a window of its own keeps its own axis. Where a panel with its x axis
%   at the bottom sits on one with its x axis on top, the lower one's tells
%   the time between them.
%   LABELSIZE ([] = the axes' default) is the x label's font size. SIDED(k)
%   (default none): panel k's axes are narrower than its rect (its note
%   takes a band left or right of them: renderFigure): neither it nor a
%   panel it sits on drops its time tick labels. HIDDEN(k): panel k's x
%   tick labels and x label went (renderFigure keeps it: a new x label
%   text of that panel shows nothing).
%
%   See also renderFigure, figureNeighbors.
if nargin < 4; labelSize = []; end
if nargin < 5; sided = false(1, numel(panels)); end
np = numel(panels);
hidden = false(1, np);
if np == 0; return; end
drawn = false(1, np);
for k = 1:np
    drawn(k) = k <= numel(axs) && isgraphics(axs(k));
end
isTime = reshape(logical(isTime(1:np)), 1, []);
N = figureNeighbors(reshape([panels.rect], 4, []).', EphysAnalysisConfig.RectTol);
up = [panels.xSide] == "top";
rasters = gobjects(1, 0);
edges = strings(1, 0);   % each of them: the side it sits against its neighbor
for k = find(drawn & isTime)
    p = panels(k);
    if up(k)
        near = find(N.above(k, :));
    else
        near = find(N.below(k, :));
    end
    hide = ~isempty(near) && ~sided(k) && all(drawn(near)) && all(isTime(near)) && ~any(sided(near)) ...
        && all(arrayfun(@(b) sameLimits(axs(k), axs(b)), near)) && (~up(k) || all(up(near)));
    ax = axs(k);
    hidden(k) = hide;
    if hide
        ax.XTickLabel = [];
        ax.XLabel.String = '';
        if strcmp(ax.Tag, 'rasterAxes')
            rasters(end+1) = ax; %#ok<AGROW>
            edges(end+1) = p.xSide; %#ok<AGROW>
        end
    else
        name = p.xLabel;
        if name == ""; name = "Time (s)"; end
        xlabel(ax, name, 'Interpreter', 'none');
        if ~isempty(labelSize); ax.XLabel.FontSize = labelSize; end
    end
end
clearRasterEdge(rasters, edges);
end


function tf = sameLimits(a, b)
%sameLimits  True when the axes A and B show the same x limits.
la = double(xlim(a));
lb = double(xlim(b));
tf = all(abs(la - lb) <= 1e-9 * max(1, abs(diff(la))));
end


function clearRasterEdge(rax, edges)
%clearRasterEdge  Drop the y ticks in the tenth of each raster on its EDGES side ("bottom" or "top").
%   A raster sits right on the panel below it (above it: EDGES "top"), so
%   a label there would run into that panel's nearest one. The bottom is
%   the last epoch (YDir reverse), or the first otherwise.
%
%   It leaves alone a raster whose tick labels were set by hand: a raster of
%   several blocks names each block at its middle, and every name stays.
for i = 1:numel(rax)
    ra = rax(i);
    r = ra.YAxis(1);
    if strcmp(r.TickLabelsMode, 'manual'); continue; end
    lim = double(r.Limits);
    tk = r.TickValues;
    up = tk - lim(1);   % from the bottom edge
    if strcmp(ra.YDir, 'reverse'); up = lim(2) - tk; end
    if edges(i) == "top"; up = diff(lim) - up; end   % from the top edge
    keep = up >= 0.1 * diff(lim);
    if ~all(keep); r.TickValues = tk(keep); end
end
end
