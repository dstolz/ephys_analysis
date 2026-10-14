function figureTimeStack(axs, panels, isTime, labelSize)
%figureTimeStack  One time axis for the time panels stacked in a figure's columns.
%   figureTimeStack(AXS, PANELS, ISTIME, LABELSIZE) goes through the
%   arrangement's columns (PANELS: the figure spec's panels, with row,
%   col, rowSpan and colSpan; AXS(k): panel k's axes, not drawn where it
%   is no graphics object; ISTIME(k): panel k's x axis is time from the
%   event, panelTypes().SharesTime). For each time panel it finds, in every
%   column the panel covers, the nearest drawn panel below it, of any type:
%     every one of them is a time panel showing the same x limits
%         the panel's x tick labels and x label go (the panel below tells
%         the time); a raster panel also drops its y ticks in its bottom
%         tenth, which would run into the top tick label of the panel it
%         sits on (clearRasterEdge), unless its ticks name its blocks
%     otherwise (nothing below, a panel of another kind of x axis such as
%         waveforms, or another time span)  the panel keeps
%         its ticks and is labeled "Time (s)"
%   So a stack sharing the figure's time axis is labeled once, at its
%   bottom, and a panel with a window of its own keeps its own axis.
%   LABELSIZE ([] = the axes' default) is the x label's font size.
%
%   See also renderFigure.
if nargin < 4; labelSize = []; end
np = numel(panels);
drawn = false(1, np);
for k = 1:np
    drawn(k) = k <= numel(axs) && isgraphics(axs(k));
end
time = find(drawn & reshape(isTime(1:np), 1, []));
shown = find(drawn);
rasters = gobjects(1, 0);
for k = time
    p = panels(k);
    bottom = p.row + p.rowSpan - 1;
    hide = true;
    for c = p.col:(p.col + p.colSpan - 1)
        below = shown(arrayfun(@(j) panels(j).row > bottom && panels(j).col <= c && c <= panels(j).col + panels(j).colSpan - 1, shown));
        if isempty(below)
            hide = false;
            break
        end
        [~, i] = min([panels(below).row]);
        b = below(i);
        if ~isTime(b) || ~sameLimits(axs(k), axs(b))
            hide = false;
            break
        end
    end
    ax = axs(k);
    if hide
        ax.XTickLabel = [];
        ax.XLabel.String = '';
        if strcmp(ax.Tag, 'rasterAxes'); rasters(end+1) = ax; end %#ok<AGROW>
    else
        xlabel(ax, 'Time (s)');
        if ~isempty(labelSize); ax.XLabel.FontSize = labelSize; end
    end
end
clearRasterEdge(rasters);
end


function tf = sameLimits(a, b)
%sameLimits  True when the axes A and B show the same x limits.
la = double(xlim(a));
lb = double(xlim(b));
tf = all(abs(la - lb) <= 1e-9 * max(1, abs(diff(la))));
end


function clearRasterEdge(rax)
%clearRasterEdge  Drop the y ticks in the bottom tenth of each raster.
%   A raster sits right on the panel below it, so a label there would run
%   into that panel's top one. The bottom is the last epoch (YDir
%   reverse), or the first otherwise.
%
%   A copy of renderPSTH's local clearRasterEdge, so that no existing
%   renderer changes in phase 1 of the modular figures; phase 2
%   consolidates the two into one shared helper. Unlike the original it
%   leaves alone a raster whose tick labels were set by hand: a raster of
%   several blocks names each block at its middle, and every name stays.
for ra = reshape(rax, 1, [])
    r = ra.YAxis(1);
    if strcmp(r.TickLabelsMode, 'manual'); continue; end
    lim = double(r.Limits);
    tk = r.TickValues;
    up = tk - lim(1);
    if strcmp(ra.YDir, 'reverse'); up = lim(2) - tk; end
    keep = up >= 0.1 * diff(lim);
    if ~all(keep); r.TickValues = tk(keep); end
end
end
