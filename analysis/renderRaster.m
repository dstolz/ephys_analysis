function h = renderRaster(R, target, opts)
%renderRaster  Draw the spike rasters of a spikePSTH result, one tile per unit.
%   H = renderRaster(R, TARGET, Page=, SortBy=, Waveform=, Style=) draws one raster per unit of
%   the page (MaxTiles per page; units by Style.SortShank / Style.SortDepth,
%   titled with their shank / depth for Style.LabelShank / Style.LabelDepth):
%   epochs as rows, sorted by group, then by SortBy, then by time,
%   each group on a pale band of its colour; all ticks of a tile are one
%   line object. An axes TARGET gets the first unit of the page. Every row
%   is shown: Style.YLim does not apply to rasters.
%
%   SortBy  "" (default): the epochs of a group in time (trial) order;
%           "stop": by their stop event's latency (R.epochStop); else the
%           name of a column of R.epochs, e.g. a trial parameter (compute
%           the epochs with epochTable(..., Columns=SortBy)). Missing
%           values sort last; ties stay in time order
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
for j = 1:numel(idx)
    u = order(idx(j));
    if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
    rasterInto(ax, R, u, style, colors, opts.SortBy);
    tagPart(ax, "rasterAxes", "", names(u));
    waveformInset(ax, waves, u, wave, style);
    title(ax, names(u), 'FontWeight', 'normal', 'Interpreter', 'none');
    r = ceil(j / nc);
    if r == nr || ~isempty(ax0); xlabel(ax, 'Time (s)'); end
    if j - (r - 1) * nc > 1; ax.YLabel.String = ''; end   % "Epoch" on the left column only
    axs(j) = ax;
end
if ~isempty(axs) && style.Legend && height(R.groups) > 1
    ax = axs(1);
    hold(ax, 'on');
    lh = gobjects(1, height(R.groups));
    for g = 1:height(R.groups)
        lh(g) = tagPart(patch(ax, NaN, NaN, colors(g, :) + (1 - colors(g, :)) * 0.82, 'EdgeColor', colors(g, :)), ...
            "rasterBand", R.groups.label(g));
    end
    hold(ax, 'off');
    legend(ax, lh, R.groups.label, 'Location', 'bestoutside', 'Box', 'off', 'Interpreter', 'none', ...
        'FontSize', max(6, style.FontSize - 1));
end
cornerLabels(axs, nr, nc, style);
if nr * nc > 1; tileTicks(axs, style); end
h = struct('layout', tl, 'axes', axs);
end
