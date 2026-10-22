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
%              eventLatency); "latency" by their first spike's latency
%              (firstSpikeLatency of unit U, in the window of
%              look.firstSpike's minSec and maxSec -- on or off -- else from
%              the event to the window's end); any other value names a
%              column of R.epochs (a trial parameter epochTable copied on).
%              Missing values (an epoch with no first spike) sort last
%              either way; ties keep the time order. The order is
%              figEpochOrder's, which the heat map of trials shares; a key
%              the result lacks sorts in time order
%    byGroup   true (default): the rows go by group first; false: every
%              epoch sorted as one block, each row's ticks in its group's
%              color
%    marks     Plot.rasterEvents (EventMark structs): each mark's look
%              (marker, size, color; rasterMarkLooks) for the events in
%              R.rasterEvents (epochEvents), one line object per mark,
%              tagged "rasterEvent" with its label (e.g. "Trough onset")
%    into      [] (default) or a stack's rows: a
%              struct with base (1 x nGroups: the bottom of each group's
%              raster, in AX's y units) and height. Each group's epochs
%              then fill a band of their own, from its base up, the first
%              at the bottom (byGroup does not apply: a band is one
%              group's); AX keeps its limits, direction and style, and no
%              zero line is drawn (the stack has its own). Optional
%              fields: trials (default Inf), the most epochs a band shows,
%              picked evenly over the group's sorted order (the others not
%              drawn); equal (default false): every band's rows one height,
%              that of the band showing the most epochs, filled from the
%              bottom (false: each band's rows fill it)
%    tickColor  "groups" (default: each group's color, as the PSTH colors its
%               traces) or a color name or hex code: every tick in that
%               color
%    backColor  "none" (default: no bands), "groups" (a pale band of each
%               group's color behind its rows) or a color name or hex code
%               (every group's band in that color)
%    firstSpike [] (default: none) or defaults("FirstSpike") (a raster
%               panel's options.firstSpike): with enabled, a mark on each
%               epoch's first spike at or after minSec and at or before
%               maxSec (firstSpikeLatency of unit U), on that epoch's row
%               wherever the sort, the groups or a stack's band put it,
%               over the ticks; in its marker and size, filled or not,
%               each group's color ("groups") or one color. One line
%               object per group, tagged "firstSpike" with the group's
%               label, its epochs in appdata PlotEpochs (the data tips')
%   Each group's ticks are one line object (NaN-separated), tagged
%   "rasterTicks" with the group's label, so even long rasters export small.
%   With ShowStop each epoch's stop event is a dot. The axes
%   are styled (styleAxes) without Style.YLim: that is for rates, and every
%   row stays in view.
%   R.rasterSpans (optional: label, epoch, on, off, color, style, width,
%   alpha) draws a line on each epoch's row from each interval's onset to
%   its offset, clipped to the window, one line object per span, tagged
%   "eventSpan" with its label.
if nargin < 6; sortBy = ""; end
if nargin < 7; look = struct(); end
look = rasterLook(look);
nE = numel(R.epochGroup);
so = struct('rasterSort', strtrim(string(sortBy)), 'rasterSortOrder', look.order, 'rasterByGroup', look.byGroup, ...
    'firstSpike', look.firstSpike);
[order, name] = figEpochOrder(R, so, u);   % the rows' order, shared with the heat map of trials and the event traces
row = zeros(nE, 1);
row(order) = 1:nE;
W = R.edges([1 end]);
into = ~isempty(look.into);
if into
    [y, half] = stackRows(row, R.epochGroup(:), look.into);
else
    y = row;
    half = 0.4 * ones(nE, 1);
end
fixed = rasterColor(look.tickColor, []);   % one color for every tick; [] = each group's own
[back, bands] = rasterBack(look.backColor);   % bands: whether there are any; back: their one color, [] = each group's pale one
held = ishold(ax);   % a stack goes on drawing in AX after its rasters: leave its hold as found
hold(ax, 'on');
bandOf = 1:height(R.groups);
if ~bands; bandOf = []; end
for g = bandOf
    rows = sort(row(R.epochGroup == g));
    if isempty(rows); continue; end
    if into   % the group's band: its rows' share of the stack
        r1 = look.into.base(g);
        r2 = r1 + look.into.height;
    else
        brk = [0; find(diff(rows) > 1); numel(rows)];   % each run of adjacent rows is one face
        r1 = rows(brk(1:end-1) + 1) - 0.5;
        r2 = rows(brk(2:end)) + 0.5;
    end
    nb = numel(r1);
    face = paleColor(colors(g, :), 0.82, style);
    if ~isempty(back); face = back; end
    tagPart(patch(ax, 'XData', repmat(reshape(W([1 2 2 1]), 4, 1), 1, nb), 'YData', [r1 r1 r2 r2].', ...
        'FaceColor', face, 'EdgeColor', 'none', 'HandleVisibility', 'off'), ...
        "rasterBand", R.groups.label(g));
end
tm = R.raster(u).times(:);
ep = R.raster(u).epoch(:);
if ~isempty(tm)
    rr = y(ep);
    hh = half(ep);
    gg = R.epochGroup(ep);
    for g = 1:height(R.groups)   % one line per group, in its color
        in = gg == g;
        if ~any(in); continue; end
        c = colors(g, :);
        if ~isempty(fixed); c = fixed; end
        X = [tm(in) tm(in) NaN(nnz(in), 1)].';
        Y = [rr(in) - hh(in) rr(in) + hh(in) NaN(nnz(in), 1)].';
        tagPart(line(ax, X(:), Y(:), 'Color', c, 'LineWidth', 0.5), "rasterTicks", R.groups.label(g));
    end
end
if isstruct(look.firstSpike) && look.firstSpike.enabled && look.firstSpike.minSec <= look.firstSpike.maxSec
    firstSpikeMarks(ax, R, u, y, colors, look.firstSpike);
end
if style.ShowStop && any(isfinite(R.epochStop))
    ok = isfinite(R.epochStop) & R.epochStop >= W(1) & R.epochStop <= W(2);
    tagPart(line(ax, R.epochStop(ok), y(ok), 'LineStyle', 'none', 'Marker', '.', 'MarkerSize', 6, 'Color', [0.8 0.1 0.1]), ...
        "rasterStop");
end
if isfield(R, 'rasterEvents') && ~isempty(R.rasterEvents)
    mks = rasterMarkLooks(look.marks, [R.rasterEvents.label]);
    for m = 1:numel(R.rasterEvents)
        ev = R.rasterEvents(m);
        ok = ev.t >= W(1) & ev.t <= W(2);
        tagPart(line(ax, ev.t(ok), y(ev.epoch(ok)), 'LineStyle', 'none', 'Marker', mks(m).marker, ...
            'MarkerSize', mks(m).size, 'Color', mks(m).color, 'MarkerFaceColor', mks(m).color, 'HandleVisibility', 'off'), ...
            "rasterEvent", ev.label);
    end
end
if isfield(R, 'rasterSpans')   % a line on each row from each interval's onset to its offset, clipped to the window
    for m = 1:numel(R.rasterSpans)
        s = R.rasterSpans(m);
        x0 = max(s.on(:), W(1));
        x1 = min(s.off(:), W(2));
        yy = y(s.epoch(:));
        ok = x1 >= x0 & isfinite(yy(:));
        n = nnz(ok);
        X = [x0(ok) x1(ok) NaN(n, 1)].';
        Y = [yy(ok) yy(ok) NaN(n, 1)].';
        tagPart(line(ax, X(:), Y(:), 'Color', [s.color s.alpha], 'LineStyle', char(s.style), 'LineWidth', s.width, ...
            'HandleVisibility', 'off'), "eventSpan", s.label);
    end
end
if style.ShowZeroLine && ~into
    tagPart(xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'), "zeroLine");
end
if ~held; hold(ax, 'off'); end
if into
    rows = name;
    return
end
set(ax, 'YDir', 'reverse');
xlim(ax, W);
ylim(ax, [0.5 max(1, nE) + 0.5]);
rows = name;
style.YLim = [];
styleAxes(ax, style);
end


function [y, half] = stackRows(row, grp, into)
%stackRows  Each epoch's y in a stack's rows, and its ticks' half height.
%   Each group's epochs, in their sorted order (ROW), share the group's band
%   [into.base(g), into.base(g) + into.height] evenly, the first at the
%   bottom: at most into.trials of them, spread evenly over that order, in
%   rows of one height for every band with into.equal. An epoch in no
%   group, or left out, is NaN (not drawn).
trials = Inf;
if isfield(into, 'trials') && ~isempty(into.trials); trials = into.trials; end
equal = isfield(into, 'equal') && ~isempty(into.equal) && into.equal;
nE = numel(row);
y = NaN(nE, 1);
half = zeros(nE, 1);
nG = numel(into.base);
shown = cell(1, nG);   % each group's epochs drawn, bottom row first
for g = 1:nG
    in = find(grp == g);
    [~, ord] = sort(row(in));
    in = in(ord);
    n = numel(in);
    if n > trials; in = in(unique(round(linspace(1, n, trials)))); end
    shown{g} = in;
end
most = max([cellfun(@numel, shown) 1]);
for g = 1:nG
    in = shown{g};
    n = numel(in);
    if n == 0; continue; end
    if equal; n = most; end
    slot = into.height / n;
    y(in) = into.base(g) + ((1:numel(in)).' - 0.5) * slot;
    half(in) = 0.4 * slot;
end
end


function look = rasterLook(look)
%rasterLook  LOOK with its missing fields filled (rasterInto's defaults).
if ~isfield(look, 'order') || look.order == ""; look.order = "ascending"; end
if ~isfield(look, 'byGroup'); look.byGroup = true; end
if ~isfield(look, 'marks'); look.marks = []; end
if ~isfield(look, 'into'); look.into = []; end
if ~isfield(look, 'tickColor'); look.tickColor = "groups"; end
if ~isfield(look, 'backColor'); look.backColor = "none"; end
if ~isfield(look, 'firstSpike'); look.firstSpike = []; end
look.order = string(look.order);
look.byGroup = logical(look.byGroup);
end


function firstSpikeMarks(ax, R, u, y, colors, fs)
%firstSpikeMarks  A mark on each epoch's first spike in [fs.minSec, fs.maxSec] (firstSpikeLatency), on its row Y, a line per group.
%   An epoch with no spike in the window, or not drawn (Y NaN: left out of
%   a stack's band), has none.
L = firstSpikeLatency(R, Units=u, MinSec=fs.minSec, MaxSec=fs.maxSec);
lat = L.lat(:, 1);
fixed = rasterColor(fs.color, []);
grp = R.epochGroup(:);
for g = 1:height(R.groups)
    ep = find(grp == g & isfinite(lat) & isfinite(y(:)));
    if isempty(ep); continue; end
    c = colors(g, :);
    if ~isempty(fixed); c = fixed; end
    face = 'none';
    if fs.filled; face = c; end
    h = tagPart(line(ax, lat(ep), y(ep), 'LineStyle', 'none', 'Marker', char(fs.marker), 'MarkerSize', fs.size, ...
        'Color', c, 'MarkerFaceColor', face, 'HandleVisibility', 'off'), "firstSpike", string(R.groups.label(g)));
    setappdata(h, 'PlotEpochs', ep);
end
end


function c = rasterColor(spec, c)
%rasterColor  The RGB triplet of a color name or hex code; C (the default) for "groups" or a spec that is not a color.
spec = strtrim(string(spec));
if spec == "groups"; return; end
try
    c = namedColor(spec);
catch
    % not a color: the default
end
end


function [c, bands] = rasterBack(spec)
%rasterBack  The bands' look from LOOK.backColor: BANDS whether any are drawn, C their one color ([] = each group's pale one).
%   "groups" is the groups' pale bands; a color name or hex code, one color
%   for every band; "none", "" or a spec that is not a color, no bands.
spec = strtrim(string(spec));
c = [];
bands = spec == "groups";
if bands || spec == "" || spec == "none"; return; end
c = rasterColor(spec, []);
bands = ~isempty(c);
end
