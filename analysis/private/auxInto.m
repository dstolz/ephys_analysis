function auxInto(ax, A, X, W, style, over, label, opt)
%auxInto  Draw the aux traces of A (auxMean) into the axes AX.
%   auxInto(AX, A, X, W, STYLE, OVER, LABEL, OPT) draws every trace of A -- each
%   channel's statistic (the mean or median over the epochs), or the
%   magnitude's, per group -- as X (auxLooks) says, on the time axis W
%   ([t0 t1] s, the plot's). OPT.display chooses how:
%     "lines"    a line per trace, with each trace's error band under it
%                when OPT.errorType is not "off" (A.err: the statistic +/-
%                SEM or SD, a bootstrap 95% CI or the interquartile range,
%                over the epochs; errorPatch in STYLE's Error* look)
%     "stacked"  a row of its own per trace (X.rows: a channel's groups
%                together, the first at the top), every row on the same
%                amplitude scale and centered on its median over W, its
%                label (the channel, the group, or both) at its tick, a scale
%                bar the size of half a row spacing; the bands as in "lines"
%     "heatmap"  an image, a row per trace and time across, on one color
%                scale: the range of the traces in W (symmetric about 0 when
%                they run both ways, a diverging map; else the design's heat
%                map), or OPT.yLim when that is set. A bar in the color of
%                each row's group or channel sits at its left edge (none for a
%                trace with no group); the scale is written in the corner.
%                No bands. Needs a panel of its own: with OVER it is drawn
%                as "lines"
%   The lines are tagged "auxTrace", the bands "auxSem", the image
%   "auxImage", the group bars "auxGroup" and the scale bar or text
%   "auxScale" (the group or channel label as the group; tagPart), the
%   lines kept out of legends (auxStandIns stands in for them there).
%     OVER false  AX is an aux panel of its own: the bands are opaque by
%                 default (as the PSTH's), the axes styled (styleAxes, without
%                 Style.YLim: that is for rates) and the y axis automatic
%     OVER true   the traces go on AX's right y axis (yyaxis), over what
%                 AX shows (a PSTH's rate, a raster's rows): the bands are
%                 semitransparent (opacity 0.2, unless ErrorFaceAlpha sets
%                 one), so what is under them shows through.
%                 The left side is the active one again after, both y
%                 axes in AX's x axis color
%   LABEL true names the aux y axis (the panel's, or AX's right one)
%   X.label; false (a grid, whose layout names its panels) leaves it.
%   OPT (a plot's aux settings, defaults("Aux"); default: its defaults)
%   sets the scale and, over a plot, the place:
%     yLim          [lo hi] in A's units: the signal's y limits (a panel's
%                   y axis, or the part of the right axis the signal spans;
%                   stacked: the span each row has; heat map: the color
%                   scale); [] = from the traces, and their bands when
%                   drawn, in W
%     overPosition  OVER: [bottom top], fractions 0-1 of AX's height, where
%                   the signal's y limits sit: [0 0.3] puts it in the bottom
%                   three tenths. The right axis' limits are set so that its
%                   lo and hi fall there, and its ticks (at most three, at
%                   round values) stay between them. [0 1] (default) with
%                   yLim [] leaves the right axis automatic, the whole height
%   A value outside yLim is still drawn at its place on the scale, so it
%   runs past the span (up to the axes' edge, where it is clipped).
%
%   See also auxLooks, auxStandIns, renderPSTH, renderRaster.

if nargin < 8 || isempty(opt); opt = struct(); end
opt = EphysAnalysisConfig.normalizeSection("Aux", opt);
display = opt.display;
if over && display == "heatmap"; display = "lines"; end   % no room for an image on a plot's right axis
if over
    yyaxis(ax, 'right');
    ax.LineStyleOrder = '-';   % a yyaxis side cycles through markers otherwise
    ax.YDir = 'normal';        % the active side's: a raster's rows run down on the left
end
held = ishold(ax);
hold(ax, 'on');
t = A.t(:);
[eLo, eHi] = resultBounds(A, 'mean');
bands = opt.errorType ~= "off" && display ~= "heatmap";
alpha = NaN;
if over; alpha = 0.2; end
fixed = numel(opt.yLim) == 2 && all(isfinite(opt.yLim)) && opt.yLim(2) > opt.yLim(1);
d = [];       % the signal's span on the axis, when it is not automatic
rowTicks = [];
switch display
    case "lines"
        linesInto(ax, A, X, t, eLo, eHi, style, bands, alpha);
        if fixed; d = opt.yLim; end
    case "stacked"
        [d, rowTicks] = stackInto(ax, A, X, t, eLo, eHi, W, style, bands, alpha, fixed, opt.yLim);
    case "heatmap"
        heatInto(ax, A, X, t, W, style, fixed, opt.yLim);
end
if ~held; hold(ax, 'off'); end
xlim(ax, W);
if label; ylabel(ax, X.label, 'Interpreter', 'none'); end
if over
    pos = opt.overPosition;
    if ~(numel(pos) == 2 && all(isfinite(pos)) && pos(1) >= 0 && pos(2) <= 1 && pos(2) > pos(1)); pos = [0 1]; end
    if display == "lines" && ~fixed && ~isequal(pos, [0 1])
        d = autoRange(A, eLo, eHi, W, bands);
    end
    if ~isempty(d)
        span = diff(d) / diff(pos);   % the right axis' range for the whole height
        ylim(ax, [d(1) - pos(1) * span, d(2) + (1 - pos(2)) * span]);
        if display == "lines" && ~isequal(pos, [0 1])
            ax.YAxis(2).TickValues = roundTicks(d, 3);   % the signal's own scale, along its span only
        end
    end
    if ~isempty(rowTicks)
        ax.YAxis(2).TickValues = rowTicks.values;
        ax.YAxis(2).TickLabels = cellstr(rowTicks.labels);
    end
    yyaxis(ax, 'left');
    set(ax.YAxis, 'Color', ax.XAxis.Color);
else
    flat = style;
    flat.YLim = [];
    styleAxes(ax, flat);
    switch display
        case "lines"
            if fixed; ylim(ax, opt.yLim); end
        case "stacked"
            ylim(ax, d);
            setRowTicks(ax, rowTicks);
        case "heatmap"
            grid(ax, 'off');
    end
end
end


function linesInto(ax, A, X, t, eLo, eHi, style, bands, alpha)
%linesInto  A line per trace, each with its band under it.
[~, nTr, nGa] = size(A.mean);
for g = 1:nGa
    for c = 1:nTr
        L = X.trace(c, g);
        m = double(A.mean(:, c, g));
        if bands
            errorPatch(ax, t, eLo(:, c, g), eHi(:, c, g), L.color, L.group, style, "auxSem", alpha);
        end
        tagPart(line(ax, t, m, 'Color', L.color, 'LineStyle', char(L.lineStyle), 'LineWidth', style.LineWidth, ...
            'HandleVisibility', 'off'), "auxTrace", L.group);
    end
end
end


function [d, rowTicks] = stackInto(ax, A, X, t, eLo, eHi, W, style, bands, alpha, fixed, yLim)
%stackInto  The traces as rows, the first on top, on one amplitude scale, each centered on its median in W.
%   D: the rows' span [lo hi] on the axis; ROWTICKS: the rows' tick values and labels.
rows = X.rows;
nR = numel(rows);
in = t >= W(1) - 1e-12 & t <= W(2) + 1e-12;
cen = zeros(nR, 1);
amp = 0;
for r = 1:nR
    m = double(A.mean(:, rows(r).c, rows(r).g));
    v = m(in & isfinite(m));
    if isempty(v); continue; end
    cen(r) = median(v);
    if bands
        lo = double(eLo(:, rows(r).c, rows(r).g));
        hi = double(eHi(:, rows(r).c, rows(r).g));
        v = [v; lo(in & isfinite(lo)); hi(in & isfinite(hi))]; %#ok<AGROW>
    end
    amp = max(amp, max(v) - min(v));
end
if fixed
    step = diff(yLim);
else
    step = 1.15 * amp;
end
if ~(step > 0); step = 1; end
off = (nR - (1:nR)) * step;   % the first row on top
for r = 1:nR
    c = rows(r).c; g = rows(r).g;
    L = X.trace(c, g);
    m = double(A.mean(:, c, g)) - cen(r) + off(r);
    if bands
        errorPatch(ax, t, double(eLo(:, c, g)) - cen(r) + off(r), double(eHi(:, c, g)) - cen(r) + off(r), ...
            L.color, L.group, style, "auxSem", alpha);
    end
    tagPart(line(ax, t, m, 'Color', L.color, 'LineStyle', char(L.lineStyle), 'LineWidth', style.LineWidth, ...
        'HandleVisibility', 'off'), "auxTrace", L.group);
end
d = [-0.6 * step, (nR - 1) * step + 0.6 * step];
% a scale bar at the right edge of the bottom row, half a row spacing at most
len = niceLength(step / 2);
x1 = W(2) - 0.02 * diff(W);
y0 = off(end) - 0.5 * step + 0.05 * step;
tagPart(line(ax, [x1 x1], [y0 y0 + len], 'Color', ax.XColor, 'LineWidth', 1.5, 'HandleVisibility', 'off'), "auxScale");
tagPart(text(ax, x1 - 0.015 * diff(W), y0 + len / 2, sprintf('%.3g %s', len, A.units), 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'middle', 'FontSize', max(6, style.FontSize - 2), 'Color', ax.XColor, 'Interpreter', 'none', ...
    'Clipping', 'on', 'HandleVisibility', 'off'), "auxScale");
keep = 1:max(1, ceil(nR / 6)):nR;   % at most six row labels
rowTicks = struct('values', fliplr(off(keep)), 'labels', fliplr([rows(keep).label]));
end


function setRowTicks(ax, rowTicks)
%setRowTicks  Label the rows' places on AX's y axis (ascending values).
ax.YAxis(1).TickValues = rowTicks.values;
ax.YAxis(1).TickLabels = cellstr(rowTicks.labels);
ax.TickLabelInterpreter = 'none';
end


function heatInto(ax, A, X, t, W, style, fixed, yLim)
%heatInto  The traces as an image, a row each, on one color scale, with a bar of each row's color at its left.
rows = X.rows;
nR = numel(rows);
M = NaN(nR, numel(t));
for r = 1:nR
    M(r, :) = double(A.mean(:, rows(r).c, rows(r).g)).';
end
in = t >= W(1) - 1e-12 & t <= W(2) + 1e-12;
v = M(:, in);
v = v(isfinite(v));
if fixed
    c0 = yLim;
elseif isempty(v)
    c0 = [0 1];
else
    c0 = [min(v) max(v)];
    if c0(1) < 0 && c0(2) > 0
        c0 = max(abs(c0)) * [-1 1];   % both ways: a scale symmetric about zero
    end
    if ~(c0(2) > c0(1)); c0 = c0 + [-0.5 0.5]; end
end
signed = c0(1) < 0 && c0(2) > 0;
if style.HeatColormap ~= ""
    cmap = feval(char(style.HeatColormap), 256);
elseif signed
    cmap = designColormap(style, ["diverging" "heat"], "blueWhiteRed");
else
    cmap = designColormap(style, "heat", "parula");
end
tagPart(imagesc(ax, t, 1:nR, M, 'AlphaData', double(isfinite(M))), "auxImage");
set(ax, 'YDir', 'reverse');
colormap(ax, cmap);
clim(ax, c0);
ylim(ax, [0.5 nR + 0.5]);
w = 0.02 * diff(W);
for r = 1:nR
    col = rows(r).color;
    if all(abs(col - X.neutral) < 1e-9); continue; end   % no group, one channel: nothing to tell apart
    tagPart(patch(ax, W(1) + [0 w w 0], r + [-0.5 -0.5 0.5 0.5], col, 'EdgeColor', 'none', 'HandleVisibility', 'off'), ...
        "auxGroup", X.trace(rows(r).c, rows(r).g).group);
end
keep = 1:max(1, ceil(nR / 6)):nR;   % at most six row labels
set(ax, 'YTick', keep, 'YTickLabel', cellstr([rows(keep).label]), 'TickLabelInterpreter', 'none');
ground = ax.Color;
if ~(isnumeric(ground) && numel(ground) == 3); ground = [1 1 1]; end
tagPart(text(ax, W(2), 0.5, sprintf('%.3g to %.3g %s', c0(1), c0(2), A.units), 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'top', 'FontSize', max(6, style.FontSize - 2), 'Color', ax.XColor, 'BackgroundColor', ground, ...
    'Margin', 1, 'Interpreter', 'none', 'Clipping', 'on', 'HandleVisibility', 'off'), "auxScale");
end


function len = niceLength(x)
%niceLength  The largest of 1, 2 or 5 x 10^k not above X (X itself when it is not positive and finite).
len = x;
if ~(isfinite(x) && x > 0); return; end
e = floor(log10(x));
for m = [5 2 1]
    if m * 10^e <= x * (1 + 1e-9)
        len = m * 10^e;
        return
    end
end
end


function d = autoRange(A, lo, hi, W, withBands)
%autoRange  The traces' range inside the time window W (their bands' too), padded 5% each way.
in = A.t(:) >= W(1) - 1e-12 & A.t(:) <= W(2) + 1e-12;
v = reshape(A.mean(in, :, :), [], 1);
if withBands; v = [v; reshape(lo(in, :, :), [], 1); reshape(hi(in, :, :), [], 1)]; end
v = double(v(isfinite(v)));
if isempty(v); d = [0 1]; return; end
d = [min(v) max(v)];
pad = 0.05 * diff(d);
if ~(pad > 0); pad = 0.05 * max(abs(d(1)), 1); end
d = d + [-pad pad];
end


function v = roundTicks(d, maxN)
%roundTicks  At most MAXN ticks in [d(1) d(2)] at the smallest round step (1, 2, 2.5 or 5 x 10^k) that fits.
span = diff(d);
v = d;
for e = floor(log10(span / maxN)) + (0:2)
    for m = [1 2 2.5 5]
        s = m * 10^e;
        k = ceil(d(1) / s - 1e-9):floor(d(2) / s + 1e-9);
        if numel(k) <= maxN
            if numel(k) >= 2; v = k * s; end
            return
        end
    end
end
end
