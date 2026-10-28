function h = renderProbeMap(values, probe, target, opts)
%renderProbeMap  Draw values on the probe: one per unit, or one per site.
%   H = renderProbeMap(VALUES, PROBE, TARGET, Name=Value) draws the probe
%   map PROBE (chanMap 0-based, xc, yc, kcoords) with VALUES in one color
%   scale, all shanks on one axis. VALUES is either a numeric vector
%   indexed by 1-based recording channel (each site colored by its
%   channel's), or a probeMapValues result (then PROBE may be []; its
%   units are drawn as dots at their own positions, colored by their own
%   value where the result is one per unit, R.on "units", else ink dots
%   over sites colored by theirs).
%
%   Every site is drawn where the map puts it (xc, yc): no shank is moved.
%   The probe is drawn behind its sites, each shank (probeColumns: sites a
%   wide gap in x apart, so a site a Kilosort map parks on a kcoords group
%   of its own above a shank is on that shank) a pale body with a pointed
%   tip, named under the tip by the kcoords group holding most of its sites
%   (a probe of more than one shank), with an x tick at each shank. Sites
%   with a value are filled circles in the color scale, sites without one
%   (every site, where the values are the units') open circles; units with
%   a value filled circles in the color scale, those without one open.
%   Units per site (a result's units "units") draw a site with none as one
%   without a value, and a few counts get a color step each.
%
%   With Waveforms (unitWaveforms, a row per unit of the result's table)
%   and a Waveform mode other than "off", each unit is drawn as its
%   waveform instead of a dot: a glyph centered on its position, as a unit
%   waveforms panel's probe layout draws it (waveformGlyphs; the mean,
%   with its band, the spikes, both, or the template; width and height:
%   1 = about a twelfth of the probe's length tall, 1.6 times as wide).
%   The units' values then color nothing, and there is no color bar (units
%   per site still color the sites), unless ColorWaveforms is true: each
%   glyph (mean, band and spikes) then takes the color of its unit's value
%   (rate or spike count) in the color scale, a unit without one gray, and
%   the color bar is drawn.
%
%   UnitLabels writes each unit's name (shortUnitLabels of the table's
%   label) in a column beside its shank, clear of the units, each with a
%   leader and an arrowhead stopping short of its unit (dot or glyph). One
%   shank: the units right of its middle labeled on the right, the others
%   on the left; several: the first shank's on its left, every other's on
%   its right, so each gap between shanks holds one column. A column's
%   labels keep the height of their units where they can, spread apart
%   (in points: they do not overlap at the size drawn) where they cannot.
%   The x limits widen to hold them.
%
%   Options
%     Title       text over the tiles
%     ValueName   color-bar label (default from the result: "Firing rate
%                 (Hz)", "Spikes", "Units"; else "value")
%     SiteLabels  write the channel number next to each site, on the outer
%                 side of its shank (default: when no shank has more than
%                 64 sites, UnitLabels is off and the units are dots)
%     UnitLabels  each unit's name beside it, with an arrow (default false)
%     Waveforms   unitWaveforms of the result's units (default [] = dots)
%     Waveform    the glyphs' settings (EphysAnalysisConfig.defaults(
%                 "Waveform"): mode, band, timeMs, ampScale, ampLim, width,
%                 height); mode "off" (default) draws dots
%     ColorWaveforms  color each glyph by its unit's value (default false)
%     Style       EphysAnalysisConfig.defaults("Style") fields (HeatColormap, SiteSize,
%                 CLim, FontSize)
%
%   H: layout (tiled layout or []), axes, colorbar (empty when none),
%   glyph ([width height] of a unit's glyph, um; [0 0] for dots).
%   Parts: probeShank, emptySites, sites, siteLabels, unitDots, waveBand,
%   waveSpikes, waveMean, unitLeaders, unitArrows, unitLabels,
%   shankLabels.
%
%   See also probeMapValues, unitSummary, renderFigure, probeColumns, waveformGlyphs.

arguments
    values
    probe
    target
    opts.Title (1,1) string = ""
    opts.ValueName (1,1) string = ""
    opts.SiteLabels = []
    opts.UnitLabels (1,1) logical = false
    opts.Waveforms = []
    opts.Waveform = struct()
    opts.ColorWaveforms (1,1) logical = false
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
        'on', "sites", 'value', v, 'units', "value", 'unitX', [], 'unitY', []);
    P.x = P.x(:); P.y = P.y(:);
end
valueName = opts.ValueName;
if valueName == ""; valueName = valueLabel(P); end
[tl, ax] = renderLayout(target, 1, 1, style);
if isempty(ax); ax = nexttile(tl, 1); end

% the colors: the scale, and the probe's own in the plot's ground
onUnits = isfield(P, 'on') && P.on == "units";   % the value is the units', not the sites'
isCount = isfield(P, 'units') && string(P.units) == "units";
fin = isfinite(P.value);
if isCount; fin = fin & P.value > 0; end   % a site with no unit is drawn as one without a value
v = P.value(fin);
if onUnits; fin = false(size(P.x)); end   % then no site has one
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

% the units: where they are, and drawn as waveforms (a glyph each) instead of dots
ux = zeros(0, 1); uy = zeros(0, 1);
if isfield(P, 'unitX') && ~isempty(P.unitX); ux = double(P.unitX(:)); uy = double(P.unitY(:)); end
wave = EphysAnalysisConfig.normalizeSection("Waveform", opts.Waveform);
W = opts.Waveforms;
glyphs = wave.mode ~= "off" && isstruct(W) && isfield(W, 'mean') && numel(W.mean) == numel(ux) && ~isempty(ux);
gw = 0; gh = 0;
colored = false;
if glyphs
    WP = cell(numel(ux), 1);
    for u = 1:numel(ux); WP{u} = waveformParts(W, u, wave); end
    base = max(30, ySpan / 12);   % as a unit waveforms panel's probe layout
    gh = wave.height * base;
    gw = 1.6 * wave.width * base;
    Gl = waveformGlyphs(W, WP, ux, uy, gw, gh, wave);
    glyphs = any(Gl.placed);
    colored = glyphs && opts.ColorWaveforms && onUnits;   % the glyphs take their units' values' colors
    if glyphs
        xl = [min(xl(1), min(ux(Gl.placed)) - 0.6 * gw), max(xl(2), max(ux(Gl.placed)) + 0.6 * gw)];
        yl = [min(yl(1), min(uy(Gl.placed)) - 0.6 * gh), max(yl(2), max(uy(Gl.placed)) + 0.6 * gh)];
    else
        gw = 0; gh = 0;
    end
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
if isempty(labels); labels = max([0 C.n]) <= 64 && ~opts.UnitLabels && ~glyphs; end   % the units' labels take the shanks' sides, glyphs cover them
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
dotPt = 0;   % a unit's dot's diameter (points), for its label's arrow to stop short of
if glyphs
    meanColor = [0.80 0.10 0.10];
    if colored   % each glyph in its unit's value's color (a unit without one gray)
        uc = repmat(steel, numel(ux), 1);
        hasV = isfinite(P.value(:));
        step = min(max(round(1 + (P.value(hasV) - clim0(1)) / (clim0(2) - clim0(1)) * (size(cmap, 1) - 1)), 1), size(cmap, 1));
        uc(hasV, :) = cmap(step, :);
        for u = find(~cellfun(@isempty, Gl.band)).'
            B = Gl.band{u};
            errorPatch(ax, B(:, 1), B(:, 2), B(:, 3), uc(u, :), "", style, "waveBand");
        end
        for u = find(~cellfun(@isempty, Gl.spikes)).'
            tagPart(line(ax, Gl.spikes{u}(:, 1), Gl.spikes{u}(:, 2), 'Color', [uc(u, :) 0.25], 'LineWidth', 0.5), "waveSpikes");
        end
        for u = find(~cellfun(@isempty, Gl.mean)).'
            tagPart(line(ax, Gl.mean{u}(:, 1), Gl.mean{u}(:, 2), 'Color', uc(u, :), 'LineWidth', max(1, style.LineWidth)), "waveMean");
        end
    else
        for u = find(~cellfun(@isempty, Gl.band)).'
            B = Gl.band{u};
            errorPatch(ax, B(:, 1), B(:, 2), B(:, 3), meanColor, "", style, "waveBand");
        end
        Sx = vertcat(Gl.spikes{:});
        if ~isempty(Sx)
            tagPart(line(ax, Sx(:, 1), Sx(:, 2), 'Color', [0.30 0.45 0.75 0.25], 'LineWidth', 0.5), "waveSpikes");
        end
        M = vertcat(Gl.mean{:});
        if ~isempty(M)
            tagPart(line(ax, M(:, 1), M(:, 2), 'Color', meanColor, 'LineWidth', max(1, style.LineWidth)), "waveMean");
        end
    end
elseif ~isempty(ux)
    u = isfinite(ux) & isfinite(uy);
    dotPt = max(3.5, 0.55 * sz);
    if onUnits; dotPt = 0.8 * sz; end
    if onUnits
        uv = P.value(:);
        has = u & isfinite(uv);
        if any(u & ~has)
            tagPart(plot(ax, ux(u & ~has), uy(u & ~has), 'o', 'MarkerSize', 0.8 * sz, 'Color', ink, ...
                'MarkerFaceColor', ground, 'LineWidth', 0.75), "unitDots");
        end
        if any(has)
            tagPart(scatter(ax, ux(has), uy(has), (0.8 * sz)^2, uv(has), 'o', 'filled', 'MarkerEdgeColor', ink, ...
                'LineWidth', 0.75), "unitDots");
        end
    elseif any(u)
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
cb = gobjects(0);
if ~(glyphs && onUnits) || colored   % waveforms color nothing, unless ColorWaveforms asks
    cb = colorbar(axs(end));
    cb.Label.String = valueName;
    cb.TickDirection = 'out';
    if counts && ~fixed; cb.Ticks = min(v):max(v); end
    if ~isempty(tl); cb.Layout.Tile = 'east'; end
end
if opts.Title ~= ""
    if ~isempty(tl); title(tl, opts.Title); else; title(axs(1), opts.Title); end
end
if opts.UnitLabels && ~isempty(ux)   % last: the axes' size in points is known now
    unitLabels(ax, P, ux, uy, C, hw, dotPt, [gw gh], ink, style);
end
h = struct('layout', tl, 'axes', axs, 'colorbar', cb, 'glyph', [gw gh]);
end


function unitLabels(ax, P, ux, uy, C, hw, dotPt, glyph, ink, style)
%unitLabels  Each unit's name in a column beside its shank, a leader and an arrowhead from it to the unit.
%   A unit at UX, UY is a dot DOTPT points wide, or a glyph GLYPH ([w h],
%   um) wide and tall. Its column of labels: one shank (C, the sites'
%   probeColumns; HW the bodies' half widths), the units right of its
%   middle on the right, the others on the left; several shanks, the
%   first one's on its left, every other one's on its right. The labels
%   keep their units' heights where they can, spread apart where they
%   cannot (spreadLabels); the arrows stop 1.5 points short of the unit.
names = string(1:numel(ux)).';
if isfield(P, 'table') && istable(P.table) && height(P.table) == numel(ux)
    vars = string(P.table.Properties.VariableNames);
    if ismember("label", vars)
        names = shortUnitLabels(P.table.label(:));
    elseif ismember("unitId", vars)
        names = string(P.table.unitId(:));
    end
end
on = isfinite(ux) & isfinite(uy);
nC = numel(C.center);
if ~any(on) || nC == 0; return; end
[~, ~, uc] = probeColumns(P.x, P.shank, ux);
uc = uc(:);
on = on & uc > 0;
fs = max(5, style.FontSize - 3);
gapPt = 14;                          % a label's least distance from its shank's units, along x
padPt = 2;                           % between a label and its leader's start
stopPt = 1.5;                        % between the arrow's tip and its unit
lineH = 1.25 * fs;                   % a label's height, points
side = zeros(numel(ux), 1);          % -1 left of its shank, 1 right
for c = 1:nC
    k = on & uc == c;
    if nC == 1
        side(k) = 1;
        side(k & ux < C.center(c) - 1e-6) = -1;
    elseif c == 1
        side(k) = -1;
    else
        side(k) = 1;
    end
end
textW = 0.6 * fs * strlength(names);   % points, about
half = glyph / 2;
yl = ylim(ax);
xl = xlim(ax);
for pass = 1:3   % the x limits widen to hold the labels, which moves them: lay them out again
    [wPt, hPt] = axesPoints(ax);
    xpp = diff(xl) / wPt;            % data units per point
    ypp = diff(yl) / hPt;
    cx = zeros(numel(ux), 1);        % each label's x (the end its leader starts at)
    ly = NaN(numel(ux), 1);
    lo = xl(1); hi = xl(2);
    for c = 1:nC
        for s = [-1 1]
            k = find(on & uc == c & side == s);
            if isempty(k); continue; end
            mine = on & uc == c;
            if s > 0
                edge = max([C.center(c) + hw(c); ux(mine) + half(1) + 0.5 * dotPt * xpp]);
                x0 = edge + gapPt * xpp;
                hi = max(hi, x0 + (padPt + max(textW(k)) + 4) * xpp);
            else
                edge = min([C.center(c) - hw(c); ux(mine) - half(1) - 0.5 * dotPt * xpp]);
                x0 = edge - gapPt * xpp;
                lo = min(lo, x0 - (padPt + max(textW(k)) + 4) * xpp);
            end
            cx(k) = x0;
            ly(k) = spreadLabels(uy(k), lineH * ypp, yl(1) + 0.5 * lineH * ypp, yl(2) - 0.5 * lineH * ypp);
        end
    end
    if lo >= xl(1) && hi <= xl(2); break; end
    xl = [lo hi];
    xlim(ax, xl);
end

% the leaders: from beside each label to the unit's edge, an arrowhead there
k = find(on);
ax0 = cx(k) + side(k) * -padPt * xpp;   % a right-hand label's leader starts left of it
ay0 = ly(k);
dx = (ux(k) - ax0) / xpp;                % label to unit, points
dy = (uy(k) - ay0) / ypp;
d = hypot(dx, dy);
d(d == 0) = 1;
if glyph(1) > 0   % to the glyph's box: the ray leaves it where the nearer of its sides is crossed
    tx = (half(1) / xpp) ./ abs(dx);
    ty = (half(2) / ypp) ./ abs(dy);
    reach = d .* (1 - min(tx, ty)) - stopPt;   % from the label's end to the arrow's tip, points
else
    reach = d - 0.5 * dotPt - stopPt;
end
keep = reach > 4;                        % room for a leader and its arrowhead
k = k(keep); ax0 = ax0(keep); ay0 = ay0(keep); dx = dx(keep); dy = dy(keep); d = d(keep); reach = reach(keep);
ex = dx ./ d; ey = dy ./ d;              % unit vectors, points
tipX = ax0 + ex .* reach * xpp;
tipY = ay0 + ey .* reach * ypp;
len = 4; wid = 1.6;                      % the arrowhead, points
bx = tipX - ex * len * xpp; by = tipY - ey * len * ypp;
leadC = paleColor(ink, 0.35, style);
if ~isempty(k)
    X = [ax0 bx NaN(numel(k), 1)].';
    Y = [ay0 by NaN(numel(k), 1)].';
    tagPart(line(ax, X(:), Y(:), 'Color', leadC, 'LineWidth', 0.5, 'HandleVisibility', 'off'), "unitLeaders");
    V = [tipX tipY; bx - ey * wid * xpp, by + ex * wid * ypp; bx + ey * wid * xpp, by - ex * wid * ypp];
    n = numel(k);
    tagPart(patch(ax, 'Faces', [1:n; n + (1:n); 2 * n + (1:n)].', 'Vertices', V, 'FaceColor', leadC, ...
        'EdgeColor', 'none', 'HandleVisibility', 'off'), "unitArrows");
end
lab = {'FontSize', fs, 'Color', ink, 'Interpreter', 'none', 'VerticalAlignment', 'middle', 'Clipping', 'off'};
r = find(on & side > 0);
l = find(on & side < 0);
if ~isempty(r); tagPart(text(ax, cx(r), ly(r), names(r), lab{:}, 'HorizontalAlignment', 'left'), "unitLabels"); end
if ~isempty(l); tagPart(text(ax, cx(l), ly(l), names(l), lab{:}, 'HorizontalAlignment', 'right'), "unitLabels"); end
end


function y = spreadLabels(y0, d, lo, hi)
%spreadLabels  Heights for labels wished at Y0, at least D apart and inside [LO HI] where they fit, in Y0's order.
%   Neighbors too close are pooled into a block centered on their wishes'
%   mean (kept inside the bounds), D apart; blocks that then overlap pool
%   again. Labels too many for the bounds overflow both ends alike.
[ys, o] = sort(y0(:));
n = numel(ys);
first = zeros(n, 1); last = zeros(n, 1); mid = zeros(n, 1);
nb = 0;
for i = 1:n
    nb = nb + 1;
    first(nb) = i; last(nb) = i;
    mid(nb) = centerOf(ys, i, i, d, lo, hi);
    while nb > 1 && mid(nb - 1) + (last(nb - 1) - first(nb - 1)) * d / 2 + d > mid(nb) - (last(nb) - first(nb)) * d / 2 + 1e-9
        last(nb - 1) = last(nb);
        nb = nb - 1;
        mid(nb) = centerOf(ys, first(nb), last(nb), d, lo, hi);
    end
end
y = zeros(n, 1);
for b = 1:nb
    m = last(b) - first(b);
    y(first(b):last(b)) = mid(b) + ((0:m).' - m / 2) * d;
end
y(o) = y;
end


function c = centerOf(ys, i, j, d, lo, hi)
%centerOf  A block's center: its labels' wishes' mean, moved inside [LO HI] as far as its height allows.
c = mean(ys(i:j));
h = (j - i) * d / 2;
if hi - lo < 2 * h
    c = (lo + hi) / 2;
else
    c = min(max(c, lo + h), hi - h);
end
end


function [w, h] = axesPoints(ax)
%axesPoints  The axes' plot box in points (a default before the figure is laid out).
for attempt = 1:2
    u = ax.Units;
    ax.Units = 'pixels';
    p = ax.InnerPosition;
    ax.Units = u;
    k = 72 / get(groot, 'ScreenPixelsPerInch');
    w = p(3) * k; h = p(4) * k;
    if w > 20 && h > 20; return; end
    if attempt == 1; drawnow limitrate; end
end
w = 432; h = 288;
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
