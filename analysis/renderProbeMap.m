function h = renderProbeMap(values, probe, target, opts)
%renderProbeMap  Draw one value per channel on the probe's sites.
%   H = renderProbeMap(VALUES, PROBE, TARGET, Name=Value) colours every site
%   of the probe map PROBE (chanMap 0-based, xc, yc, kcoords) by VALUES, all
%   shanks on one axis and one colour scale. VALUES is either a numeric vector
%   indexed by 1-based recording channel, or a probeMapValues result (then
%   PROBE may be []; its units' own positions are drawn as black dots).
%   Sites without a value are open grey squares.
%
%   Options
%     Title       text over the tiles
%     ValueName   colour-bar label (default the result's units, else "value")
%     SiteLabels  write the channel number next to each site (default: when
%                 no shank has more than 64 sites)
%     Style       EphysAnalysisConfig.defaults("Style") fields (HeatColormap, SiteSize,
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
[tl, ax] = renderLayout(target, 1, 1, style);
if isempty(ax); ax = nexttile(tl, 1); end
clim0 = style.CLim;
if ~(numel(clim0) == 2 && clim0(2) > clim0(1))
    v = P.value(isfinite(P.value));
    if isempty(v); clim0 = [0 1]; else; clim0 = [min(v) max(v)]; end
    if clim0(2) <= clim0(1); clim0 = clim0 + [-0.5 0.5]; end
end
cmapName = style.HeatColormap;
if cmapName == ""; cmapName = "parula"; end
cmap = feval(char(cmapName), 256);

% One axis for every shank: shift a shank sideways only where it would overlap the one before.
xoff = zeros(nSh, 1);
gap = max(40, 0.5 * max(1, median(diff(sort(unique(P.x))))));
edge = -Inf;
for j = 1:nSh
    xs = P.x(P.shank == shanks(j));
    if min(xs) <= edge + gap - 1e-9
        xoff(j) = edge + gap - min(xs);
    end
    edge = max(xs) + xoff(j);
end
X = P.x + xoff(arrayfun(@(k) find(shanks == k, 1), P.shank(:)));
yr = [min(P.y) max(P.y)];
sz = style.SiteSize;

hold(ax, 'on');
fin = isfinite(P.value);
if any(~fin)
    tagPart(plot(ax, X(~fin), P.y(~fin), 's', 'MarkerSize', sz, 'Color', [0.6 0.6 0.6]), "emptySites");
end
if any(fin)
    tagPart(scatter(ax, X(fin), P.y(fin), sz^2, P.value(fin), 's', 'filled', 'MarkerEdgeColor', [0.3 0.3 0.3]), "sites");
end
labels = opts.SiteLabels;
if isempty(labels); labels = max(arrayfun(@(k) nnz(P.shank == k), shanks)) <= 64; end
if labels
    % Each label on the outer side of its site (a shank's left column to the left), clear of the marker
    % and of the column beside it. The gap is spaces, so it is in points whatever the axis scale.
    fs = max(5, style.FontSize - 3);
    pad = string(blanks(ceil((sz / 2 + 0.5) / (0.28 * fs))));
    left = false(size(X));
    for k = shanks
        on = P.shank(:) == k;
        xs = P.x(on);
        left(on) = xs < (min(xs) + max(xs)) / 2;
    end
    txt = string(P.channel(:));
    lab = {'FontSize', fs, 'Color', [0.35 0.35 0.35], 'Interpreter', 'none'};
    if any(~left); tagPart(text(ax, X(~left), P.y(~left), pad + txt(~left), lab{:}, 'HorizontalAlignment', 'left'), "siteLabels"); end
    if any(left); tagPart(text(ax, X(left), P.y(left), txt(left) + pad, lab{:}, 'HorizontalAlignment', 'right'), "siteLabels"); end
end
if isfield(P, 'unitX') && ~isempty(P.unitX) && isfield(P, 'table') && istable(P.table) ...
        && ismember("shank", string(P.table.Properties.VariableNames))
    ux = P.unitX(:) + xoff(arrayfun(@(k) find(shanks == k, 1), P.table.shank(:)));
    u = isfinite(ux) & isfinite(P.unitY(:));
    tagPart(plot(ax, ux(u), P.unitY(u), 'k.', 'MarkerSize', 10), "unitDots");
end
if nSh > 1
    for j = 1:nSh
        xs = X(P.shank == shanks(j));
        tagPart(text(ax, mean([min(xs) max(xs)]), yr(2) + max(20, 0.04 * diff(yr)), sprintf('Shank %d', shanks(j)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', style.FontSize), "shankLabels");
    end
end
hold(ax, 'off');
colormap(ax, cmap);
clim(ax, clim0);
pad = max(40, 0.05 * max(1, diff([min(X) max(X)])));
xlim(ax, [min(X) max(X)] + [-1 1] * pad);
ylim(ax, yr + [-1 1] * max(20, 0.04 * diff(yr)) + [0 (nSh > 1) * max(20, 0.04 * diff(yr)) * 1.5]);
ax.FontSize = style.FontSize;
box(ax, 'on');
xlabel(ax, 'x (µm)'); ylabel(ax, 'y (µm)');
axs = ax;
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
