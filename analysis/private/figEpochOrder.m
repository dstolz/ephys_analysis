function [order, name] = figEpochOrder(R, o, u)
%figEpochOrder  A result's epochs in a raster's row order, top row first, and the rows' y label.
%   [ORDER, NAME] = figEpochOrder(R, O, U), for a result R that holds its
%   epochs' groups (R.epochGroup [nE x 1], rows of R.groups), stop
%   latencies (R.epochStop), the sort event's latencies
%   (R.rasterSortEvent: label, t), the epochs (R.epochs: a trial
%   parameter's column) and, for the latency sort, its raster rows
%   (R.raster, firstSpikeLatency), and the options O (rasterSort,
%   rasterSortOrder, rasterByGroup; optional firstSpike) of a raster
%   (rasterInto), a heat map of trials (figTrialMatrix) or an event
%   trace's sub-rows (drawEventTracePanel). U (default 1) is the raster
%   unit the latency sort reads:
%     ORDER  the epochs, top row first: by group first with
%            O.rasterByGroup; then O.rasterSort -- "" the epochs' time
%            order, "stop" their stop latency, "event" R.rasterSortEvent.t,
%            "latency" their first-spike latency (firstSpikeLatency of unit
%            U, in the window [O.firstSpike.minSec, O.firstSpike.maxSec]
%            whether or not the marks are on, else from the event to the
%            window's end; an epoch with no spike there counts as missing),
%            else that column of R.epochs -- in O.rasterSortOrder, missing
%            values last, ties in time order
%     NAME   the rows' y label: "Epoch", with the sort ("Epoch (by Depth),
%            descending")
%   A sort key R lacks (no sort event, no such column, no raster rows for
%   "latency") sorts in time order.
%
%   See also figTrialMatrix, drawEventTracePanel, rasterInto, firstSpikeLatency.

if nargin < 3; u = 1; end
grp = double(R.epochGroup(:));
nE = numel(grp);
win = [0 Inf];
if isfield(o, 'firstSpike') && isstruct(o.firstSpike) && all(isfield(o.firstSpike, {'minSec', 'maxSec'}))
    win = [o.firstSpike.minSec o.firstSpike.maxSec];
end
[key, name] = sortKey(R, string(o.rasterSort), nE, u, win);
dirs = ["ascend" "ascend"];
if o.rasterSortOrder == "descending"; dirs(1) = "descend"; end
T = table(key, (1:nE).', 'VariableNames', {'key', 'idx'});
if o.rasterByGroup
    T = addvars(T, grp, 'Before', 1, 'NewVariableNames', 'g');
    dirs = ["ascend" dirs];
end
[~, order] = sortrows(T, 1:width(T), cellstr(dirs), 'MissingPlacement', 'last');
if o.rasterSortOrder == "descending"; name = name + ", descending"; end
if ~o.rasterByGroup && isfield(R, 'groups') && istable(R.groups) && height(R.groups) > 1
    name = name + ", groups mixed";
end
end


function [key, name] = sortKey(R, sortBy, nE, u, win)
%sortKey  Each epoch's sort value and the y label (time order where R lacks the key).
key = (1:nE).';
name = "Epoch";
switch sortBy
    case ""
    case "latency"
        try
            L = firstSpikeLatency(R, Units=u, MinSec=win(1), MaxSec=win(2));
            if numel(L.lat) == nE
                key = L.lat(:, 1);   % NaN (no spike in the window) sorts last
                name = "Epoch (by first-spike latency)";
            end
        catch ME
            if ~startsWith(ME.identifier, "firstSpikeLatency:"); rethrow(ME); end   % no raster rows, a bad window or unit: time order
        end
    case "stop"
        if isfield(R, 'epochStop') && numel(R.epochStop) == nE
            key = R.epochStop(:);
            name = "Epoch (by stop latency)";
        end
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
