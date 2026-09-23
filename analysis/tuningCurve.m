function R = tuningCurve(rates, x, opts)
%tuningCurve  Rate against a trial parameter, one curve per series.
%   R = tuningCurve(RATES, X, Name=Value) averages RATES ([nEpochs x nUnits],
%   e.g. firingRate's rate) over the epochs sharing each value of X
%   ([nEpochs x 1], numeric or text, e.g. the Depth of each epoch's trial).
%   Pure: no I/O, no graphics.
%
%   Options
%     Series        [nEpochs x 1] a second parameter: one curve per value
%                   ([] = one curve)
%     Param         name of X (axis label)
%     SeriesParam   name of Series (legend)
%     Meta, Labels  unit table / labels as in spikePSTH
%     Units         unit of RATES (default "spikes/s")
%
%   Epochs whose X (or Series) is missing are left out; when that leaves
%   none (e.g. recording-scope events that all fall outside the trials) it
%   is tuningCurve:NoValues. R fields: kind "tuning", x (sorted unique
%   values: numeric ascending, text alphabetical), xIsNumeric, series
%   (labels), seriesValues, mean / sem [nX x nUnits x nSeries], n [nX x
%   nSeries], groups (one row per series: index, label, color), param,
%   seriesParam, labels, meta, units, params, created.
%
%   See also firingRate, epochTable, renderTuning.

arguments
    rates {mustBeNumeric}
    x
    opts.Series = []
    opts.Param (1,1) string = "x"
    opts.SeriesParam (1,1) string = ""
    opts.Meta = []
    opts.Labels (1,:) string = string.empty(1,0)
    opts.Units (1,1) string = "spikes/s"
end

nE = size(rates, 1);
nU = size(rates, 2);
x = x(:);
if numel(x) ~= nE
    error('tuningCurve:Size', 'X has %d values for %d epochs.', numel(x), nE);
end
if iscell(x); x = string(x); end
xIsNumeric = isnumeric(x) || islogical(x);
if xIsNumeric; x = double(x); ok = isfinite(x); else; x = string(x); ok = ~ismissing(x); end
s = opts.Series;
if isempty(s)
    s = repmat("all", nE, 1);
    sIsNumeric = false;
else
    s = s(:);
    if iscell(s); s = string(s); end
    if numel(s) ~= nE
        error('tuningCurve:Size', 'Series has %d values for %d epochs.', numel(s), nE);
    end
    sIsNumeric = isnumeric(s) || islogical(s);
    if sIsNumeric; s = double(s); ok = ok & isfinite(s); else; s = string(s); ok = ok & ~ismissing(s); end
end
if ~any(ok)
    what = opts.Param;
    if ~isempty(opts.Series)
        sp = opts.SeriesParam;
        if sp == ""; sp = "the series"; end
        what = what + " and " + sp;
    end
    error('tuningCurve:NoValues', 'None of the %d epoch(s) has a value of %s (epochs outside the trials have none).', nE, what);
end
ux = unique(x(ok));
us = unique(s(ok));
nX = numel(ux); nS = numel(us);
M = NaN(nX, nU, nS); SE = NaN(nX, nU, nS); N = zeros(nX, nS);
for i = 1:nX
    for j = 1:nS
        rows = ok & x == ux(i) & s == us(j);
        N(i, j) = nnz(rows);
        if N(i, j) == 0; continue; end
        M(i, :, j) = mean(rates(rows, :), 1, 'omitnan');
        SE(i, :, j) = semOf(rates(rows, :), 1);
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

R = struct();
R.kind = "tuning";
R.x = ux;
R.xIsNumeric = xIsNumeric;
R.series = slabels(:);
R.seriesValues = us;
R.mean = M;
R.sem = SE;
R.n = N;
R.groups = G;
R.param = opts.Param;
R.seriesParam = opts.SeriesParam;
R.labels = unitLabels(nU, opts.Labels, opts.Meta);
R.meta = opts.Meta;
R.units = opts.Units;
R.params = struct('Param', opts.Param, 'SeriesParam', opts.SeriesParam);
R.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
