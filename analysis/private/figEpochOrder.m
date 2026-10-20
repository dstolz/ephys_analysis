function [order, name] = figEpochOrder(R, o)
%figEpochOrder  A result's epochs in a raster's row order, top row first, and the rows' y label.
%   [ORDER, NAME] = figEpochOrder(R, O), for a result R that holds its
%   epochs' groups (R.epochGroup [nE x 1], rows of R.groups), stop
%   latencies (R.epochStop), the sort event's latencies
%   (R.rasterSortEvent: label, t) and the epochs (R.epochs: a trial
%   parameter's column), and the options O (rasterSort, rasterSortOrder,
%   rasterByGroup) of a heat map of trials (figTrialMatrix) or an event
%   trace's sub-rows (drawEventTracePanel):
%     ORDER  the epochs, top row first: rasterInto's order (by group first
%            with O.rasterByGroup; then O.rasterSort -- "" the epochs' time
%            order, "stop" their stop latency, "event" R.rasterSortEvent.t,
%            else that column of R.epochs -- in O.rasterSortOrder, missing
%            values last, ties in time order)
%     NAME   the rows' y label: "Epoch", with the sort ("Epoch (by Depth),
%            descending")
%   A sort key R lacks (no sort event, no such column) sorts in time order.
%
%   See also figTrialMatrix, drawEventTracePanel, rasterInto.

grp = double(R.epochGroup(:));
nE = numel(grp);
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
if ~o.rasterByGroup && isfield(R, 'groups') && istable(R.groups) && height(R.groups) > 1
    name = name + ", groups mixed";
end
end


function [key, name] = sortKey(R, sortBy, nE)
%sortKey  Each epoch's sort value and the y label (rasterInto's rules; time order where R lacks the key).
key = (1:nE).';
name = "Epoch";
switch sortBy
    case ""
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
