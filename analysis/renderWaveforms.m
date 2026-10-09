function h = renderWaveforms(R, target, opts)
%renderWaveforms  Draw each unit's waveform: a tile per unit, or at its place on the probe.
%   H = renderWaveforms(R, TARGET, Layout=, Page=, Waveform=, Style=) draws
%   the waveforms of R.waveforms (unitWaveforms) for the units R.meta
%   (selectUnits' table) as the waveform settings say
%   (EphysAnalysisConfig.defaults("Waveform")):
%     mode       "mean" (the mean waveform), "subsample" (maxSpikes of the
%                unit's spikes, thin) or "both"; "off" is read as "both". A
%                template (no spikes read) is drawn as the mean whatever the
%                mode, and says so
%     ampScale   "unit": each waveform fills its tile / glyph; "common": one
%                amplitude scale for all units whose values are of the same
%                kind (R.waveforms.units), so their sizes can be compared
%     showPP, showCount   the mean's peak-to-peak amplitude, the unit's
%                number of spikes, in the label
%     scale, showSites, showNames   the probe layout's glyph size (1 = about
%                a twelfth of the probe's length), the probe's sites behind
%                the glyphs, each unit's name (and label) beside its glyph
%
%   Layout
%     "grid"   (default) one tile per unit (MaxTiles per page), titled by
%              unit and ordered by Style.SortShank / Style.SortDepth like
%              the other grids; time (ms from the spike) against amplitude,
%              with the spike's time marked; a label in the tile's corner
%     "probe"  one panel, the probe's x and y (um): each unit's waveform as
%              a glyph centred on its position (R.meta.x, y), shanks side by
%              side as in the probe map, the sites in grey behind. In the
%              common scale a bar says how much amplitude a bar's length is.
%              Units without a position are left out, and the panel says so
%
%   H: layout (tiled layout or []), axes.
%
%   See also unitWaveforms, renderPlot, renderProbeMap.

arguments
    R (1,1) struct
    target
    opts.Layout (1,1) string {mustBeMember(opts.Layout, ["grid" "probe"])} = "grid"
    opts.Page (1,1) double {mustBePositive, mustBeInteger} = 1
    opts.Waveform = struct()
    opts.Style = struct()
end

style = renderStyle(opts.Style);
wave = EphysAnalysisConfig.normalizeSection("Waveform", opts.Waveform);
if wave.mode == "off"; wave.mode = "both"; end
if ~isfield(R, 'waveforms') || isempty(R.waveforms)
    error('renderWaveforms:NoWaveforms', 'The result holds no waveforms (compute them with unitWaveforms).');
end
W = R.waveforms;
nU = height(R.meta);
P = cell(nU, 1);
for u = 1:nU
    P{u} = unitParts(W, u, wave.mode);
end
if opts.Layout == "probe"
    h = probeLayout(R, W, P, target, wave, style);
else
    h = gridLayout(R, W, P, target, wave, style, opts.Page);
end
end


function h = gridLayout(R, W, P, target, wave, style, page)
%gridLayout  One tile per unit of the page.
nU = numel(P);
[idx, nr, nc] = pageItems(nU, page, style.MaxTiles);
[tl, ax0] = renderLayout(target, nr, nc, style);
if ~isempty(ax0); idx = idx(1:min(1, end)); end
axs = gobjects(1, numel(idx));
names = siteLabels(shortUnitLabels(R.labels), R.meta, style);
order = probeOrder(R.meta, nU, style);
for j = 1:numel(idx)
    u = order(idx(j));
    if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
    tagPart(ax, "axes", "", names(u));
    p = P{u};
    hold(ax, 'on');
    if p.has
        if wave.ampScale == "common"
            [lo, hi] = commonRange(W, P, W.units(u));
        else
            [lo, hi] = valueRange(p);
        end
        pad = 0.08 * (hi - lo);
        if ~(pad > 0); pad = 1; end
        if p.spikes
            tagPart(line(ax, repmat([p.t; NaN], size(p.S, 2), 1), reshape([p.S; NaN(1, size(p.S, 2))], [], 1), ...
                'Color', [0.30 0.45 0.75 0.25], 'LineWidth', 0.5), "waveSpikes");
        end
        if p.mean
            tagPart(line(ax, p.t, p.m, 'Color', [0.80 0.10 0.10], 'LineWidth', max(1, style.LineWidth)), "waveMean");
        end
        tagPart(xline(ax, 0, ':', 'Color', [0.5 0.5 0.5]), "waveZero");
        xlim(ax, [min(p.t) max(p.t)]);
        ylim(ax, [lo - pad, hi + pad]);
        txt = labelText(W, u, p, wave);
    else
        txt = "no waveform";
    end
    hold(ax, 'off');
    styleAxes(ax, style);
    if txt ~= ""
        tagPart(text(ax, 0.03, 0.97, txt, 'Units', 'normalized', 'FontSize', max(6, style.FontSize - 2), ...
            'Color', [0.3 0.3 0.3], 'VerticalAlignment', 'top', 'Interpreter', 'none', 'Clipping', 'on'), "waveLabel");
    end
    title(ax, names(u), 'FontWeight', 'normal', 'Interpreter', 'none');
    axs(j) = ax;
end
gridLabels(tl, axs, "Time (ms)", ampLabel(W), style);
if nr * nc > 1; tileTicks(axs, style); end
h = struct('layout', tl, 'axes', axs);
end


function h = probeLayout(R, W, P, target, wave, style)
%probeLayout  Every unit's waveform as a glyph at its position on the probe.
meta = R.meta;
nU = numel(P);
[tl, ax] = renderLayout(target, 1, 1, style);
if isempty(ax); ax = nexttile(tl, 1); end
tagPart(ax, "axes");
has = cellfun(@(p) p.has, P);
ux = double(meta.x(:)); uy = double(meta.y(:));
shank = zeros(nU, 1);
if ismember("shank", string(meta.Properties.VariableNames)); shank = double(meta.shank(:)); end
placed = has & isfinite(ux) & isfinite(uy);
sx = zeros(0, 1); sy = zeros(0, 1); sk = zeros(0, 1);
pr = [];
if isfield(R, 'probe'); pr = R.probe; end
if isstruct(pr) && all(isfield(pr, {'chanMap', 'xc', 'yc'}))
    n = numel(pr.chanMap);
    sx = double(pr.xc(1:n)); sx = sx(:);
    sy = double(pr.yc(1:n)); sy = sy(:);
    sk = zeros(n, 1);
    if isfield(pr, 'kcoords'); k = double(pr.kcoords(:)); sk = k(1:n); end
end
span = max([sy; uy(placed)]) - min([sy; uy(placed)]);
if isempty(span) || ~(span > 0); span = 100; end
gh = wave.scale * max(30, span / 12);   % a glyph: this tall, 1.6 times as wide (um)
gw = 1.6 * gh;

% One axis for every shank: shift a shank sideways only where its glyphs would overlap the one before.
shanks = unique([sk; shank(placed)]).';
xoff = zeros(numel(shanks), 1);
edge = -Inf;
for j = 1:numel(shanks)
    xs = [sx(sk == shanks(j)); ux(placed & shank == shanks(j))];
    if isempty(xs); continue; end
    lo = min(xs) - gw / 2;
    if lo <= edge + gw / 4 - 1e-9
        xoff(j) = edge + gw / 4 - lo;
    end
    edge = max(xs) + gw / 2 + xoff(j);
end
shift = @(s) shankShift(s, shanks, xoff);

hold(ax, 'on');
if wave.showSites && ~isempty(sx)
    tagPart(plot(ax, sx + shift(sk), sy, 's', 'MarkerSize', 3, 'Color', [0.8 0.8 0.8]), "waveSites");
end
X0 = ux + shift(shank);
spk = cell(0, 1); mu = cell(0, 1);
common = zeros(nU, 1);
for u = find(placed).'
    p = P{u};
    [lo, hi] = valueRange(p);
    span1 = hi - lo;
    if wave.ampScale == "common"
        common(u) = commonSpan(W, P, W.units(u));
        span1 = common(u);
    end
    if ~(span1 > 0); span1 = 1; end
    tspan = max(p.t) - min(p.t);
    if ~(tspan > 0); tspan = 1; end
    gx = X0(u) + gw * ((p.t - min(p.t)) / tspan - 0.5);
    at = @(v) uy(u) + gh * (v - (lo + hi) / 2) / span1;
    if p.spikes
        k = size(p.S, 2);
        spk{end+1, 1} = [repmat([gx; NaN], k, 1), reshape([at(p.S); NaN(1, k)], [], 1)]; %#ok<AGROW>
    end
    if p.mean
        mu{end+1, 1} = [gx, at(p.m); NaN NaN]; %#ok<AGROW>
    end
end
if ~isempty(spk)
    S = vertcat(spk{:});
    tagPart(line(ax, S(:, 1), S(:, 2), 'Color', [0.30 0.45 0.75 0.25], 'LineWidth', 0.5), "waveSpikes");
end
if ~isempty(mu)
    M = vertcat(mu{:});
    tagPart(line(ax, M(:, 1), M(:, 2), 'Color', [0.80 0.10 0.10], 'LineWidth', max(1, style.LineWidth)), "waveMean");
end
fs = max(5, style.FontSize - 3);
if wave.showNames
    names = shortUnitLabels(R.labels);
    for u = find(placed).'
        txt = names(u);
        extra = labelText(W, u, P{u}, wave);
        if extra ~= ""; txt = txt + ", " + extra; end
        tagPart(text(ax, X0(u) - gw / 2, uy(u) + gh / 2, txt, 'FontSize', fs, 'Color', [0.3 0.3 0.3], ...
            'VerticalAlignment', 'bottom', 'Interpreter', 'none', 'Clipping', 'on'), "waveName");
    end
end
allX = [X0(placed); sx + shift(sk)];
allY = [uy(placed); sy];
if isempty(allX); allX = [0; 1]; allY = [0; 1]; end
if numel(shanks) > 1
    top = max(allY) + gh / 2;
    for j = 1:numel(shanks)
        xs = [sx(sk == shanks(j)); ux(placed & shank == shanks(j))] + xoff(j);
        if isempty(xs); continue; end
        tagPart(text(ax, mean([min(xs) max(xs)]), top + 0.1 * gh, sprintf('Shank %d', shanks(j)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', style.FontSize), "shankLabels");
    end
    allY = [allY; top + 1.5 * gh];
end
xlim(ax, [min(allX) - gw, max(allX) + gw]);
ylim(ax, [min(allY) - gh, max(allY) + gh]);
if wave.ampScale == "common" && any(common > 0)
    sb = scaleBar(ax, W, common, gh);
    if ~isempty(sb); tagPart(sb.line, "waveScale"); tagPart(sb.text, "waveScale"); end
end
nOff = nnz(has & ~placed);
if nOff > 0
    tagPart(text(ax, 0.01, 0.01, sprintf('%d unit(s) without a probe position not drawn', nOff), 'Units', 'normalized', ...
        'FontSize', fs, 'Color', [0.3 0.3 0.3], 'VerticalAlignment', 'bottom', 'Interpreter', 'none'), "waveLabel");
end
hold(ax, 'off');
styleAxes(ax, style);
xlabel(ax, 'x (µm)'); ylabel(ax, 'y (µm)');
h = struct('layout', tl, 'axes', ax);
end


function d = shankShift(s, shanks, xoff)
%shankShift  The sideways shift of each shank in S (none for one the panel does not draw).
d = zeros(numel(s), 1);
[tf, loc] = ismember(s(:), shanks);
d(tf) = xoff(loc(tf));
end


function b = scaleBar(ax, W, common, gh)
%scaleBar  A vertical bar at the panel's lower left, of a round amplitude, in the common scale.
b = [];
u = find(common > 0, 1);
units = W.units(u);
if any(W.units(common > 0) ~= units); return; end   % values of different kinds: no one bar
span = common(u);
e = 10 ^ floor(log10(span));
amp = e;
for m = [2 5]
    if m * e <= span; amp = m * e; end
end
xl = xlim(ax); yl = ylim(ax);
x0 = xl(1) + 0.03 * diff(xl);
y0 = yl(1) + 0.03 * diff(yl);
b = struct('line', line(ax, [x0 x0], [y0 y0 + gh * amp / span], 'Color', [0.2 0.2 0.2], 'LineWidth', 1.5), ...
    'text', text(ax, x0, y0 + gh * amp / span / 2, "  " + sprintf("%g %s", amp, unitText(units)), 'FontSize', 8, ...
    'Color', [0.2 0.2 0.2], 'VerticalAlignment', 'middle', 'Interpreter', 'none'));
end


function p = unitParts(W, u, mode)
%unitParts  What to draw for unit U: its mean, spikes and time, and which of them the mode shows.
p = struct('has', false, 'm', [], 't', [], 'S', [], 'spikes', false, 'mean', false, 'template', false);
if u > numel(W.mean) || isempty(W.mean{u}); return; end
p.has = true;
p.m = W.mean{u}(:);
p.t = W.timeMs{u}(:);
p.template = W.from(u) == "template";
p.S = W.spikes{u};
p.spikes = ismember(mode, ["subsample" "both"]) && ~isempty(p.S) && ~p.template;
p.mean = ismember(mode, ["mean" "both"]) || ~p.spikes;
if ~p.spikes; p.S = []; end
end


function [lo, hi] = valueRange(p)
%valueRange  The lowest and highest value drawn for a unit.
V = p.m;
if p.spikes; V = [p.m p.S]; end
lo = min(V(:));
hi = max(V(:));
if ~(hi > lo); lo = lo - 1; hi = hi + 1; end
end


function [lo, hi] = commonRange(W, P, units)
%commonRange  The range of every drawn unit whose values are of the kind UNITS.
lo = Inf; hi = -Inf;
for u = 1:numel(P)
    if ~P{u}.has || W.units(u) ~= units; continue; end
    [l, h] = valueRange(P{u});
    lo = min(lo, l); hi = max(hi, h);
end
end


function span = commonSpan(W, P, units)
%commonSpan  The largest peak-to-peak range of the drawn units whose values are of the kind UNITS.
span = 0;
for u = 1:numel(P)
    if ~P{u}.has || W.units(u) ~= units; continue; end
    [l, h] = valueRange(P{u});
    span = max(span, h - l);
end
end


function txt = labelText(W, u, p, wave)
%labelText  The unit's label: peak-to-peak amplitude, spike count, template.
parts = strings(1, 0);
if wave.showPP
    parts(end+1) = sprintf("%.3g %s p-p", max(p.m) - min(p.m), unitText(W.units(u)));
end
if wave.showCount && ~p.template && ~isempty(p.S)
    total = size(p.S, 2);
    if isfield(W, 'total'); total = max(W.total(u), total); end
    parts(end+1) = sprintf("%d spikes", total);
end
if p.template; parts(end+1) = "(template)"; end
txt = strjoin(parts, ", ");
end


function s = ampLabel(W)
%ampLabel  The amplitude axis' label: its unit when all the waveforms share one.
u = unique(W.units(W.units ~= ""));
if isscalar(u)
    s = "Amplitude (" + unitText(u) + ")";
else
    s = "Amplitude";
end
end


function s = unitText(units)
%unitText  The amplitude unit for a label (unitWaveforms' units).
switch units
    case "uV";       s = char(181) + "V";
    case "bin";      s = ".bin units";
    case "whitened"; s = "whitened";
    otherwise;       s = "a.u.";
end
end
