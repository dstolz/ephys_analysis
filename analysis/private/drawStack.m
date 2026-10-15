function step = drawStack(ax, P, R, colors, style, look, show)
%drawStack  One rate panel's groups in rows, the first at the bottom, step = Spacing x the tallest PSTH.
%   STEP = drawStack(AX, P, R, COLORS, STYLE, LOOK, SHOW) draws the PSTH of
%   one unit (or a mean) of the spikePSTH result R, one row per trial
%   group, into AX:
%     P      m / lo / hi [nBins x nGroups] (the means and their error
%            bands' edges), peak [nGroups x 1] (the right axis' labels),
%            peakLabel (its name); optional tallest (the height the step is
%            taken from; default: the tallest of P.m), so further traces
%            drawn into the rows by the caller fit them
%     LOOK   hist, fill, alpha (histTrace's), spacing (the row step as a
%            multiple of the tallest PSTH), raster ([] or u, sortBy, equal,
%            trials, look: rasterInto's, for each group's raster in its row)
%     SHOW   left / right: label the left / right axis
%   Left axis: a tick at each row's baseline, labeled with the group's
%   value (the groupBy parameters name the axis: rowLabels). Right axis: a
%   tick where each row peaks, labeled with P.peak (named by P.peakLabel).
%   Rows are drawn top down, so where they overlap the lower one is in
%   front. With LOOK.raster each row also holds its group's raster, as
%   tall as the tallest PSTH, just above the highest reach of any row's
%   PSTH and band; the step is then Spacing x that row's height. AX is
%   left on its left y axis. Roles: stackBase, sem, rate / rateFill,
%   stopLine, zeroLine. Drawn by a figure's PSTH panel (drawPsthPanel,
%   options.stack).
%
%   See also drawPsthPanel, rowLabels, histTrace.
nG = size(P.m, 2);
tallest = max(P.m, [], 'all');
if ~(tallest > 0); tallest = max(abs(P.m), [], 'all'); end
if isfield(P, 'tallest') && P.tallest > 0; tallest = P.tallest; end
if ~(tallest > 0); tallest = 1; end
rowHeight = tallest;
inRows = isfield(look, 'raster') && ~isempty(look.raster);
if inRows
    reach = tallest;
    if style.ShowSEM; reach = max([reach; P.hi(:)]); end
    gap = 0.05 * tallest;
    rasterAt = reach + gap;   % the raster's bottom, from the row's baseline
    rowHeight = rasterAt + tallest;
end
step = look.spacing * rowHeight;
base = (0:nG-1) * step;
W = R.edges([1 end]);
ls = groupLineStyles(R);
yyaxis(ax, 'left');
ax.LineStyleOrder = '-';   % a yyaxis side cycles through markers ('o-', '^-', ...) otherwise
hold(ax, 'on');
lo = 0;
hi = base(end) + rowHeight;
if inRows   % behind the rows' PSTHs
    rl = look.raster.look;
    rl.into = struct('base', base + rasterAt, 'height', tallest, 'equal', look.raster.equal, 'trials', look.raster.trials);
    rasterInto(ax, R, look.raster.u, style, colors, look.raster.sortBy, rl);
end
for g = nG:-1:1
    b = base(g);
    tagPart(line(ax, W, [b b], 'Color', [0.72 0.72 0.72], 'LineWidth', 0.5, 'HandleVisibility', 'off'), "stackBase", R.groups.label(g));
    m = P.m(:, g);
    elo = m; ehi = m;   % how far the row reaches: its band, where it has one
    if style.ShowSEM
        errorPatch(ax, R.t, P.lo(:, g) + b, P.hi(:, g) + b, colors(g, :), R.groups.label(g), style);
        f = isfinite(P.lo(:, g)); elo(f) = P.lo(f, g);
        f = isfinite(P.hi(:, g)); ehi(f) = P.hi(f, g);
    end
    histTrace(ax, R.t, R.edges, m, b, colors(g, :), look, style.LineWidth, R.groups.label(g), ls(g));
    if style.ShowStop && isfield(R, 'stopMean') && isfinite(R.stopMean(g))
        tagPart(line(ax, R.stopMean([g g]), b + [0 0.9 * min(step, tallest)], 'LineStyle', '--', 'Color', colors(g, :), ...
            'HandleVisibility', 'off'), "stopLine", R.groups.label(g));
    end
    lo = min([lo; b + elo]);
    hi = max([hi; b + ehi]);
end
if style.ShowZeroLine
    tagPart(xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'), "zeroLine");
end
hold(ax, 'off');
pad = 0.03 * (hi - lo);
yl = [lo - pad, hi + pad];
xlim(ax, W);
flat = style;
flat.YLim = [];
styleAxes(ax, flat);
[labels, name] = rowLabels(R);
set(ax, 'YTick', base, 'YTickLabel', labels(1:nG), 'TickLabelInterpreter', 'none');
ylim(ax, yl);
if show.left; ylabel(ax, name, 'Interpreter', 'none'); end

yyaxis(ax, 'right');
ylim(ax, yl);
top = base(:) + max(P.m, [], 1).';
ok = isfinite(top) & isfinite(P.peak(:));
[tk, iu] = unique(top(ok));
txt = compose("%.3g", P.peak(ok));
set(ax, 'YTick', tk, 'YTickLabel', txt(iu));
if show.right; ylabel(ax, P.peakLabel, 'Interpreter', 'none'); end
yyaxis(ax, 'left');
set(ax.YAxis, 'Color', ax.XAxis.Color);
end
