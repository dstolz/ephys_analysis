function R = epochMatrixNormalize(R, N)
%epochMatrixNormalize  Normalize an epochMatrix result: each row's trace against its baseline, or to 0 to 1.
%   R = epochMatrixNormalize(R) applies R.settings.normalize to R (an
%   epochMatrix result, or DatasetBrowser's B.Result); epochMatrix does this
%   when it assembles R. R = epochMatrixNormalize(R, N) applies N instead: a
%   struct of normalize fields, merged over R.settings.normalize and
%   checked by epochMatrixSettings (e.g. struct('method', "zscore")). A
%   result normalized before is normalized again from its raw values
%   (R.raw), so the methods do not stack; method "none" gives the raw
%   values back.
%
%   Methods (normalize.method), per row of R.data and, with scope "group",
%   per group (scope "row", the default: one value per row from all its
%   groups, so the groups keep their differences). b is the mean and SD
%   the standard deviation of the trace's values at the times of R.t inside
%   normalize.baseline (missing values ignored):
%     "none"      the values as computed
%     "subtract"  x - b                        (R.data's unit)
%     "ratio"     x / b                        ("x baseline")
%     "percent"   100 (x - b) / |b|            ("%")
%     "zscore"    (x - b) / SD                 ("z")
%     "minmax"    (x - min) / (max - min)      ("0-1"; over the whole window)
%   The SD is over the baseline's bins (spikes) or samples (signals) of the
%   group's mean trace, not over the epochs, so it shrinks with more epochs
%   and grows with narrower bins. (spikePSTH's BaselineMode "zscore", which
%   the analysis app's PSTH panels use, takes the SD over the epochs.)
%   Where b is 0 (ratio, percent), SD is 0 (zscore) or the trace is flat
%   (minmax), or no baseline value is finite, the row's values are NaN in
%   that group (with scope "row": in every group); R.normalization.undefined
%   marks them. A result of measure "auroc" is not normalized (method
%   "none" is used; R.settings.normalize keeps what was asked).
%
%   Fields of R it sets
%     R.data           the normalized values (the raw ones with "none")
%     R.raw            the values before normalization ([] with "none")
%     R.valueUnits     the unit of R.data: the raw unit for "none" and
%                      "subtract", "x baseline", "%", "z" or "0-1"
%     R.settings       with normalize = N (checked)
%     R.normalization  struct: method (the one applied), baseline ([b0 b1],
%                      [] for "none" and "minmax"), scope, rawUnits, center
%                      and scale (R.data = (R.raw - center) ./ scale;
%                      [nRows x 1] for scope "row", [nRows x 1 x nGroups]
%                      for "group"; [] for "none"), undefined (logical
%                      [nRows x nGroups]: a row with values in the group
%                      whose normalization is undefined, so NaN), nBaseline
%                      (the times of R.t inside the baseline)
%     R.labels         made again (epochMatrixLabels)
%
%   Errors: epochMatrixNormalize:NoBaseline (no time of R.t lies inside
%   the baseline), epochMatrixNormalize:BadResult (R is not an epochMatrix
%   result), and epochMatrixSettings'.
%
%   Example
%     Rz = epochMatrixNormalize(B.Result, struct('method', "zscore", 'baseline', [-1 0]));
%     imagesc(Rz.t, 1:height(Rz.rows), Rz.data(:, :, 1));
%     cb = colorbar; cb.Label.String = Rz.labels.value;
%
%   See also epochMatrix, epochMatrixSettings, epochMatrixLabels, DatasetBrowser.

arguments
    R
    N = []
end
if ~(isstruct(R) && isscalar(R) && all(isfield(R, {'data', 't', 'settings', 'valueUnits'})))
    error('epochMatrixNormalize:BadResult', 'Pass an epochMatrix result (a struct with data, t, settings and valueUnits).');
end

% --- the raw values
raw = R.data;
rawUnits = string(R.valueUnits);
if isfield(R, 'normalization') && isstruct(R.normalization) && isfield(R.normalization, 'rawUnits')
    rawUnits = string(R.normalization.rawUnits);
    if isfield(R, 'raw') && ~isempty(R.raw); raw = R.raw; end
end

% --- the settings
if isempty(N)
    S = epochMatrixSettings(R.settings);
else
    S = epochMatrixSettings(R.settings, normalize=N);
end
nz = S.normalize;
method = nz.method;
if ismember(S.data, ["units" "detected"]) && S.measure == "auroc"
    method = "none";
end

nRows = size(raw, 1);
nG = size(raw, 3);
t = R.t(:);
info = struct('method', method, 'baseline', [], 'scope', nz.scope, 'rawUnits', rawUnits, ...
    'center', [], 'scale', [], 'undefined', false(nRows, nG), 'nBaseline', 0);

if method == "none"
    R.data = raw;
    R.raw = [];
    R.valueUnits = rawUnits;
else
    % one value per row (scope "row": the groups' values side by side) or per row and group
    if nz.scope == "row"
        pool = @(X) reshape(X, nRows, []);   % (row, time x group)
    else
        pool = @(X) X;                       % (row, time, group)
    end
    if method == "minmax"
        X = pool(raw);
        lo = min(X, [], 2);
        hi = max(X, [], 2);
        center = lo;
        scale = hi - lo;
    else
        b = nz.baseline;
        inB = t >= b(1) - 1e-9 & t <= b(2) + 1e-9;
        if ~any(inB)
            error('epochMatrixNormalize:NoBaseline', ['The baseline [%g %g] s holds no time of R.t ' ...
                '(%g to %g s, %d times).'], b(1), b(2), t(1), t(end), numel(t));
        end
        info.baseline = b;
        info.nBaseline = nnz(inB);
        X = pool(raw(:, inB, :));
        mu = mean(X, 2, 'omitnan');
        switch method
            case "subtract"
                center = mu; scale = ones(size(mu));
            case "ratio"
                center = zeros(size(mu)); scale = mu;
            case "percent"
                center = mu; scale = abs(mu) / 100;
            case "zscore"
                center = mu; scale = std(X, 0, 2, 'omitnan');
        end
    end
    bad = ~isfinite(center) | ~isfinite(scale) | scale == 0;
    scale(bad) = NaN;
    R.data = (raw - center) ./ scale;
    R.raw = raw;
    info.center = center;
    info.scale = scale;
    has = reshape(any(isfinite(raw), 2), nRows, nG);   % (row, group) holding values
    info.undefined = has & reshape(repmat(bad, 1, 1, nG / size(bad, 3)), nRows, nG);
    switch method
        case "subtract"; R.valueUnits = rawUnits;
        case "ratio";    R.valueUnits = "x baseline";
        case "percent";  R.valueUnits = "%";
        case "zscore";   R.valueUnits = "z";
        case "minmax";   R.valueUnits = "0-1";
    end
end
R.settings = S;
R.normalization = info;
R.labels = epochMatrixLabels(R);
end
