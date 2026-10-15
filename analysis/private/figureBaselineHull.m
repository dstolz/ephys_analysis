function b = figureBaselineHull(panels)
%figureBaselineHull  [b0 b1] spanning the baseline windows of figure PANELS ([] = none): what epochTable must read.
%   B = figureBaselineHull(PANELS) for panels of a figureFor spec (their
%   resolved options): the hull of every baseline window whose Mode is not
%   "none". figureCompute passes it as epochTable's Baseline for the
%   panels on the figure's alignment (and for a panel's own epochs), and
%   figureObservations for a perGroup figure's groups, so both drop the
%   same epochs (an epoch whose baseline leaves the recording).
%
%   See also figureCompute, figureObservations, epochTable.
b = [];
lo = Inf; hi = -Inf;
for k = 1:numel(panels)
    o = panels(k).options;
    if isfield(o, 'baseline') && isstruct(o.baseline) && o.baseline.Mode ~= "none" && numel(o.baseline.Window) == 2
        lo = min(lo, o.baseline.Window(1));
        hi = max(hi, o.baseline.Window(2));
    end
end
if isfinite(lo) && isfinite(hi); b = [lo hi]; end
end
