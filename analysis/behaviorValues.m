function R = behaviorValues(y, x, opts)
%behaviorValues  A per-epoch behavioral value against a trial parameter.
%   R = behaviorValues(Y, X, Name=Value) gathers Y ([nEpochs x 1], e.g. the
%   RespLatency of each epoch's trial, or its stop event's latency) by the
%   values of X ([nEpochs x 1], numeric or text, e.g. Depth) and of an
%   optional series parameter, and summarizes each x value and series:
%   mean, SEM, median and count. Every value is kept as well (R.values), so
%   a renderer can draw each trial. Pure: no I/O, no graphics.
%
%   Options
%     Series        [nEpochs x 1] a second parameter: one series per value
%                   ([] = one series, "all")
%     Param         name of X (axis label)
%     SeriesParam   name of Series (legend)
%     YName         what Y is (axis label), e.g. "RespLatency"
%     YUnits        its unit ("" = as recorded, none named), e.g. "ms"
%
%   Epochs whose Y is not finite (a miss has no RespLatency; an epoch
%   without a stop event no stop latency) or whose X or Series is missing
%   are left out and counted (nMissing); when that leaves none it is
%   behaviorValues:NoValues; a Y that is not numeric (a text column) is
%   behaviorValues:NotNumeric. R fields: kind "behavior", x (sorted unique
%   values: numeric ascending, text alphabetical), xIsNumeric, series
%   (labels), seriesValues, groups (one row per series: index, label,
%   color, n), mean / sem / median / n [nX x nSeries], values (table, one
%   row per epoch kept: epoch (its row of Y), xIndex, seriesIndex, y),
%   nEpochs, nMissing, param, seriesParam, yName, units, params, created.
%
%   See also epochTable, renderBehavior, tuningCurve.

arguments
    y
    x
    opts.Series = []
    opts.Param (1,1) string = "x"
    opts.SeriesParam (1,1) string = ""
    opts.YName (1,1) string = "y"
    opts.YUnits (1,1) string = ""
end

if ~(isnumeric(y) || islogical(y))
    error('behaviorValues:NotNumeric', '%s is not numeric (a %s), so it cannot go on the y axis.', opts.YName, class(y));
end
y = double(y(:));
nE = numel(y);
x = x(:);
if numel(x) ~= nE
    error('behaviorValues:Size', 'X has %d values for %d epochs.', numel(x), nE);
end
[x, xIsNumeric, okX] = asKey(x);
s = opts.Series;
if isempty(s)
    s = repmat("all", nE, 1);
    sIsNumeric = false;
    okS = true(nE, 1);
else
    s = s(:);
    if numel(s) ~= nE
        error('behaviorValues:Size', 'Series has %d values for %d epochs.', numel(s), nE);
    end
    [s, sIsNumeric, okS] = asKey(s);
end
ok = isfinite(y) & okX & okS;
if ~any(ok)
    error('behaviorValues:NoValues', ['None of the %d epoch(s) has both a value of %s and of %s ' ...
        '(misses have no response latency; epochs outside the trials have no parameters).'], nE, opts.YName, opts.Param);
end
ux = unique(x(ok));
us = unique(s(ok));
nX = numel(ux); nS = numel(us);
xi = zeros(nE, 1); si = zeros(nE, 1);
[~, xi(ok)] = ismember(x(ok), ux);
[~, si(ok)] = ismember(s(ok), us);
M = NaN(nX, nS); SE = NaN(nX, nS); MD = NaN(nX, nS); N = zeros(nX, nS);
for i = 1:nX
    for j = 1:nS
        v = y(ok & xi == i & si == j);
        N(i, j) = numel(v);
        if isempty(v); continue; end
        M(i, j) = mean(v);
        SE(i, j) = semOf(v, 1);
        MD(i, j) = median(v);
    end
end
if isempty(opts.Series)
    slabels = "all";
    color = [0.15 0.15 0.15];
else
    if sIsNumeric; sv = compose("%.10g", us); else; sv = us; end
    slabels = opts.SeriesParam + " = " + sv;
    color = groupColors(us, sIsNumeric);
end
G = table((1:nS).', slabels(:), color, sum(N, 1).', 'VariableNames', {'index', 'label', 'color', 'n'});
rows = find(ok);

R = struct();
R.kind = "behavior";
R.x = ux;
R.xIsNumeric = xIsNumeric;
R.series = slabels(:);
R.seriesValues = us;
R.groups = G;
R.mean = M;
R.sem = SE;
R.median = MD;
R.n = N;
R.values = table(rows, xi(rows), si(rows), y(rows), 'VariableNames', {'epoch', 'xIndex', 'seriesIndex', 'y'});
R.nEpochs = nE;
R.nMissing = nE - numel(rows);
R.param = opts.Param;
R.seriesParam = opts.SeriesParam;
R.yName = opts.YName;
R.units = opts.YUnits;
R.params = struct('Param', opts.Param, 'SeriesParam', opts.SeriesParam, 'YName', opts.YName, 'YUnits', opts.YUnits);
R.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end


function [v, isNum, ok] = asKey(v)
%asKey  Numeric values as double (finite = present), anything else as string (not missing).
if iscell(v); v = string(v); end
isNum = isnumeric(v) || islogical(v);
if isNum
    v = double(v);
    ok = isfinite(v);
else
    v = string(v);
    ok = ~ismissing(v);
end
end
