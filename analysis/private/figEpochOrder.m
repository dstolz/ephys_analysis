function [order, name] = figEpochOrder(R, o, u)
%figEpochOrder  A result's epochs in a raster's row order, top row first, and the rows' y label.
%   [ORDER, NAME] = figEpochOrder(R, O, U), for a result R that holds its
%   epochs' groups (R.epochGroup [nE x 1], rows of R.groups), stop
%   latencies (R.epochStop), the sort event's latencies
%   (R.rasterSortEvent: label, t), the epochs (R.epochs: a trial
%   parameter's column) and, for the latency sort, its units' first-spike
%   latencies (R.latency: the figure's, figureLatencies), and the options O
%   (rasterSort, rasterSortOrder, rasterByGroup) of a raster
%   (rasterInto), a heat map of trials (figTrialMatrix) or an event
%   trace's sub-rows (drawEventTracePanel). U (default 1) is the raster
%   unit the latency sort reads:
%     ORDER  the epochs, top row first: by group first with
%            O.rasterByGroup; then O.rasterSort -- "" the epochs' time
%            order, "stop" their stop latency, "event" R.rasterSortEvent.t,
%            "latency" their first-spike latency (R.latency.lat of unit U:
%            by the figure's latency block, its method and window, whether
%            or not the marks are on; an epoch with no latency counts as
%            missing),
%            else that column of R.epochs -- in O.rasterSortOrder, missing
%            values last, ties in time order
%     NAME   the rows' y label: "Epoch", with the sort ("Epoch (by Depth),
%            descending")
%   A sort key R lacks (no sort event, no such column, no latencies for
%   "latency") sorts in time order.
%
%   See also figTrialMatrix, drawEventTracePanel, rasterInto, figureLatencies.

if nargin < 3; u = 1; end
grp = double(R.epochGroup(:));
nE = numel(grp);
[key, name] = sortKey(R, string(o.rasterSort), nE, u);
dirs = ["ascend" "ascend"];
if o.rasterSortOrder == "descending"; dirs(1) = "descend"; end
if o.rasterByGroup   % (the table made at once: addvars took a quarter of a raster's drawing)
    T = table(grp, key, (1:nE).', 'VariableNames', {'g', 'key', 'idx'});
    dirs = ["ascend" dirs];
else
    T = table(key, (1:nE).', 'VariableNames', {'key', 'idx'});
end
[~, order] = sortrows(T, 1:width(T), cellstr(dirs), 'MissingPlacement', 'last');
if o.rasterSortOrder == "descending"; name = name + ", descending"; end
if ~o.rasterByGroup && isfield(R, 'groups') && istable(R.groups) && height(R.groups) > 1
    name = name + ", groups mixed";
end
end


function [key, name] = sortKey(R, sortBy, nE, u)
%sortKey  Each epoch's sort value and the y label (time order where R lacks the key).
key = (1:nE).';
name = "Epoch";
switch sortBy
    case ""
    case "latency"
        if isfield(R, 'latency') && isstruct(R.latency) && isfield(R.latency, 'lat') && size(R.latency.lat, 1) == nE ...
                && u >= 1 && u <= size(R.latency.lat, 2)
            key = R.latency.lat(:, u);   % NaN (no latency) sorts last
            name = "Epoch (by first-spike latency)";
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
