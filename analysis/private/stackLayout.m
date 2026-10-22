function L = stackLayout(lo, hi, spacing, opts)
%stackLayout  Where a panel's stacked rows go, the first on top, and how each row's values map onto the axis.
%   L = stackLayout(LO, HI, SPACING, Mode=, Limits=, Zero=, Image=, Above=) lays
%   out n rows (a stacked panel's trial groups, channels or series: LO and
%   HI, 1 x n, each row's data extent in its own units, NaN for a row with
%   nothing finite) one above the other, row 1 on top, as every panel type
%   with options.stack draws them (drawStack, the line stacks of
%   drawContinuousPanel, drawSpectrumPanel, drawCoherencePanel and
%   drawTuningPanel, drawImageStack). Row r's values v are drawn at
%   L.offset(r) + L.scale(r) * v.
%     Mode    how the rows' scales relate (a panel's options.yLimMode):
%             "rows" (default), "batch" and "fixed" put every row on one
%             scale, the range Limits ([lo hi]; [] = the union of the rows'
%             extents); "auto" scales each row to its own extent, the
%             tallest keeping its units
%     Zero    rows that stand on zero (a PSTH's bars): each extent holds 0
%     Image   image rows (a spectrogram's blocks): they never overlap
%             (SPACING below 1 counts as 1) and get no margin
%     Above   room above each row for something drawn outside its values
%             (a PSTH's latency box lane), a multiple of the row height
%             (default 0): each row's slot is (1 + Above) x H, so what sits
%             there stays outside the row's range whatever the Mode
%   SPACING is the row step as a multiple of the row's slot, H x (1 +
%   Above) (1: the rows touch; below 1 they overlap; not finite or not
%   positive: 1.1).
%   L fields
%     n        the rows
%     height   H, every row's height on the axis (the tallest extent, or
%              the shared range's)
%     step     SPACING x H
%     base     1 x n: each row's bottom on the axis ((n-1:-1:0) x step)
%     mid      1 x n: each row's middle (base + H/2), where its label goes
%     top      1 x n: each row's top (base + H), where its Above room starts
%     above    the room above each row, Above x H
%     range    n x 2: the values each row spans, [lo hi] (shared: one range)
%     scale    1 x n: axis units per data unit (1 on a shared scale)
%     offset   1 x n: where each row's value 0 lies on the axis
%     shared   true when every row has one scale
%     ylim     the axis' limits: the rows, a 3% margin above and below
%              (none for images)
%   A row whose extent is flat gets +/-0.5 around it; when no row has any
%   finite extent every row spans [0 1].
%
%   See also stackBaseLines, stackAxes, drawStack, drawImageStack.
arguments
    lo double
    hi double
    spacing (1,1) double
    opts.Mode (1,1) string = "rows"
    opts.Limits double = []
    opts.Zero (1,1) logical = false
    opts.Image (1,1) logical = false
    opts.Above (1,1) double {mustBeNonnegative} = 0
end
lo = reshape(double(lo), 1, []);
hi = reshape(double(hi), 1, []);
n = numel(lo);
if opts.Zero
    lo = min(lo, 0);
    hi = max(hi, 0);
end
ok = isfinite(lo) & isfinite(hi);
if ~any(ok)
    lo(:) = 0;
    hi(:) = 1;
else
    lo(~ok) = min(lo(ok));
    hi(~ok) = max(hi(ok));
end
flat = ~(hi > lo);
lo(flat) = lo(flat) - 0.5;
hi(flat) = hi(flat) + 0.5;
shared = opts.Mode ~= "auto";
lim = double(opts.Limits);
if shared
    if numel(lim) == 2 && all(isfinite(lim)) && lim(2) > lim(1)
        R = reshape(lim, 1, 2);
    else
        R = [min(lo) max(hi)];
    end
    rng = repmat(R, n, 1);
    H = R(2) - R(1);
    scale = ones(1, n);
else
    rng = [lo(:) hi(:)];
    H = max(hi - lo);
    scale = H ./ (hi - lo);
end
if ~(isfinite(spacing) && spacing > 0); spacing = 1.1; end
if opts.Image; spacing = max(1, spacing); end
above = opts.Above * H;
step = spacing * (H + above);
base = (n-1:-1:0) * step;
offset = base - scale .* reshape(rng(:, 1), 1, []);
top = base + H;
pad = 0;
if ~opts.Image && n > 0; pad = 0.03 * (top(1) + above - base(end)); end
yl = [0 1];
if n > 0; yl = [base(end) - pad, top(1) + above + pad]; end
L = struct('n', n, 'height', H, 'step', step, 'base', base, 'mid', base + H / 2, 'top', top, 'range', rng, ...
    'scale', scale, 'offset', offset, 'shared', shared, 'ylim', yl, 'above', above);
end
