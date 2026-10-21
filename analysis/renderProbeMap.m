function h = renderProbeMap(values, probe, target, opts)
%renderProbeMap  Draw one value per channel on the probe's sites.
%   H = renderProbeMap(VALUES, PROBE, TARGET, Name=Value) colors every site
%   of the probe map PROBE (chanMap 0-based, xc, yc, kcoords) by VALUES, all
%   shanks on one axis and one color scale. VALUES is either a numeric vector
%   indexed by 1-based recording channel, or a probeMapValues result (then
%   PROBE may be []; its units' own positions are drawn as dots).
%
%   Every site is drawn where the map puts it (xc, yc): no shank is moved.
%   The probe is drawn behind its sites, each shank (probeColumns: sites a
%   wide gap in x apart, so a site a Kilosort map parks on a kcoords group
%   of its own above a shank is on that shank) a pale body with a pointed
%   tip, named under the tip by the kcoords group holding most of its sites
%   (a probe of more than one shank), with an x tick at each shank. Sites
%   with a value are filled circles in the color scale, sites without one
%   open circles. Units per site (a result's units "units") draw a site
%   with none as one without a value, and a few counts get a color step
%   each.
%
%   Options
%     Title       text over the tiles
%     ValueName   color-bar label (default from the result: "Firing rate
%                 (Hz)", "Spikes", "Units"; else "value")
%     SiteLabels  write the channel number next to each site, on the outer
%                 side of its shank (default: when no shank has more than
%                 64 sites)
%     Style       EphysAnalysisConfig.defaults("Style") fields (HeatColormap, SiteSize,
%                 CLim, FontSize)
%
%   H: layout (tiled layout or []), axes, colorbar.
%
%   See also probeMapValues, unitSummary, renderFigure, probeColumns.

arguments
    values
    probe
    target
    opts.Title (1,1) string = ""
    opts.ValueName (1,1) string = ""
    opts.SiteLabels = []
    opts.Style = struct()
end

style = renderStyle(opts.Style);
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
if valueName == ""; valueName = valueLabel(P); end
[tl, ax] = renderLayout(target, 1, 1, style);
if isempty(ax); ax = nexttile(tl, 1); end

% the colors: the scale, and the probe's own in the plot's ground
isCount = isfield(P, 'units') && string(P.units) == "units";
fin = isfinite(P.value);
if isCount; fin = fin & P.value > 0; end   % a site with no unit is drawn as one without a value
v = P.value(fin);
counts = isCount && ~isempty(v) && all(v == round(v)) && max(v) - min(v) <= 12;
clim0 = style.CLim;
fixed = numel(clim0) == 2 && clim0(2) > clim0(1);
nColors = 256;
if ~fixed
    if isempty(v)
        clim0 = [0 1];
    elseif counts
        clim0 = [min(v) max(v)] + [-0.5 0.5];
        nColors = max(v) - min(v) + 1;
    else
        clim0 = [min(v) max(v)];
    end
    if clim0(2) <= clim0(1); clim0 = clim0 + [-0.5 0.5]; end
end
if style.HeatColormap == ""
    cmap = designColormap(style, "heat", "parula", nColors);
else
    cmap = feval(char(style.HeatColormap), nColors);
end
ground = [1 1 1];
if isfield(style, 'Design') && numel(style.Design.background) == 3; ground = style.Design.background; end
ink = [0.15 0.15 0.15];
if mean(ground) < 0.5; ink = [0.9 0.9 0.9]; end
steel = [0.42 0.45 0.5];

% the probe's geometry (um): its shanks, how far apart its sites are
[col, C] = probeColumns(P.x, P.shank);
nC = numel(C.center);
yr = [min(P.y) max(P.y)];
ySpan = diff(yr);
if ~(ySpan > 0); ySpan = 100; end
siteR = nearestHalf(P.x, P.y);
pad = min(max(1.5 * siteR, 8), 25);   % the body round its sites' x extent
gaps = C.lo(2:end) - C.hi(1:end-1);
if ~isempty(gaps); pad = min(pad, 0.25 * min(gaps)); end
hw = (C.hi - C.lo) / 2 + pad;   % each body's half width
taper = max(1.5 * max(hw), 0.06 * ySpan);
yTip = zeros(1, nC);
for c = 1:nC
    yTip(c) = min(P.y(col == c)) - max(1.2 * siteR, 0.03 * ySpan) - taper;
end
named = nC > 1;
below = 0.03;
if named; below = 0.09; end   % room for the shanks' names under their tips
yl = [min([yTip yr(1)]) - below * ySpan, yr(2) + max(2 * siteR, 0.05 * ySpan)];
if nC > 1
    xm = max(1.5 * pad, 0.06 * (max(C.center + hw) - min(C.center - hw)));
    xl = [min(C.center - hw) - xm, max(C.center + hw) + xm];
elseif nC == 1
    half = max(4 * hw, 0.2 * ySpan);
    xl = C.center + [-1 1] * half;
else
    xl = [-1 1];
end

hold(ax, 'on');
for c = 1:nC   % the bodies run past the top of the axes: the probe goes on above
    bx = C.center(c) + hw(c) * [-1 -1 0 1 1];
    by = [yl(2) + ySpan, yTip(c) + taper, yTip(c), yTip(c) + taper, yl(2) + ySpan];
    tagPart(patch(ax, 'XData', bx, 'YData', by, 'FaceColor', paleColor(steel, 0.86, style), ...
        'EdgeColor', paleColor(steel, 0.45, style), 'LineWidth', 0.75, 'HandleVisibility', 'off'), "probeShank");
end
sz = style.SiteSize;
if any(~fin)
    tagPart(plot(ax, P.x(~fin), P.y(~fin), 'o', 'MarkerSize', sz, 'Color', paleColor(steel, 0.3, style), ...
        'MarkerFaceColor', ground, 'LineWidth', 0.75), "emptySites");
end
if any(fin)
    tagPart(scatter(ax, P.x(fin), P.y(fin), sz^2, P.value(fin), 'o', 'filled', 'MarkerEdgeColor', [0.25 0.25 0.25], ...
        'LineWidth', 0.5), "sites");
end
labels = opts.SiteLabels;
if isempty(labels); labels = max([0 C.n]) <= 64; end
if labels && nC > 0
    % Each label on the outer side of its site (a shank's left column to the left), clear of the marker
    % and of the column beside it. The gap is spaces, so it is in points whatever the axis scale.
    fs = max(5, style.FontSize - 3);
    gap = string(blanks(ceil((sz / 2 + 0.5) / (0.28 * fs))));
    left = false(size(P.x));
    on = col > 0;
    mid = C.center(:);
    left(on) = P.x(on) < mid(col(on)) - 1e-6;
    txt = string(P.channel(:));
    lab = {'FontSize', fs, 'Color', paleColor(ink, 0.4, style), 'Interpreter', 'none', 'VerticalAlignment', 'middle'};
    right = on & ~left;
    if any(right); tagPart(text(ax, P.x(right), P.y(right), gap + txt(right), lab{:}, 'HorizontalAlignment', 'left'), "siteLabels"); end
    if any(left); tagPart(text(ax, P.x(left), P.y(left), txt(left) + gap, lab{:}, 'HorizontalAlignment', 'right'), "siteLabels"); end
end
if isfield(P, 'unitX') && ~isempty(P.unitX)
    ux = P.unitX(:);
    uy = P.unitY(:);
    u = isfinite(ux) & isfinite(uy);
    if any(u)
        tagPart(plot(ax, ux(u), uy(u), 'o', 'MarkerSize', max(3.5, 0.55 * sz), 'Color', ink, 'MarkerFaceColor', ink, ...
            'MarkerEdgeColor', ground, 'LineWidth', 0.75), "unitDots");
    end
end
if named
    for c = 1:nC
        tagPart(text(ax, C.center(c), yTip(c) - 0.015 * ySpan, sprintf('Shank %d', C.shank(c)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', style.FontSize, 'Color', ink), "shankLabels");
    end
end
hold(ax, 'off');
colormap(ax, cmap);
clim(ax, clim0);
xlim(ax, xl);
ylim(ax, yl);
if nC > 1; ax.XTick = unique(round(C.center)); end
ax.FontSize = style.FontSize;
ax.TickDir = 'out';
box(ax, 'off');
xlabel(ax, 'x (µm)'); ylabel(ax, 'y (µm)');
axs = ax;
cb = colorbar(axs(end));
cb.Label.String = valueName;
cb.TickDirection = 'out';
if counts && ~fixed; cb.Ticks = min(v):max(v); end
if ~isempty(tl); cb.Layout.Tile = 'east'; end
if opts.Title ~= ""
    if ~isempty(tl); title(tl, opts.Title); else; title(axs(1), opts.Title); end
end
h = struct('layout', tl, 'axes', axs, 'colorbar', cb);
end


function s = valueLabel(P)
%valueLabel  The color bar's label: the value's name and unit.
s = "value";
if isfield(P, 'valueName')
    switch string(P.valueName)
        case "rate",    s = "Firing rate (Hz)"; return
        case "nSpikes", s = "Spikes"; return
        case "nUnits",  s = "Units"; return
    end
end
if isfield(P, 'units') && string(P.units) ~= ""; s = string(P.units); end
end


function r = nearestHalf(x, y)
%nearestHalf  Half the typical distance from a site to its nearest neighbor (um; 10 for a single site).
ok = isfinite(x) & isfinite(y);
x = x(ok); y = y(ok);
r = 10;
if numel(x) < 2; return; end
D = hypot(x - x.', y - y.');
D(1:numel(x)+1:end) = Inf;
d = min(D, [], 2);
d = d(d > 0 & isfinite(d));
if ~isempty(d); r = median(d) / 2; end
end
