function X = epochMatrixRaster(R, row, opts)
%epochMatrixRaster  One row's epochs of an epochMatrix result, trial by trial: its raster, or its signal per epoch.
%   X = epochMatrixRaster(R, ROW) takes row ROW of R.data (an index into
%   R.rows) of an epochMatrix result made with settings.keepEpochs (the
%   dataset browser's "Keep single trials"), and gives that row's epochs one
%   by one from R.epochs, in the order a raster draws them: by group (in
%   R.groupLabels' order), each group's epochs in time order. Nothing is
%   computed again and nothing is normalized: the spike times and the
%   signal traces are the ones R.epochs holds.
%
%   X = epochMatrixRaster(R, ROW, Order=ORDER)
%     Order  "group" (default): by group, then by time; "time": every
%            epoch in time order, whatever its group
%
%   Fields of X
%     row, label     ROW and its R.rows.label
%     key, name      its dataset (R.epochs(k).key and name)
%     rowKind        "unit" or "channel" (R.rowKind)
%     order          the Order used
%     t              R.t (column, s from the event)
%     window         [pre post] s (R.settings.window)
%     groupLabels    R.groupLabels; groupNames: a label per group, as text
%                    (R.labels.groups when R has its labels)
%     E              the dataset's epochs (R.epochs(k).E: epochTable's
%                    columns plus resultGroup, the epoch's group in
%                    R.groupLabels) in X's order, plus epochRow: its row
%                    of R.epochs(k).E. Row j of E is trial j of the raster
%     nPerGroup      the epochs in each group of R.groupLabels (column)
%     times, trial   spikes: each spike's time from the event (s) and its
%                    row of X.E (both columns); [] for signals
%     counts         spikes: the spike count of each epoch in each bin of
%                    R.t, [nEpochs x nTime], binned as spikePSTH bins them
%                    (whole binSec bins with an edge at the event; a spike
%                    on an edge in the bin that starts there). For measure
%                    "count" the mean of a group's rows is its trace in
%                    R.data before normalization. [] for measure "auroc"
%                    (R.t is no bin center then) and for signals
%     data           signals: [nEpochs x nTime], row j the trace of epoch
%                    X.E(j) at R.t (each epoch after Detrend, Baseline,
%                    Magnitude and Rectify: what is averaged; the mean of a
%                    group's rows is R.data for statistic "mean" without
%                    normalization); [] for spikes
%     units          the unit of data ("uV", "V", ...); "s" for spikes
%
%   Errors: epochMatrixRaster:BadResult (R is no epochMatrix result),
%   epochMatrixRaster:NoEpochs (R keeps no epochs: compute with
%   keepEpochs=true), epochMatrixRaster:BadRow (ROW is no row of R).
%
%   Example: a unit's raster, group by group
%     R = B.Result;                       % computed with "Keep single trials"
%     X = epochMatrixRaster(R, 12);
%     plot([X.times X.times].', [X.trial - 0.4 X.trial + 0.4].', 'k');
%     set(gca, 'YDir', 'reverse'); xlabel(R.labels.time); ylabel("Epoch");
%
%   See also epochMatrix, epochMatrixSettings, TrialRaster, DatasetBrowser.

arguments
    R
    row (1,1) double
    opts.Order (1,1) string {mustBeMember(opts.Order, ["group" "time"])} = "group"
end
if ~(isstruct(R) && isscalar(R) && all(isfield(R, {'data', 'rows', 't', 'groupLabels', 'settings', 'rowKind'})))
    error('epochMatrixRaster:BadResult', 'Not an epochMatrix result.');
end
if ~isfield(R, 'epochs') || isempty(R.epochs)
    error('epochMatrixRaster:NoEpochs', ['The result keeps no epochs: compute it with keepEpochs=true ' ...
        '(the dataset browser''s "Keep single trials, not just averages (R.epochs)", Measure tab).']);
end
nRows = height(R.rows);
if row < 1 || row > nRows || row ~= round(row)
    error('epochMatrixRaster:BadRow', 'Row %g is not a row of the result (1..%d).', row, nRows);
end
k = find(arrayfun(@(e) any(e.rows == row), R.epochs), 1);
if isempty(k) || isempty(R.epochs(k).E)
    error('epochMatrixRaster:NoEpochs', 'Row %d''s dataset kept no epochs.', row);
end
e = R.epochs(k);
i = find(e.rows == row, 1);   % the row's place among its dataset's rows
E = e.E;
nE = height(E);
E.epochRow = (1:nE).';
order = timeOrder(E);
if opts.Order == "group"
    g = double(E.resultGroup(order));
    g(~isfinite(g)) = Inf;   % an epoch in no group: last
    [~, o] = sort(g);   % stable: each group's epochs stay in time order
    order = order(o);
end
E = E(order, :);
pos = zeros(nE, 1);
pos(order) = 1:nE;   % an epoch's row of E (its trial in the raster)

nG = numel(R.groupLabels);
X = struct();
X.row = row;
X.label = string(R.rows.label(row));
X.key = string(e.key);
X.name = string(e.name);
X.rowKind = string(R.rowKind);
X.order = opts.Order;
X.t = R.t(:);
X.window = [R.settings.window.pre R.settings.window.post];
X.groupLabels = R.groupLabels;
X.groupNames = groupNames(R);
X.E = E;
X.nPerGroup = arrayfun(@(g) nnz(E.resultGroup == g), (1:nG).');
X.times = [];
X.trial = [];
X.counts = [];
X.data = [];
if R.rowKind == "unit"
    sp = e.spikes(i);
    X.times = double(sp.times(:));
    X.trial = pos(sp.epoch(:));
    X.units = "s";
    if R.settings.measure ~= "auroc"
        b = R.settings.binSec;
        edges = (ceil(X.window(1) / b - 1e-9) : floor(X.window(2) / b + 1e-9)) * b;   % spikePSTH's: whole bins, an edge at the event
        X.counts = zeros(nE, numel(edges) - 1);
        for j = 1:nE
            X.counts(j, :) = binCounts(X.times(X.trial == j), 0, edges).';   % spikePSTH's rule for a spike on an edge
        end
    end
else
    D = reshape(e.data(i, :, :), size(e.data, 2), size(e.data, 3));   % time x epoch
    X.data = D(:, order).';
    X.units = rawUnits(R);
end
end


function order = timeOrder(E)
%timeOrder  E's rows by time (t0, ties in E's order), or in E's order without t0.
order = (1:height(E)).';
if ismember("t0", string(E.Properties.VariableNames))
    [~, order] = sort(E.t0);
end
end


function n = groupNames(R)
%groupNames  A label per group as text: R.labels.groups, else the labels themselves.
n = reshape(string(R.groupLabels), [], 1);
if isfield(R, 'labels') && isstruct(R.labels) && isfield(R.labels, 'groups') && numel(R.labels.groups) == numel(n)
    n = reshape(string(R.labels.groups), [], 1);
end
end


function u = rawUnits(R)
%rawUnits  The unit of the epochs' values (never normalized): the raw unit of R.data.
u = string(R.valueUnits);
if isfield(R, 'normalization') && isstruct(R.normalization) && isfield(R.normalization, 'rawUnits')
    u = string(R.normalization.rawUnits);
end
end
