function h = renderProbeMap(values, probe, target, opts)
%renderProbeMap  Draw one value per channel on the probe's sites.
%   H = renderProbeMap(VALUES, PROBE, TARGET, Name=Value) colours every site
%   of the probe map PROBE (chanMap 0-based, xc, yc, kcoords) by VALUES, one
%   tile per shank on one colour scale. VALUES is either a numeric vector
%   indexed by 1-based recording channel, or a probeMapValues result (then
%   PROBE may be []; its units' own positions are drawn as black dots).
%   Sites without a value are open grey squares.
%
%   Options
%     Title       text over the tiles
%     ValueName   colour-bar label (default the result's units, else "value")
%     SiteLabels  write the channel number next to each site (default: when
%                 a shank has at most 64 sites)
%     Style       EphysAnalysisConfig.defaults("Style") fields (HeatColormap,
%                 CLim, FontSize)
%
%   H: layout (tiled layout or []), axes, colorbar.
%
%   See also probeMapValues, unitSummary, renderPlot.

arguments
    values
    probe
    target
    opts.Title (1,1) string = ""
    opts.ValueName (1,1) string = ""
    opts.SiteLabels = []
    opts.Style = struct()
end

style = EphysAnalysisConfig.normalizeSection("Style", opts.Style);
if isstruct(values) && isfield(values, 'kind') && values.kind == "probemap"
    P = values;
else
    if isempty(probe) || ~isstruct(probe) || ~all(isfield(probe, {'chanMap', 'xc', 'yc'}))
        error('renderProbeMap:NoProbe', 'A probe map (chanMap, xc, yc) is needed.');
    end
    ch = double(probe.chanMap(:)) + 1;
    n = numel(ch);
    v = NaN(n, 1);
    ok = ch >= 1 & ch <= numel(values);
    v(ok) = values(ch(ok));
    shank = zeros(n, 1);
    if isfield(probe, 'kcoords'); k = double(probe.kcoords(:)); shank = k(1:n); end
    P = struct('channel', ch, 'x', double(probe.xc(1:n)).', 'y', double(probe.yc(1:n)).', 'shank', shank, ...
        'value', v, 'units', "value", 'unitX', [], 'unitY', []);
    P.x = P.x(:); P.y = P.y(:);
end
valueName = opts.ValueName;
if valueName == ""; valueName = string(P.units); end
shanks = unique(P.shank(:)).';
nSh = numel(shanks);
[tl, ax0] = renderLayout(target, 1, nSh);
if ~isempty(ax0); shanks = shanks(1:min(1, end)); end
clim0 = style.CLim;
if ~(numel(clim0) == 2 && clim0(2) > clim0(1))
    v = P.value(isfinite(P.value));
    if isempty(v); clim0 = [0 1]; else; clim0 = [min(v) max(v)]; end
    if clim0(2) <= clim0(1); clim0 = clim0 + [-0.5 0.5]; end
end
cmapName = style.HeatColormap;
if cmapName == ""; cmapName = "parula"; end
cmap = feval(char(cmapName), 256);
xr = [min(P.x) max(P.x)]; yr = [min(P.y) max(P.y)];
axs = gobjects(1, numel(shanks));
for j = 1:numel(shanks)
    if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
    on = P.shank == shanks(j);
    xs = P.x(on); ys = P.y(on); vs = P.value(on); cs = P.channel(on);
    fin = isfinite(vs);
    hold(ax, 'on');
    if any(~fin)
        plot(ax, xs(~fin), ys(~fin), 's', 'MarkerSize', 7, 'Color', [0.6 0.6 0.6]);
    end
    if any(fin)
        scatter(ax, xs(fin), ys(fin), 60, vs(fin), 's', 'filled', 'MarkerEdgeColor', [0.3 0.3 0.3]);
    end
    labels = opts.SiteLabels;
    if isempty(labels); labels = nnz(on) <= 64; end
    if labels
        text(ax, xs + 6, ys, string(cs), 'FontSize', max(5, style.FontSize - 3), 'Color', [0.35 0.35 0.35]);
    end
    if isfield(P, 'unitX') && ~isempty(P.unitX) && isfield(P, 'table') && istable(P.table) ...
            && ismember("shank", string(P.table.Properties.VariableNames))
        u = P.table.shank == shanks(j) & isfinite(P.unitX) & isfinite(P.unitY);
        plot(ax, P.unitX(u), P.unitY(u), 'k.', 'MarkerSize', 10);
    end
    hold(ax, 'off');
    colormap(ax, cmap);
    clim(ax, clim0);
    sx = [min(xs) max(xs)];
    xlim(ax, mean(sx) + [-1 1] * max(40, diff(xr) / max(1, nSh) / 2 + 20));
    ylim(ax, yr + [-1 1] * max(20, 0.04 * diff(yr)));
    ax.FontSize = style.FontSize;
    box(ax, 'on');
    title(ax, sprintf('Shank %d', shanks(j)), 'FontWeight', 'normal');
    xlabel(ax, 'x (µm)');
    if j == 1; ylabel(ax, 'y (µm)'); end
    axs(j) = ax;
end
cb = gobjects(0);
if ~isempty(axs)
    cb = colorbar(axs(end));
    cb.Label.String = valueName;
    if ~isempty(tl); cb.Layout.Tile = 'east'; end
end
if opts.Title ~= ""
    if ~isempty(tl); title(tl, opts.Title); else; title(axs(1), opts.Title); end
end
h = struct('layout', tl, 'axes', axs, 'colorbar', cb);
end
