function rows = rasterInto(ax, R, u, style, colors, sortBy, look)
%rasterInto  Draw unit U's raster from a spikePSTH result into AX.
%   ROWS = rasterInto(...) is the y label that says what the rows are and
%   how they are sorted ("Epoch (by level), descending"); the caller puts
%   it on the grid (gridLabels). Epochs are rows, first on top. LOOK (a
%   struct; every field optional) says how they are ordered and what is
%   marked on them:
%     order    "ascending" (default) | "descending": the direction of the
%              SORTBY key. SORTBY "" (default) is the epochs' time (trial)
%              order, so "descending" turns it over; "stop" sorts them by
%              their stop event's latency (R.epochStop); "event" by their
%              latency to the event of R.rasterSortEvent (label, t:
%              eventLatency); any other value names a column of R.epochs
%              (a trial parameter epochTable copied on). Missing values
%              sort last either way; ties keep the time order
%    byGroup   true (default): the rows go by group first, each group's on
%              a pale band of its color; false: every epoch sorted as one
%              block, each row on its group's color
%    marks     EphysAnalysisConfig.defaults("Plot").rasterEvents: the look
%              (marker, size, color) of the events in R.rasterEvents
%              (epochEvents), one line object per line and edge, tagged
%              "rasterEvent" with its label (e.g. "Trough onset")
%   All ticks are one line object (NaN-separated), so even long rasters
%   export small. With ShowStop each epoch's stop event is a dot. The axes
%   are styled (styleAxes) without Style.YLim: that is for rates, and every
%   row stays in view.
if nargin < 6; sortBy = ""; end
if nargin < 7; look = struct(); end
look = rasterLook(look);
nE = numel(R.epochGroup);
[key, name] = rasterSortKey(R, sortBy, nE);
dirs = ["ascend" "ascend"];
if look.order == "descending"; dirs(1) = "descend"; end
T = table(key, (1:nE).', 'VariableNames', {'key', 'idx'});
if look.byGroup
    T = addvars(T, R.epochGroup(:), 'Before', 1, 'NewVariableNames', 'g');
    dirs = ["ascend" dirs];
end
[~, order] = sortrows(T, 1:width(T), cellstr(dirs), 'MissingPlacement', 'last');
row = zeros(nE, 1);
row(order) = 1:nE;
W = R.edges([1 end]);
hold(ax, 'on');
for g = 1:height(R.groups)
    rows = sort(row(R.epochGroup == g));
    if isempty(rows); continue; end
    brk = [0; find(diff(rows) > 1); numel(rows)];   % each run of adjacent rows is one face
    r1 = rows(brk(1:end-1) + 1) - 0.5;
    r2 = rows(brk(2:end)) + 0.5;
    nb = numel(r1);
    tagPart(patch(ax, 'XData', repmat(reshape(W([1 2 2 1]), 4, 1), 1, nb), 'YData', [r1 r1 r2 r2].', ...
        'FaceColor', paleColor(colors(g, :), 0.82, style), 'EdgeColor', 'none', 'HandleVisibility', 'off'), ...
        "rasterBand", R.groups.label(g));
end
tm = R.raster(u).times(:);
ep = R.raster(u).epoch(:);
if ~isempty(tm)
    rr = row(ep);
    X = [tm tm NaN(size(tm))].';
    Y = [rr - 0.4 rr + 0.4 NaN(size(rr))].';
    tagPart(line(ax, X(:), Y(:), 'Color', [0 0 0], 'LineWidth', 0.5), "rasterTicks");
end
if style.ShowStop && any(isfinite(R.epochStop))
    ok = isfinite(R.epochStop) & R.epochStop >= W(1) & R.epochStop <= W(2);
    tagPart(line(ax, R.epochStop(ok), row(ok), 'LineStyle', 'none', 'Marker', '.', 'MarkerSize', 6, 'Color', [0.8 0.1 0.1]), ...
        "rasterStop");
end
if isfield(R, 'rasterEvents')
    for m = 1:numel(R.rasterEvents)
        ev = R.rasterEvents(m);
        ok = ev.t >= W(1) & ev.t <= W(2);
        c = rasterMarkColor(look.marks.color, m);
        tagPart(line(ax, ev.t(ok), row(ev.epoch(ok)), 'LineStyle', 'none', 'Marker', look.marks.marker, ...
            'MarkerSize', look.marks.size, 'Color', c, 'MarkerFaceColor', c, 'HandleVisibility', 'off'), "rasterEvent", ev.label);
    end
end
if style.ShowZeroLine
    tagPart(xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'), "zeroLine");
end
hold(ax, 'off');
set(ax, 'YDir', 'reverse');
xlim(ax, W);
ylim(ax, [0.5 max(1, nE) + 0.5]);
if look.order == "descending"; name = name + ", descending"; end
if ~look.byGroup && height(R.groups) > 1; name = name + ", groups mixed"; end
rows = name;
style.YLim = [];
styleAxes(ax, style);
end


function look = rasterLook(look)
%rasterLook  LOOK with its missing fields filled (rasterInto's defaults).
if ~isfield(look, 'order') || look.order == ""; look.order = "ascending"; end
if ~isfield(look, 'byGroup'); look.byGroup = true; end
def = EphysAnalysisConfig.defaults("Plot").rasterEvents;
if ~isfield(look, 'marks') || isempty(look.marks)
    look.marks = def;
else
    look.marks = EphysAnalysisConfig.coerceStruct(def, look.marks, "rasterEvents");
end
look.order = string(look.order);
look.byGroup = logical(look.byGroup);
end


function [key, name] = rasterSortKey(R, sortBy, nE)
%rasterSortKey  Each epoch's sort value and the raster's y label.
%   "" gives the epoch index (time order), "stop" R.epochStop, "event"
%   R.rasterSortEvent.t, any other name that column of R.epochs.
sortBy = strtrim(string(sortBy));
name = "Epoch";
if sortBy == ""
    key = (1:nE).';
    return
end
if sortBy == "stop"
    key = R.epochStop(:);
    name = "Epoch (by stop latency)";
    return
end
if sortBy == "event"
    if ~(isfield(R, 'rasterSortEvent') && isstruct(R.rasterSortEvent) && isscalar(R.rasterSortEvent) ...
            && all(isfield(R.rasterSortEvent, {'label', 't'})))
        error('renderRaster:NoSortEvent', ['The raster sorts by an event''s latency, but the result holds no ' ...
            'R.rasterSortEvent (label, t: eventLatency).']);
    end
    key = R.rasterSortEvent.t(:);
    if numel(key) ~= nE
        error('renderRaster:NoSortEvent', 'R.rasterSortEvent.t holds %d latencies for %d epochs.', numel(key), nE);
    end
    name = "Epoch (by " + string(R.rasterSortEvent.label) + " latency)";
    return
end
if ~(isfield(R, 'epochs') && istable(R.epochs) && ismember(sortBy, string(R.epochs.Properties.VariableNames)))
    error('renderRaster:NoSortColumn', ['The raster sorts by "%s", which is not a column of the epochs ' ...
        '(R.epochs: epochTable(..., Columns="%s")).'], sortBy, sortBy);
end
key = R.epochs.(sortBy);
if size(key, 1) ~= nE || size(key, 2) ~= 1
    error('renderRaster:NoSortColumn', 'The epochs'' column "%s" is not one value per epoch.', sortBy);
end
name = "Epoch (by " + sortBy + ")";
end
