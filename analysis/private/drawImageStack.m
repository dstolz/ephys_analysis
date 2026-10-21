function [L, hLegend] = drawImageStack(ax, x, y, Z, names, colors, spacing, role)
%drawImageStack  Images over one x axis stacked as rows, the first on top, each with its group's color strip.
%   [L, HLEGEND] = drawImageStack(AX, X, Y, Z, NAMES, COLORS, SPACING, ROLE)
%   draws Z (nY x nX x n: one image per trial group, its rows at the
%   ascending values Y, e.g. frequencies, its columns at X, e.g. time from
%   the event) into AX as n blocks one above the other, block 1 on top (as
%   a raster lists its groups), each block spanning Y's range plus half a
%   bin either side; SPACING is the block step x the block's height
%   (stackLayout with Image: never below 1, no overlap). Every image is
%   tagged ROLE (default "image") with its group's name NAMES(g); where it
%   is NaN it is transparent. Each block gets a thin strip of its group's
%   color (COLORS(g, :)) along its left edge (role "rasterBand", as a heat
%   map of trials marks its groups) and a thin gray line along its bottom
%   (role "stackBase", carrying 'StackMap' for the data tips:
%   stackBaseLines), the left y axis a tick at each block's middle labeled
%   with its name. The images share AX's colormap and color limits (the
%   caller sets them: one scale, one color bar for every block). YDir is
%   normal and AX is held off afterwards. L is the stackLayout (its
%   offset: where each block's Y = 0 lies); HLEGEND (1 x n) a color swatch
%   per group for the figure's legend (role "rasterBand"). Used by a
%   stacked spectrogram (drawSpectrogramPanel) and coherogram
%   (drawCoherencePanel).
%
%   See also stackLayout, stackBaseLines, drawSpectrogramPanel, drawCoherencePanel.
arguments
    ax
    x double
    y double
    Z double
    names string
    colors double
    spacing (1,1) double = 1
    role (1,1) string = "image"
end
x = double(x(:)).';
y = double(y(:)).';
n = size(Z, 3);
dy = 1;
if numel(y) > 1; dy = median(diff(y)); end
lo = y(1) - dy / 2;
hi = y(end) + dy / 2;
L = stackLayout(repmat(lo, 1, n), repmat(hi, 1, n), spacing, Image=true);
hLegend = gobjects(1, n);
for g = 1:n
    M = Z(:, :, g);
    tagPart(imagesc(ax, x, y + L.offset(g), M, 'AlphaData', double(isfinite(M))), role, names(g));
    if g == 1; hold(ax, 'on'); end   % imagesc resets an axes it does not hold
end
if n == 0; hold(ax, 'on'); end
xr = [x(1) x(end)];
if numel(x) > 1; xr = xr + [-1 1] * median(diff(x)) / 2; end
w = 0.025 * diff(xr);
if ~(w > 0); w = 0.01; end
for g = 1:n
    c = colors(min(g, size(colors, 1)), :);
    yb = L.base(g) + [0 0 L.height L.height];
    tagPart(patch(ax, xr(1) + [0 w w 0], yb, c, 'EdgeColor', 'none', 'HandleVisibility', 'off'), "rasterBand", names(g));
    hLegend(g) = tagPart(patch(ax, 'XData', NaN, 'YData', NaN, 'FaceColor', c, 'EdgeColor', 'none'), "rasterBand", names(g));
end
if n > 1; stackBaseLines(ax, xr, L, names, Zero=false); end
hold(ax, 'off');
set(ax, 'YDir', 'normal', 'Layer', 'top');
if n > 0
    ylim(ax, [L.base(end) L.top(1)]);
    set(ax, 'YTick', fliplr(L.mid), 'YTickLabel', cellstr(flip(reshape(names, 1, []))), 'TickLabelInterpreter', 'none');
end
end
