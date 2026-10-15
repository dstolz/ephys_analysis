function cl = chronuxAutoLimits(v, signed)
%chronuxAutoLimits  The color limits of a Chronux image: the 1st to the 99th percentile of its values.
%   CL = chronuxAutoLimits(V, SIGNED): V the finite values drawn (any
%   shape; [] gives [0 1]). SIGNED (a baseline-normalized image, centered
%   on no change): symmetric about 0, [-m m] with m the larger magnitude
%   of the two percentiles. Otherwise [lo hi], or lo +/- 0.5 when they meet.
%   Nearest-rank percentiles, without the Statistics Toolbox.
%
%   See also renderChronux, drawSpectrogramPanel, chronuxScaled.
if isempty(v); cl = [0 1]; return; end
v = sort(v(:));
lo = v(max(1, ceil(0.01 * numel(v))));
hi = v(max(1, ceil(0.99 * numel(v))));
if signed
    m = max(abs([lo hi]));
    if ~(m > 0); m = 1; end
    cl = [-m m];
elseif hi > lo
    cl = [lo hi];
else
    cl = lo + [-0.5 0.5];
end
end
