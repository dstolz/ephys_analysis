function [step, base] = drawStack(ax, P, R, colors, style, look, show)
%drawStack  One rate panel's groups in rows, the first on top, in the rows of a stackLayout.
%   [STEP, BASE] = drawStack(AX, P, R, COLORS, STYLE, LOOK, SHOW) draws the
%   PSTH of one unit (or a mean) of the spikePSTH result R, one row per
%   trial group, into AX, the first group's row on top (as a raster lists
%   its groups, first on top); BASE (1 x nGroups) is each group's row
%   baseline (its zero) and STEP the row step:
%     P      m / lo / hi [nBins x nGroups] (the means and their error
%            bands' edges), peak [nGroups x 1] (the right axis' labels),
%            peakLabel (its name)
%     LOOK   hist, fill, alpha (histTrace's) and layout: the stackLayout
%            (Zero) of the rows (drawPsthPanel's drawRows takes it from
%            every item's reach and options.stackSpacing): row g's values
%            are drawn at layout.offset(g) + layout.scale(g) x v, its bars
%            from its zero, layout.offset(g)
%     SHOW   left / right: label the left / right axis
%   Left axis: a tick at each row's baseline, labeled with the group's
%   value (the groupBy parameters name the axis: rowLabels). Right axis: a
%   tick where each row peaks, labeled with P.peak (named by P.peakLabel).
%   Rows are drawn top down, so where they overlap the lower one is in
%   front. The y limits are the layout's, widened to any reach beyond it.
%   AX is left on its left y axis. Roles: stackBase (carrying 'StackMap',
%   [offset scale], for the data tips), sem, rate / rateFill, stopLine,
%   zeroLine. Drawn by a figure's PSTH panel (drawPsthPanel,
%   options.stack "groups").
%
%   See also drawPsthPanel, stackLayout, rowLabels, histTrace.
nG = size(P.m, 2);
L = look.layout;
step = L.step;
base = L.offset;   % each row's zero: its bars stand on it
W = R.edges([1 end]);
ls = groupLineStyles(R);
yyaxis(ax, 'left');
ax.LineStyleOrder = '-';   % a yyaxis side cycles through markers ('o-', '^-', ...) otherwise
hold(ax, 'on');
lo = L.ylim(1);
hi = L.ylim(2);
for g = 1:nG   % top down
    b = base(g);
    k = L.scale(g);
    hb = tagPart(line(ax, W, [b b], 'Color', [0.72 0.72 0.72], 'LineWidth', 0.5, 'HandleVisibility', 'off'), "stackBase", R.groups.label(g));
    setappdata(hb, 'StackMap', [b k]);
    m = k * P.m(:, g);
    elo = m; ehi = m;   % how far the row reaches: its band, where it has one
    if style.ShowSEM
        errorPatch(ax, R.t, k * P.lo(:, g) + b, k * P.hi(:, g) + b, colors(g, :), R.groups.label(g), style);
        f = isfinite(P.lo(:, g)); elo(f) = k * P.lo(f, g);
        f = isfinite(P.hi(:, g)); ehi(f) = k * P.hi(f, g);
    end
    histTrace(ax, R.t, R.edges, m, b, colors(g, :), look, style.LineWidth, R.groups.label(g), ls(g));
    if style.ShowStop && isfield(R, 'stopMean') && isfinite(R.stopMean(g))
        tagPart(line(ax, R.stopMean([g g]), b + [0 0.9 * min(step, L.height)], 'LineStyle', '--', 'Color', colors(g, :), ...
            'HandleVisibility', 'off'), "stopLine", R.groups.label(g));
    end
    lo = min([lo; b + elo(isfinite(elo))]);
    hi = max([hi; b + ehi(isfinite(ehi))]);
end
if style.ShowZeroLine
    tagPart(xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'), "zeroLine");
end
hold(ax, 'off');
yl = [lo hi];
xlim(ax, W);
flat = style;
flat.YLim = [];
styleAxes(ax, flat);
[labels, name] = rowLabels(R);
[tk, ord] = sort(base);   % (each row its own scale: its zero may sit anywhere in its row)
keep = [true diff(tk) > 0];
set(ax, 'YTick', tk(keep), 'YTickLabel', labels(ord(keep)), 'TickLabelInterpreter', 'none');
ylim(ax, yl);
if show.left; ylabel(ax, name, 'Interpreter', 'none'); end

yyaxis(ax, 'right');
ylim(ax, yl);
top = base(:) + L.scale(:) .* max(P.m, [], 1).';
ok = isfinite(top) & isfinite(P.peak(:));
[tk, iu] = unique(top(ok));
txt = compose("%.3g", P.peak(ok));
set(ax, 'YTick', tk, 'YTickLabel', txt(iu));
if show.right; ylabel(ax, P.peakLabel, 'Interpreter', 'none'); end
yyaxis(ax, 'left');
set(ax.YAxis, 'Color', ax.XAxis.Color);
end
