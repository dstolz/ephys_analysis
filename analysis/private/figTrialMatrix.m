function [M, order, grp, name] = figTrialMatrix(R, o)
%figTrialMatrix  One unit's epochs by time: its raster binned as its PSTH, and the epochs in a raster's order.
%   [M, ORDER, GRP, NAME] = figTrialMatrix(R, O), for a spikePSTH result R
%   computed with Raster=true (a heat map of trials' layer: its first
%   unit is drawn) and the heat map's options O (rasterSort,
%   rasterSortOrder, rasterByGroup):
%     M      [nEpochs x nBins]: epoch e (a row of R.epochs and
%            R.epochGroup) in R's bins (R.edges), its spikes counted as
%            spikePSTH counts them (binCounts of the unit's train, R.trains
%            -- figurePointLayer's KeepTrains -- around R.epochs.t0Continuous;
%            without R.trains its raster, binned by binCounts' rule: a spike
%            on an edge goes to the bin that starts there), in R.measure: "rate" count /
%            BinSec, "count", "probability" 1 where any spike; with
%            MaskAfterStop NaN in the bins from its stop event on; each
%            epoch smoothed by SmoothSec (gaussianSmooth, as spikePSTH
%            smooths each epoch before it averages); and BaselineMode
%            "subtract" / "zscore" / "percent" taken against its group's
%            baseline (R.baselineRate / baselineSD), so the mean of a
%            group's rows is the group's PSTH
%     ORDER  the epochs, top row first: rasterInto's order (by group first
%            with O.rasterByGroup; then O.rasterSort -- "" the epochs' time
%            order, "stop" their stop latency, "event" R.rasterSortEvent.t,
%            else that column of R.epochs -- in O.rasterSortOrder, missing
%            values last, ties in time order)
%     GRP    each epoch's group (R.epochGroup, a row of R.groups)
%     NAME   the rows' y label: "Epoch", with the sort ("Epoch (by Depth),
%            descending")
%   A sort key R lacks (no sort event, no such column) sorts in time order.
%
%   See also computeHeatmapPanel, drawHeatmapPanel, spikePSTH, rasterInto.

grp = double(R.epochGroup(:));
nE = numel(grp);
edges = reshape(R.edges, 1, []);
nB = numel(edges) - 1;
binSec = R.params.BinSec;
C = zeros(nB, nE);
if isfield(R, 'trains') && ~isempty(R.trains) && isfield(R, 'epochs') && istable(R.epochs) && height(R.epochs) == nE
    % the unmasked train, counted as spikePSTH counts it: a bin that starts before the stop keeps its spikes after it
    tr = R.trains;
    if iscell(tr); tr = tr{1}; end
    C = binCounts(tr, R.epochs.t0Continuous, edges);
elseif isfield(R, 'raster') && ~isempty(R.raster)   % the raster (with MaskAfterStop it lacks the spikes after the stop)
    rel = double(R.raster(1).times(:));
    ep = double(R.raster(1).epoch(:));
    b = discretize(rel + 1e-9, edges);   % [a, b): a spike on an edge in the bin starting there
    ok = ~isnan(b) & ep >= 1 & ep <= nE;
    C = accumarray([b(ok) ep(ok)], 1, [nB nE]);
end
switch string(R.measure)
    case "count",       X = C;
    case "probability", X = double(C > 0);
    otherwise,          X = C / binSec;
end
if R.params.MaskAfterStop
    stop = reshape(R.epochStop, 1, []);
    X(edges(1:end-1).' >= stop & isfinite(stop)) = NaN;
end
if R.params.SmoothSec > 0
    X = gaussianSmooth(X, R.params.SmoothSec / binSec);
end
mode = string(R.params.BaselineMode);
if ismember(mode, ["subtract" "zscore" "percent"]) && nE > 0
    mu = reshape(R.baselineRate(1, grp), 1, []);
    sd = reshape(R.baselineSD(1, grp), 1, []);
    switch mode
        case "subtract"
            X = X - mu;
        case "zscore"
            X = (X - mu) ./ sd;
            X(:, ~(sd > 0)) = NaN;
        case "percent"
            X = 100 * (X - mu) ./ mu;
            X(:, ~(mu > 0)) = NaN;
    end
end
M = X.';

[key, name] = sortKey(R, string(o.rasterSort), nE);
dirs = ["ascend" "ascend"];
if o.rasterSortOrder == "descending"; dirs(1) = "descend"; end
T = table(key, (1:nE).', 'VariableNames', {'key', 'idx'});
if o.rasterByGroup
    T = addvars(T, grp, 'Before', 1, 'NewVariableNames', 'g');
    dirs = ["ascend" dirs];
end
[~, order] = sortrows(T, 1:width(T), cellstr(dirs), 'MissingPlacement', 'last');
if o.rasterSortOrder == "descending"; name = name + ", descending"; end
if ~o.rasterByGroup && height(R.groups) > 1; name = name + ", groups mixed"; end
end


function [key, name] = sortKey(R, sortBy, nE)
%sortKey  Each epoch's sort value and the y label (rasterInto's rules; time order where R lacks the key).
key = (1:nE).';
name = "Epoch";
switch sortBy
    case ""
    case "stop"
        key = R.epochStop(:);
        name = "Epoch (by stop latency)";
    case "event"
        if isfield(R, 'rasterSortEvent') && isstruct(R.rasterSortEvent) && numel(R.rasterSortEvent.t) == nE
            key = R.rasterSortEvent.t(:);
            name = "Epoch (by " + string(R.rasterSortEvent.label) + " latency)";
        end
    otherwise
        if isfield(R, 'epochs') && istable(R.epochs) && ismember(sortBy, string(R.epochs.Properties.VariableNames)) ...
                && size(R.epochs.(sortBy), 1) == nE && size(R.epochs.(sortBy), 2) == 1
            key = R.epochs.(sortBy);
            name = "Epoch (by " + sortBy + ")";
        end
end
end
