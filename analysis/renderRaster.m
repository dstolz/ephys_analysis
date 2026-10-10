function h = renderRaster(R, target, opts)
%renderRaster  Draw the spike rasters of a spikePSTH result, one tile per unit.
%   H = renderRaster(R, TARGET, Page=, SortBy=, SortOrder=, ByGroup=, EventMarks=, Waveform=, Aux=, Style=)
%   draws one raster per unit of the page (MaxTiles per page; units by
%   Style.SortShank / Style.SortDepth, titled with their shank / depth for
%   Style.LabelShank / Style.LabelDepth): epochs as rows, sorted by group,
%   then by SortBy, then by time, each group on a pale band of its color;
%   all ticks of a tile are one line object. An axes TARGET gets the first
%   unit of the page. Every row is shown: Style.YLim does not apply to
%   rasters.
%
%   SortBy  "" (default): the epochs of a group in time (trial) order;
%           "stop": by their stop event's latency (R.epochStop); "event":
%           by their latency to another event, R.rasterSortEvent (a
%           struct: label, e.g. "Platform offset", and t, each epoch's
%           latency in s from eventLatency); else the name of a column of
%           R.epochs, e.g. a trial parameter (compute the epochs with
%           epochTable(..., Columns=SortBy)). Missing values (no such
%           event: NaN) sort last; ties stay in time order
%   SortOrder  "ascending" (default) or "descending": the direction of
%           SortBy ("" descending is the reverse time order); missing
%           values stay last
%   ByGroup true (default): rows by group first, each group on its band;
%           false: every epoch sorted by SortBy as one block, each row on
%           its group's color
%   EventMarks  EphysAnalysisConfig.defaults("Plot").rasterEvents fields
%           (marker, size, color): how the events in R.rasterEvents
%           (epochEvents) are marked on their rows, one mark per event,
%           named "rasterEvent" with its line and edge for the aesthetics
%           editor; the legend lists them
%   Waveform  EphysAnalysisConfig.defaults("Waveform") fields: each unit's
%           waveform from R.waveforms (unitWaveforms) as a box in its
%           tile -- its mean, a subsample of its spikes, or both -- at a
%           compass point (location), with or without the box's outline
%           (box), sized by scale (default mode "off": none)
%   Aux     EphysAnalysisConfig.defaults("Aux") fields: with a mode other
%           than "off" (default "off": none), the mean aux signal R.aux
%           (auxMean) in every unit's tile, by its placement: "below" or
%           "above" the raster, a panel of its own half the raster's
%           height, flush on the same time axis; or "over" it, on its right
%           y axis. An axes TARGET has room for "over" only. The traces
%           look as auxLooks says; several channels get legend entries.
%           yLim fixes the signal's y limits; overPosition ([bottom top],
%           fractions of the raster's height) is where it sits over the
%           raster (auxInto)
%
%   The grid's x and y labels are its tiled layout's (the y label says how
%   the rows are sorted, and names an aux panel below or above them), and
%   its legend goes east of the grid unless Style.LegendLocation says
%   otherwise.
%
%   H: layout (tiled layout or []), axes, auxAxes (the aux panels, tagged
%   "auxAxes").
%
%   See also spikePSTH, renderPSTH, renderPlot.

arguments
    R (1,1) struct
    target
    opts.Page (1,1) double {mustBePositive, mustBeInteger} = 1
    opts.SortBy (1,1) string = ""
    opts.SortOrder (1,1) string {mustBeMember(opts.SortOrder, ["ascending" "descending"])} = "ascending"
    opts.ByGroup (1,1) logical = true
    opts.EventMarks = struct()
    opts.Waveform = struct()
    opts.Aux = struct()
    opts.Style = struct()
end

style = renderStyle(opts.Style);
wave = EphysAnalysisConfig.normalizeSection("Waveform", opts.Waveform);
auxOpt = EphysAnalysisConfig.normalizeSection("Aux", opts.Aux);
waves = [];
if isfield(R, 'waveforms'); waves = R.waveforms; end
if ~isfield(R, 'raster') || isempty(R.raster)
    error('renderRaster:NoRaster', 'The result holds no raster (compute it with spikePSTH(..., Raster=true)).');
end
colors = groupPalette(R.groups, style);
nU = numel(R.raster);
[idx, nr, nc] = pageItems(nU, opts.Page, style.MaxTiles);
[tl, ax0] = renderLayout(target, nr, nc, style);
if ~isempty(ax0); idx = idx(1:min(1, end)); end
place = "";   % where the mean aux signal goes: "" (none), "above", "below" (panels of their own) or "over"
X = [];
W = R.edges([1 end]);
if auxOpt.mode ~= "off" && isfield(R, 'aux') && isstruct(R.aux) && ~isempty(R.aux)
    place = auxOpt.placement;
    X = auxLooks(R.aux, colors, style);
end
if ~isempty(ax0) && ismember(place, ["above" "below"]); place = ""; end   % one axes: no room for a panel
axs = gobjects(1, numel(idx));
xax = gobjects(1, 0);
meta = [];
if isfield(R, 'meta'); meta = R.meta; end
names = siteLabels(shortUnitLabels(R.labels), meta, style);
order = probeOrder(meta, nU, style);
look = struct('order', opts.SortOrder, 'byGroup', opts.ByGroup, 'marks', opts.EventMarks);
rows = "Epoch";
for j = 1:numel(idx)
    u = order(idx(j));
    c = j - (ceil(j / nc) - 1) * nc;
    xa = gobjects(0);
    if ~isempty(ax0)
        ax = ax0;
    elseif ismember(place, ["above" "below"])
        % the raster and its aux panel share the tile, flush on one time axis: the raster two rows, the aux one
        pair = tiledlayout(tl, 3, 1, 'TileSpacing', 'none', 'Padding', 'tight');
        pair.Layout.Tile = j;
        if place == "above"
            xa = nexttile(pair, 1);
            ax = nexttile(pair, 2, [2 1]);
        else
            ax = nexttile(pair, 1, [2 1]);
            xa = nexttile(pair, 3);
        end
    else
        ax = nexttile(tl, j);
    end
    rows = rasterInto(ax, R, u, style, colors, opts.SortBy, look);
    tagPart(ax, "rasterAxes", "", names(u));
    waveformInset(ax, waves, u, wave, style);
    top = ax;
    if ~isempty(xa)
        auxInto(xa, R.aux, X, W, style, false, false, auxOpt);
        tagPart(xa, "auxAxes", "", names(u));
        if place == "above"
            xa.XTickLabel = [];
            top = xa;
        else
            ax.XTickLabel = [];
        end
        xax(end+1) = xa; %#ok<AGROW>
    elseif place == "over"
        auxInto(ax, R.aux, X, W, style, true, c == nc || j == numel(idx) || ~isempty(ax0), auxOpt);
    end
    title(top, names(u), 'FontWeight', 'normal', 'Interpreter', 'none');
    axs(j) = ax;
end
yName = rows;
if ~isempty(xax)
    if place == "below"
        yName = X.label + "  ·  " + rows;
    else
        yName = rows + "  ·  " + X.label;
    end
end
gridLabels(tl, [axs xax], "Time (s)", yName, style);
marks = struct('label', {}, 'look', {});
if isfield(R, 'rasterEvents') && ~isempty(R.rasterEvents)
    mk = EphysAnalysisConfig.coerceStruct(EphysAnalysisConfig.defaults("Plot").rasterEvents, opts.EventMarks, "EventMarks");
    for m = 1:numel(R.rasterEvents)
        marks(m).label = R.rasterEvents(m).label;
        marks(m).look = {'LineStyle', 'none', 'Marker', mk.marker, 'MarkerSize', mk.size, ...
            'Color', rasterMarkColor(mk.color, m), 'MarkerFaceColor', rasterMarkColor(mk.color, m)};
    end
end
auxEntries = ~isempty(X) && ~isempty(X.legend);
if ~isempty(axs) && style.Legend && (height(R.groups) > 1 || ~isempty(marks) || auxEntries)
    ax = axs(1);
    hold(ax, 'on');
    lh = gobjects(1, 0);
    labels = strings(1, 0);
    if height(R.groups) > 1
        for g = 1:height(R.groups)
            lh(end+1) = tagPart(patch(ax, NaN, NaN, paleColor(colors(g, :), 0.82, style), 'EdgeColor', colors(g, :)), ...
                "rasterBand", R.groups.label(g)); %#ok<AGROW>
            labels(end+1) = R.groups.label(g); %#ok<AGROW>
        end
    end
    for m = 1:numel(marks)   % a stand-in per mark: the aesthetics rules of its marks reach it too
        lh(end+1) = tagPart(line(ax, NaN, NaN, marks(m).look{:}), "rasterEvent", marks(m).label); %#ok<AGROW>
        labels(end+1) = marks(m).label; %#ok<AGROW>
    end
    if auxEntries   % the aux channels (auxStandIns)
        [sh, sl] = auxStandIns(ax, X, style);
        lh = [lh sh];
        labels = [labels sl];
    end
    hold(ax, 'off');
    placeLegend(ax, lh, labels, style, tl, "east");
end
if nr * nc > 1; tileTicks([axs xax], style); end
edge = "top";
if place == "above"; edge = "bottom"; end
auxEdgeTicks(xax, edge);
h = struct('layout', tl, 'axes', axs, 'auxAxes', xax);
end
