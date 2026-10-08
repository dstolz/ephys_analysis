function h = renderRaster(R, target, opts)
%renderRaster  Draw the spike rasters of a spikePSTH result, one tile per unit.
%   H = renderRaster(R, TARGET, Page=, SortBy=, SortOrder=, ByGroup=, EventMarks=, Waveform=, Style=)
%   draws one raster per unit of the page (MaxTiles per page; units by
%   Style.SortShank / Style.SortDepth, titled with their shank / depth for
%   Style.LabelShank / Style.LabelDepth): epochs as rows, sorted by group,
%   then by SortBy, then by time, each group on a pale band of its colour;
%   all ticks of a tile are one line object. An axes TARGET gets the first
%   unit of the page. Every row is shown: Style.YLim does not apply to
%   rasters.
%
%   SortBy  "" (default): the epochs of a group in time (trial) order;
%           "stop": by their stop event's latency (R.epochStop); else the
%           name of a column of R.epochs, e.g. a trial parameter (compute
%           the epochs with epochTable(..., Columns=SortBy)). Missing
%           values sort last; ties stay in time order
%   SortOrder  "ascending" (default) or "descending": the direction of
%           SortBy ("" descending is the reverse time order); missing
%           values stay last
%   ByGroup true (default): rows by group first, each group on its band;
%           false: every epoch sorted by SortBy as one block, each row on
%           its group's colour
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
%
%   H: layout (tiled layout or []), axes.
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
    opts.Style = struct()
end

style = EphysAnalysisConfig.normalizeSection("Style", opts.Style);
wave = EphysAnalysisConfig.normalizeSection("Waveform", opts.Waveform);
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
axs = gobjects(1, numel(idx));
meta = [];
if isfield(R, 'meta'); meta = R.meta; end
names = siteLabels(shortUnitLabels(R.labels), meta, style);
order = probeOrder(meta, nU, style);
look = struct('order', opts.SortOrder, 'byGroup', opts.ByGroup, 'marks', opts.EventMarks);
for j = 1:numel(idx)
    u = order(idx(j));
    if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
    rasterInto(ax, R, u, style, colors, opts.SortBy, look);
    tagPart(ax, "rasterAxes", "", names(u));
    waveformInset(ax, waves, u, wave, style);
    title(ax, names(u), 'FontWeight', 'normal', 'Interpreter', 'none');
    r = ceil(j / nc);
    if r == nr || ~isempty(ax0); xlabel(ax, 'Time (s)'); end
    if j - (r - 1) * nc > 1; ax.YLabel.String = ''; end   % "Epoch" on the left column only
    axs(j) = ax;
end
marks = struct('label', {}, 'look', {});
if isfield(R, 'rasterEvents') && ~isempty(R.rasterEvents)
    mk = EphysAnalysisConfig.coerceStruct(EphysAnalysisConfig.defaults("Plot").rasterEvents, opts.EventMarks, "EventMarks");
    for m = 1:numel(R.rasterEvents)
        marks(m).label = R.rasterEvents(m).label;
        marks(m).look = {'LineStyle', 'none', 'Marker', mk.marker, 'MarkerSize', mk.size, ...
            'Color', rasterMarkColor(mk.color, m), 'MarkerFaceColor', rasterMarkColor(mk.color, m)};
    end
end
if ~isempty(axs) && style.Legend && (height(R.groups) > 1 || ~isempty(marks))
    ax = axs(1);
    hold(ax, 'on');
    lh = gobjects(1, 0);
    labels = strings(1, 0);
    if height(R.groups) > 1
        for g = 1:height(R.groups)
            lh(end+1) = tagPart(patch(ax, NaN, NaN, colors(g, :) + (1 - colors(g, :)) * 0.82, 'EdgeColor', colors(g, :)), ...
                "rasterBand", R.groups.label(g)); %#ok<AGROW>
            labels(end+1) = R.groups.label(g); %#ok<AGROW>
        end
    end
    for m = 1:numel(marks)   % a stand-in per mark: the aesthetics rules of its marks reach it too
        lh(end+1) = tagPart(line(ax, NaN, NaN, marks(m).look{:}), "rasterEvent", marks(m).label); %#ok<AGROW>
        labels(end+1) = marks(m).label; %#ok<AGROW>
    end
    hold(ax, 'off');
    legend(ax, lh, labels, 'Location', 'bestoutside', 'Box', 'off', 'Interpreter', 'none', ...
        'FontSize', max(6, style.FontSize - 1));
end
cornerLabels(axs, nr, nc, style);
if nr * nc > 1; tileTicks(axs, style); end
h = struct('layout', tl, 'axes', axs);
end
