function auxInto(ax, A, X, W, style, over, label, opt)
%auxInto  Draw the mean aux traces of A (auxMean) into the axes AX.
%   auxInto(AX, A, X, W, STYLE, OVER, LABEL, OPT) draws every trace of A -- each
%   channel's mean, or the magnitude's, per group -- as X (auxLooks) says,
%   on the time axis W ([t0 t1] s, the plot's), with each trace's
%   error band under it when STYLE.ShowSEM (A.err: mean +/- SEM or SD, or a
%   bootstrap 95% CI, over the epochs; errorPatch in STYLE's Error* look).
%   The lines are tagged
%   "auxTrace" and the bands "auxSem", both with X's group (tagPart), and
%   kept out of legends (auxStandIns stands in for them there).
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
%                   y axis, or the part of the right axis the signal spans);
%                   [] = from the traces, and their bands when drawn, in W
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
if over
    yyaxis(ax, 'right');
    ax.LineStyleOrder = '-';   % a yyaxis side cycles through markers otherwise
    ax.YDir = 'normal';        % the active side's: a raster's rows run down on the left
end
held = ishold(ax);
hold(ax, 'on');
[~, nTr, nGa] = size(A.mean);
t = A.t(:);
[eLo, eHi] = resultBounds(A, 'mean');
alpha = NaN;
if over; alpha = 0.2; end
for g = 1:nGa
    for c = 1:nTr
        L = X.trace(c, g);
        m = double(A.mean(:, c, g));
        if style.ShowSEM
            errorPatch(ax, t, eLo(:, c, g), eHi(:, c, g), L.color, L.group, style, "auxSem", alpha);
        end
        tagPart(line(ax, t, m, 'Color', L.color, 'LineStyle', char(L.lineStyle), 'LineWidth', style.LineWidth, ...
            'HandleVisibility', 'off'), "auxTrace", L.group);
    end
end
if ~held; hold(ax, 'off'); end
xlim(ax, W);
if label; ylabel(ax, X.label, 'Interpreter', 'none'); end
fixed = numel(opt.yLim) == 2 && all(isfinite(opt.yLim)) && opt.yLim(2) > opt.yLim(1);
if over
    pos = opt.overPosition;
    if ~(numel(pos) == 2 && all(isfinite(pos)) && pos(1) >= 0 && pos(2) <= 1 && pos(2) > pos(1)); pos = [0 1]; end
    if fixed || ~isequal(pos, [0 1])
        d = opt.yLim;
        if ~fixed; d = autoRange(A, eLo, eHi, W, style.ShowSEM); end
        span = diff(d) / diff(pos);   % the right axis' range for the whole height
        ylim(ax, [d(1) - pos(1) * span, d(2) + (1 - pos(2)) * span]);
        if ~isequal(pos, [0 1])
            ax.YAxis(2).TickValues = roundTicks(d, 3);   % the signal's own scale, along its span only
        end
    end
    yyaxis(ax, 'left');
    set(ax.YAxis, 'Color', ax.XAxis.Color);
else
    flat = style;
    flat.YLim = [];
    styleAxes(ax, flat);
    if fixed; ylim(ax, opt.yLim); end
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

