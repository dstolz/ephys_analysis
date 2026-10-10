function h = renderBehavior(R, target, opts)
%renderBehavior  Draw a behaviorValues result: a per-trial value against a trial parameter.
%   H = renderBehavior(R, TARGET, Layout=, Jitter=, XScale=, Style=) draws
%   one panel: R.param along x, R.yName up y, one color per series (side
%   by side within each x value; the line layout draws them on top of each
%   other, as a tuning curve does).
%
%   Layout
%     "points"  (default) every epoch's value as a dot, with each x value's
%               mean +/- SEM over it (Style.ShowSEM: the bars)
%     "line"    the mean +/- SEM at each x value, joined, one line per series
%     "box"     a box plot of the values at each x value (boxchart)
%     "swarm"   every value as a dot, spread so none overlap (swarmchart),
%               with the mean +/- SEM over them
%     "violin"  the values' density at each x value (violinplot, MATLAB
%               R2024b or later), with the mean +/- SEM over it
%   "+/- SEM" is the error the result holds (R.err: mean +/- SEM or SD, or a
%   bootstrap 95% CI of the mean, over the epochs), drawn as error bars.
%   Jitter   points: spread the dots sideways (default true), with a fixed,
%            repeatable pattern; false: every dot on its x value
%   XScale   "category" (default): the x values evenly spaced, labeled with
%            their values; "linear": at their values (numeric x only; text
%            values are spaced evenly), each box, violin or swarm a fixed
%            share of the closest spacing
%   Style    EphysAnalysisConfig.defaults("Style") fields: Colormap (the
%            series' colors), LineWidth, ShowSEM, FontSize, XLim, YLim,
%            Grid, Legend
%
%   The parts are named for the aesthetics editor: "points", "swarm",
%   "box", "violin" and "behaviorMean", each with its series' label.
%
%   H: layout (tiled layout or []), axes.
%
%   See also behaviorValues, renderTuning, renderPlot.

arguments
    R (1,1) struct
    target
    opts.Layout (1,1) string {mustBeMember(opts.Layout, ["points" "line" "box" "swarm" "violin"])} = "points"
    opts.Jitter (1,1) logical = true
    opts.XScale (1,1) string {mustBeMember(opts.XScale, ["category" "linear"])} = "category"
    opts.Style = struct()
end

style = renderStyle(opts.Style);
if opts.Layout == "violin" && ~exist('violinplot', 'file')
    error('renderBehavior:NoViolin', 'The violin layout needs violinplot (MATLAB R2024b or later).');
end
colors = groupPalette(R.groups, style);
nX = numel(R.x);
nS = height(R.groups);
linear = opts.XScale == "linear" && R.xIsNumeric;
if linear
    xpos = double(R.x(:));
    slot = 1;
    if nX > 1; slot = min(diff(xpos)); end
else
    xpos = (1:nX).';
    slot = 1;
end
per = 0.8 * slot / nS;                          % one series' share of an x value's slot
offs = ((1:nS) - (nS + 1) / 2) * per;
if opts.Layout == "line"; offs(:) = 0; end
[tl, ax] = renderLayout(target, 1, 1);
if isempty(ax); ax = nexttile(tl); end
tagPart(ax, "axes");
V = R.values;
[eLo, eHi] = resultBounds(R, 'mean');
hold(ax, 'on');
lh = gobjects(1, nS);
for k = 1:nS
    c = colors(k, :);
    gl = R.series(k);
    rows = V.seriesIndex == k;
    xx = xpos(V.xIndex(rows)) + offs(k);
    y = V.y(rows);
    switch opts.Layout
        case "points"
            jit = zeros(size(xx));
            if opts.Jitter; jit = (mod((0:numel(xx) - 1).', 7) - 3) / 3 * per * 0.3; end
            lh(k) = tagPart(plot(ax, xx + jit, y, '.', 'Color', c, 'MarkerSize', 8), "points", gl);
            meanMarks(ax, xpos + offs(k), R.mean(:, k), eLo(:, k), eHi(:, k), c, style, gl, false);
        case "line"
            lh(k) = meanMarks(ax, xpos, R.mean(:, k), eLo(:, k), eHi(:, k), c, style, gl, true);
        case "box"
            if isempty(y)
                lh(k) = tagPart(plot(ax, NaN, NaN, 's', 'Color', c), "box", gl);
            else
                lh(k) = tagPart(boxchart(ax, xx, y, 'BoxWidth', per * 0.8, 'BoxFaceColor', c, ...
                    'MarkerColor', c, 'MarkerStyle', '.'), "box", gl);
            end
        case "swarm"
            if isempty(y)
                lh(k) = tagPart(plot(ax, NaN, NaN, '.', 'Color', c), "swarm", gl);
            else
                lh(k) = tagPart(swarmchart(ax, xx, y, 12, c, 'filled', 'XJitter', 'density', ...
                    'XJitterWidth', per * 0.8), "swarm", gl);
            end
            meanMarks(ax, xpos + offs(k), R.mean(:, k), eLo(:, k), eHi(:, k), c, style, gl, false);
        case "violin"
            if isempty(y)
                lh(k) = tagPart(patch(ax, NaN, NaN, c, 'EdgeColor', c), "violin", gl);
            else
                v = violinplot(ax, xx, y, 'FaceColor', c, 'EdgeColor', c);
                if isprop(v, 'DensityWidth'); set(v, 'DensityWidth', per * 0.9); end
                lh(k) = tagPart(v(1), "violin", gl);
                tagPart(v(2:end), "violin", gl);
            end
            meanMarks(ax, xpos + offs(k), R.mean(:, k), eLo(:, k), eHi(:, k), c, style, gl, false);
    end
end
hold(ax, 'off');
if linear
    pad = 0.6 * slot;
    xlim(ax, [min(xpos) - pad, max(xpos) + pad]);
else
    if R.xIsNumeric; labels = compose("%g", double(R.x(:))); else; labels = string(R.x(:)); end
    set(ax, 'XTick', xpos, 'XTickLabel', labels, 'TickLabelInterpreter', 'none');
    if nX > 8; ax.XTickLabelRotation = 45; end
    xlim(ax, [0.4 nX + 0.6]);
end
styleAxes(ax, style);
xlabel(ax, R.param, 'Interpreter', 'none');
yl = R.yName;
if R.units ~= ""; yl = yl + " (" + R.units + ")"; end
ylabel(ax, yl, 'Interpreter', 'none');
if style.Legend && nS > 1
    placeLegend(ax, lh, R.series, style, tl, 'bestoutside');
end
h = struct('layout', tl, 'axes', ax);
end


function lh = meanMarks(ax, x, m, lo, hi, c, style, label, joined)
%meanMarks  Each x value's mean (with its error bar from LO to HI with Style.ShowSEM), joined for the line layout.
ok = isfinite(m);
ls = 'none';
if joined; ls = '-'; end
edge = c * 0.6;
if joined; edge = c; end
if style.ShowSEM
    lh = errorbar(ax, x(ok), m(ok), m(ok) - lo(ok), hi(ok) - m(ok), 'o', 'LineStyle', ls, 'Color', edge, 'MarkerFaceColor', c, ...
        'MarkerSize', 5, 'LineWidth', style.LineWidth, 'CapSize', 4);
else
    lh = plot(ax, x(ok), m(ok), 'o', 'LineStyle', ls, 'Color', edge, 'MarkerFaceColor', c, ...
        'MarkerSize', 5, 'LineWidth', style.LineWidth);
end
tagPart(lh, "behaviorMean", label);
if ~joined; lh.HandleVisibility = 'off'; end
end
