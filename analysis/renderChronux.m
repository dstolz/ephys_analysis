function h = renderChronux(R, target, opts)
%renderChronux  Draw a Chronux analysis (the analysis app's Chronux tab).
%   H = renderChronux(R, TARGET, Name=Value) draws R from chronuxSpectrum,
%   chronuxSpecgram, chronuxCoherence, chronuxSpikeSpectrum,
%   chronuxSpikeField or chronuxUnitCoherence into TARGET (an axes, uiaxes,
%   figure, uifigure, panel, tab, grid or tiled layout; never a new
%   figure), as its display settings say (chronuxSettings' display):
%     chronuxSpectrum  layout "grid": a tile per channel, the groups
%                      overlaid in their colors, each with its error bars
%                      (R.Slo / R.Shi, showErr) as a band; "overlay": a tile
%                      per group, its channels overlaid, colored from the
%                      top of the list to its end. scale "db" (10 log10),
%                      "log" (a log y axis) or "linear"
%     chronuxSpikeSpectrum  the same, a spike train in place of a channel,
%                      each marking its mean rate (what a spike spectrum
%                      tends to at high frequencies; scaled as the spectrum)
%     chronuxSpecgram  a tile per channel and group: the power over time
%                      and frequency as an image, in dB ("db" or "log"
%                      scale) or as is ("linear"); a baseline-normalized
%                      one in its own units on a diverging colormap
%                      centered on no change. One color scale for the
%                      page (clim, else from its tiles), the event at 0
%     chronuxCoherence, chronuxSpikeField, chronuxUnitCoherence
%                      layout "grid": a tile per pair, the groups overlaid,
%                      the coherence magnitude 0 to 1 with its jackknife
%                      bars (showErr) as a band and the level independent
%                      signals stay under (R.confC) as a dashed line;
%                      "overlay": a tile per group, its pairs overlaid.
%                      showPhase: a panel under each tile with the phase,
%                      -pi to pi, at the frequencies where the coherence
%                      is over that level (every frequency without one)
%     chronuxCohgram   a tile per pair and group: the coherence over time
%                      and frequency as an image, 0 to 1 (clim)
%   maxTiles tiles a page; H.pages says how many pages there are.
%
%   Everything drawn is named for the aesthetics editor (tagPart), drawn
%   in a plot design (PlotDesign) and the user's remembered looks for
%   R.kind (PlotAesthetics.userRules); in a visible figure a right-click
%   on it opens the editor.
%
%   Options
%     Display   chronuxSettings display fields ([] = R.settings.display)
%     Page      the page (default: Display.page)
%     Style     EphysAnalysisConfig Style fields (FontSize, LineWidth,
%               Grid, Legend, ShowZeroLine, the error band's look ...)
%     Design    "" (default): the user's design (PlotDesign.current; a
%               new choice redraws the plot), a design's name, or a design
%     Rules     the plot's own aesthetics rules, applied last
%     Editable  "auto" (default: in a visible figure), true or false
%
%   H: layout, axes, title, page, pages.
%
%   See also chronuxSpectrum, chronuxSpecgram, renderPlot, PlotAesthetics.
arguments
    R (1,1) struct
    target
    opts.Display = []
    opts.Page double = []
    opts.Style = struct()
    opts.Design = ""
    opts.Rules = []
    opts.Editable = "auto"
end
d = opts.Display;
if isempty(d); d = R.settings.display; end
page = opts.Page;
if isempty(page); page = d.page; end
[design, follows] = designFor(opts.Design);
st = opts.Style;
st.MaxTiles = d.maxTiles;
st.YLim = d.ylim;
st.CLim = d.clim;
st.Design = design;
style = renderStyle(st);
switch R.kind
    case {"chronuxSpectrum" "chronuxSpikeSpectrum"}
        [h, n] = drawSpectrum(R, target, d, style, page);
        mapField = "";
    case "chronuxSpecgram"
        [h, n, mapField] = drawSpecgram(R, target, d, style, page);
    case {"chronuxCoherence" "chronuxSpikeField" "chronuxUnitCoherence"}
        [h, n] = drawCoherence(R, target, d, style, page);
        mapField = "";
    case "chronuxCohgram"
        [h, n, mapField] = drawCohgram(R, target, d, style, page);
    otherwise
        error('renderChronux:BadKind', 'Unknown Chronux result "%s".', R.kind);
end
h.pages = max(1, ceil(n / d.maxTiles));
h.page = min(max(page, 1), h.pages);

txt = titleOf(R);
sub = strings(1, 0);
if isfield(R, 'dataset') && R.dataset ~= ""; sub(end+1) = R.dataset; end
sub(end+1) = R.timeBase.text;
sub(end+1) = sprintf("tapers [%.3g %d] (±%.3g Hz)", R.tapers.TW, R.tapers.K, R.tapers.halfBandwidthHz);
if h.pages > 1; sub(end+1) = sprintf("page %d of %d", h.page, h.pages); end
if ~isempty(h.layout)
    title(h.layout, txt, 'FontSize', style.FontSize + 1, 'FontWeight', 'bold', 'Interpreter', 'none');
    subtitle(h.layout, strjoin(sub, " | "), 'FontSize', style.FontSize, 'Interpreter', 'none');
elseif ~isempty(h.axes)
    title(h.axes(1), txt, 'FontSize', style.FontSize + 1, 'FontWeight', 'bold', 'Interpreter', 'none');
    subtitle(h.axes(1), strjoin(sub, " | "), 'FontSize', style.FontSize, 'Interpreter', 'none');
end
h.title = txt;

root = h.layout;
if isempty(root) && ~isempty(h.axes); root = h.axes(1); end
if isempty(root); return; end
plotRules = PlotAesthetics.normalizeRules(opts.Rules);
rules = [PlotDesign.rulesFor(design, R.kind) PlotAesthetics.userRules(R.kind) plotRules];
PlotDesign.paint(root, design);
PlotAesthetics.apply(root, rules);
if editable(opts.Editable, target)
    ctx = struct('kind', R.kind, 'id', R.kind, 'title', txt, 'root', root, 'target', target, 'plotRules', plotRules, ...
        'onRemember', {[]}, 'design', design, 'followsDesign', follows, 'ordinal', isOrdinalGroups(R.groups), ...
        'mapField', mapField, 'redraw', @(newRules) renderChronux(R, target, Display=d, Page=h.page, Style=opts.Style, ...
            Design=opts.Design, Rules=newRules, Editable=opts.Editable));
    PlotAesthetics.enableEditing(target, ctx);
end
end


function [h, n] = drawSpectrum(R, target, d, style, page)
[~, nC, nG] = size(R.S);
[Y, lo, hi] = chronuxScaled(R.S, R.Slo, R.Shi, d.scale);
showErr = d.showErr && ~isempty(lo);
f = R.f;
colors = groupPalette(R.groups, style);
h = struct('layout', [], 'axes', gobjects(0));
yl = "Power (" + R.units + ")";
if d.scale == "db"; yl = "Power (dB re 1 " + R.units + ")"; end
if d.layout == "grid"
    n = nC;
    [idx, nr, nc] = pageItems(nC, page, d.maxTiles);
    [tl, ax0] = renderLayout(target, nr, nc, style);
    if ~isempty(ax0); idx = idx(1:min(1, end)); end
    axs = gobjects(1, numel(idx));
    for j = 1:numel(idx)
        c = idx(j);
        if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
        tagPart(ax, "axes", "", R.labels(c));
        hold(ax, 'on');
        lh = gobjects(1, nG);
        for g = 1:nG
            if showErr
                errorPatch(ax, f, lo(:, c, g), hi(:, c, g), colors(g, :), R.groups.label(g), style);
            end
            lh(g) = tagPart(plot(ax, f, Y(:, c, g), 'Color', colors(g, :), 'LineWidth', style.LineWidth), ...
                "trace", R.groups.label(g));
            if isfield(R, 'rate'); rateMark(ax, f, R.rate(c, g), d.scale, colors(g, :), R.groups.label(g)); end
        end
        hold(ax, 'off');
        finishAxes(ax, f, d, style);
        ttl = R.labels(c);
        if nG == 1; ttl = ttl + sprintf(" (n = %d)", R.nTrials(c, 1)); end
        title(ax, ttl, 'FontWeight', 'normal', 'Interpreter', 'none');
        if j == 1 && style.Legend && nG > 1
            placeLegend(ax, lh, R.groups.label + " (n = " + string(R.nTrials(c, :).') + ")", style, tl, "east");
        end
        axs(j) = ax;
    end
else
    n = nG;
    [idx, nr, nc] = pageItems(nG, page, d.maxTiles);
    [tl, ax0] = renderLayout(target, nr, nc, style);
    if ~isempty(ax0); idx = idx(1:min(1, end)); end
    chColors = designColormap(style, "sequential", "parula", max(nC, 2));
    chColors = chColors(round(linspace(1, size(chColors, 1) * 0.85, nC)), :);
    axs = gobjects(1, numel(idx));
    for j = 1:numel(idx)
        g = idx(j);
        if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
        tagPart(ax, "axes", "", R.groups.label(g));
        hold(ax, 'on');
        lh = gobjects(1, nC);
        for c = 1:nC
            lh(c) = tagPart(plot(ax, f, Y(:, c, g), 'Color', chColors(c, :), 'LineWidth', style.LineWidth * 0.8), ...
                "channelTrace", R.labels(c));
            if isfield(R, 'rate'); rateMark(ax, f, R.rate(c, g), d.scale, chColors(c, :), R.labels(c)); end
        end
        hold(ax, 'off');
        finishAxes(ax, f, d, style);
        title(ax, sprintf('%s (n = %d)', R.groups.label(g), max(R.nTrials(:, g))), 'FontWeight', 'normal', 'Interpreter', 'none');
        if j == 1 && style.Legend && nC > 1 && nC <= 12
            placeLegend(ax, lh, R.labels, style, tl, "east");
        end
        axs(j) = ax;
    end
    if nC > 12 && ~isempty(axs)
        colormap(axs(end), chColors);
        cb = tagPart(colorbar(axs(end)), "colorbar");
        cb.Ticks = [0 1];
        cb.TickLabels = {char(R.labels(1)), char(R.labels(end))};
        cb.Direction = 'reverse';
    end
end
gridLabels(tl, axs, "Frequency (Hz)", yl, style);
if nr * nc > 1; tileTicks(axs, style); end
h.layout = tl;
h.axes = axs;
end


function [h, n, mapField] = drawSpecgram(R, target, d, style, page)
[~, ~, nC, nG] = size(R.S);
n = nC * nG;
normalized = R.baseline.mode ~= "none";
if normalized
    Z = R.S;
    units = R.baseline.units;
    signed = R.baseline.mode ~= "ratio";
    if R.baseline.mode == "ratio"; Z = log2(Z); units = "log2 ratio"; signed = true; end
elseif d.scale == "linear"
    Z = R.S;
    units = R.units;
    signed = false;
else
    Z = 10 * log10(R.S);
    units = "dB re 1 " + R.units;
    signed = false;
end
if signed
    mapField = "diverging";
    cmap = designColormap(style, "diverging", "blueWhiteRed");
else
    mapField = "heat";
    cmap = designColormap(style, "heat", "parula");
end
[idx, nr, nc] = pageItems(n, page, d.maxTiles);
[tl, ax0] = renderLayout(target, nr, nc, style);
if ~isempty(ax0); idx = idx(1:min(1, end)); end
cl = d.clim;
if isempty(cl)
    v = [];
    for k = idx
        [c, g] = ind2sub([nC nG], k);
        x = Z(:, :, c, g);
        v = [v; x(isfinite(x))]; %#ok<AGROW>
    end
    cl = chronuxAutoLimits(v, signed);
end
axs = gobjects(1, numel(idx));
for j = 1:numel(idx)
    [c, g] = ind2sub([nC nG], idx(j));
    if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
    name = R.labels(c);
    if nG > 1; name = name + " | " + R.groups.label(g); end
    tagPart(ax, "axes", "", name);
    x = Z(:, :, c, g).';
    tagPart(imagesc(ax, R.t, R.f, x, 'AlphaData', double(isfinite(x))), "image", name);
    set(ax, 'YDir', 'normal', 'CLim', cl, 'Layer', 'top');
    colormap(ax, cmap);
    if R.aligned && style.ShowZeroLine
        tagPart(xline(ax, 0, ':', 'Color', [0.2 0.2 0.2], 'LineWidth', 1, 'HandleVisibility', 'off'), "zeroLine");
    end
    axis(ax, 'tight');
    ax.FontSize = style.FontSize;
    box(ax, 'on');
    ttl = name;
    if R.aligned; ttl = ttl + sprintf(" (n = %d)", R.nTrials(c, g)); end
    title(ax, ttl, 'FontWeight', 'normal', 'Interpreter', 'none');
    axs(j) = ax;
end
if ~isempty(axs)
    cb = tagPart(colorbar(axs(end)), "colorbar");
    cb.Label.String = units;
    if ~isempty(tl) && numel(axs) > 1; cb.Layout.Tile = 'east'; end
end
xl = "Time (s)";
if R.aligned; xl = "Time from the event (s)"; end
gridLabels(tl, axs, xl, "Frequency (Hz)", style);
if nr * nc > 1; tileTicks(axs, style); end
h = struct('layout', tl, 'axes', axs);
end


function [h, n] = drawCoherence(R, target, d, style, page)
%drawCoherence  Coherence of pairs (channels, spike-field, unit-unit): magnitude and, under it, phase.
[~, nP, nG] = size(R.C);
f = R.f;
colors = groupPalette(R.groups, style);
showErr = d.showErr && ~isempty(R.Clo);
byPair = d.layout == "grid";
if byPair; n = nP; else; n = nG; end
[idx, nr, nc] = pageItems(n, page, d.maxTiles);
[tl, ax0] = renderLayout(target, nr, nc, style);
if ~isempty(ax0); idx = idx(1:min(1, end)); end
withPhase = d.showPhase && isempty(ax0);
if ~byPair
    pairColors = designColormap(style, "sequential", "parula", max(nP, 2));
    pairColors = pairColors(round(linspace(1, size(pairColors, 1) * 0.85, nP)), :);
end
phaseStyle = style;
phaseStyle.YLim = zeros(1, 0);
axs = gobjects(1, numel(idx));
pax = gobjects(1, numel(idx) * withPhase);
for j = 1:numel(idx)
    [ax, px] = coherencePanels(tl, ax0, j, withPhase);
    hold(ax, 'on');
    if byPair
        p = idx(j);
        name = R.pairs.label(p);
        tagPart(ax, "axes", "", name);
        lh = gobjects(1, nG);
        for g = 1:nG
            lab = R.groups.label(g);
            if showErr
                errorPatch(ax, f, R.Clo(:, p, g), R.Chi(:, p, g), colors(g, :), lab, style);
            end
            lh(g) = tagPart(plot(ax, f, R.C(:, p, g), 'Color', colors(g, :), 'LineWidth', style.LineWidth), "trace", lab);
            confMark(ax, f, R.confC(p, g), colors(g, :), lab);
            if ~isempty(px); phaseMark(px, f, R.phi(:, p, g), R.C(:, p, g), R.confC(p, g), colors(g, :), lab); end
        end
        ttl = name;
        if nG == 1; ttl = ttl + sprintf(" (n = %d)", R.nTrials(p, 1)); end
        if j == 1 && style.Legend && nG > 1
            placeLegend(ax, lh, R.groups.label + " (n = " + string(R.nTrials(p, :).') + ")", style, tl, "east");
        end
    else
        g = idx(j);
        name = R.groups.label(g);
        tagPart(ax, "axes", "", name);
        lh = gobjects(1, nP);
        for p = 1:nP
            lab = R.pairs.label(p);
            lh(p) = tagPart(plot(ax, f, R.C(:, p, g), 'Color', pairColors(p, :), 'LineWidth', style.LineWidth * 0.8), ...
                "channelTrace", lab);
            confMark(ax, f, R.confC(p, g), pairColors(p, :), lab);
            if ~isempty(px); phaseMark(px, f, R.phi(:, p, g), R.C(:, p, g), R.confC(p, g), pairColors(p, :), lab); end
        end
        ttl = sprintf('%s (n = %d)', name, max(R.nTrials(:, g)));
        if j == 1 && style.Legend && nP > 1 && nP <= 12
            placeLegend(ax, lh, R.pairs.label, style, tl, "east");
        end
    end
    hold(ax, 'off');
    if numel(f) > 1; xlim(ax, f([1 end])); end
    ylim(ax, [0 1]);
    styleAxes(ax, style);
    title(ax, ttl, 'FontWeight', 'normal', 'Interpreter', 'none');
    axs(j) = ax;
    if ~isempty(px)
        tagPart(px, "axes", "", name);
        if numel(f) > 1; xlim(px, f([1 end])); end
        ylim(px, [-pi pi]);
        set(px, 'YTick', [-pi 0 pi], 'YTickLabel', {['-' char(960)], '0', char(960)});
        styleAxes(px, phaseStyle);
        ylabel(px, 'Phase (rad)', 'Interpreter', 'none', 'FontSize', style.FontSize);
        set(ax, 'XTickLabel', []);
        pax(j) = px;
    end
end
gridLabels(tl, axs, "Frequency (Hz)", "Coherence", style);
if nr * nc > 1; tileTicks([axs pax], style); end
h = struct('layout', tl, 'axes', axs, 'phaseAxes', pax);
end


function [ax, px] = coherencePanels(tl, ax0, j, withPhase)
%coherencePanels  The axes of tile J: the magnitude and, under it, flush on one frequency axis, the phase.
px = gobjects(0);
if ~isempty(ax0); ax = ax0; return; end
if ~withPhase
    ax = nexttile(tl, j);
    return
end
pair = tiledlayout(tl, 3, 1, 'TileSpacing', 'none', 'Padding', 'tight');
pair.Layout.Tile = j;
ax = nexttile(pair, 1, [2 1]);
px = nexttile(pair, 3);
hold(px, 'on');
end


function confMark(ax, f, c, color, group)
%confMark  The coherence independent signals stay under (R.confC), a dashed line.
if ~isfinite(c) || numel(f) < 2; return; end
tagPart(plot(ax, f([1 end]), [c c], '--', 'Color', color, 'LineWidth', 1, 'HandleVisibility', 'off'), "confLine", group);
end


function phaseMark(px, f, phi, C, c, color, group)
%phaseMark  The phase where the coherence is over its confidence level (everywhere without one), as points.
y = double(phi(:));
if isfinite(c); y(~(C(:) > c)) = NaN; end
tagPart(plot(px, f, y, '.', 'Color', color, 'MarkerSize', 6, 'HandleVisibility', 'off'), "phase", group);
end


function rateMark(ax, f, r, scale, color, group)
%rateMark  A spike spectrum's mean rate, where it tends at high frequencies, in the units drawn.
if ~isfinite(r) || r <= 0 || numel(f) < 2; return; end
y = r;
if scale == "db"; y = 10 * log10(r); end
tagPart(plot(ax, f([1 end]), [y y], ':', 'Color', color, 'LineWidth', 1, 'HandleVisibility', 'off'), "rateLine", group);
end


function [h, n, mapField] = drawCohgram(R, target, d, style, page)
%drawCohgram  A tile per pair and group: the coherence over time and frequency, 0 to 1.
[~, ~, nP, nG] = size(R.C);
n = nP * nG;
mapField = "heat";
cmap = designColormap(style, "heat", "parula");
[idx, nr, nc] = pageItems(n, page, d.maxTiles);
[tl, ax0] = renderLayout(target, nr, nc, style);
if ~isempty(ax0); idx = idx(1:min(1, end)); end
cl = d.clim;
if isempty(cl); cl = [0 1]; end
axs = gobjects(1, numel(idx));
for j = 1:numel(idx)
    [p, g] = ind2sub([nP nG], idx(j));
    if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
    name = R.pairs.label(p);
    if nG > 1; name = name + " | " + R.groups.label(g); end
    tagPart(ax, "axes", "", name);
    x = R.C(:, :, p, g).';
    tagPart(imagesc(ax, R.t, R.f, x, 'AlphaData', double(isfinite(x))), "image", name);
    set(ax, 'YDir', 'normal', 'CLim', cl, 'Layer', 'top');
    colormap(ax, cmap);
    if R.aligned && style.ShowZeroLine
        tagPart(xline(ax, 0, ':', 'Color', [0.2 0.2 0.2], 'LineWidth', 1, 'HandleVisibility', 'off'), "zeroLine");
    end
    axis(ax, 'tight');
    ax.FontSize = style.FontSize;
    box(ax, 'on');
    ttl = name;
    if R.aligned; ttl = ttl + sprintf(" (n = %d)", R.nTrials(p, g)); end
    title(ax, ttl, 'FontWeight', 'normal', 'Interpreter', 'none');
    axs(j) = ax;
end
if ~isempty(axs)
    cb = tagPart(colorbar(axs(end)), "colorbar");
    cb.Label.String = "Coherence";
    if ~isempty(tl) && numel(axs) > 1; cb.Layout.Tile = 'east'; end
end
xl = "Time (s)";
if R.aligned; xl = "Time from the event (s)"; end
gridLabels(tl, axs, xl, "Frequency (Hz)", style);
if nr * nc > 1; tileTicks(axs, style); end
h = struct('layout', tl, 'axes', axs);
end


function finishAxes(ax, f, d, style)
if numel(f) > 1; xlim(ax, f([1 end])); end
if d.scale == "log"; set(ax, 'YScale', 'log'); end
styleAxes(ax, style);
end


function t = titleOf(R)
switch R.kind
    case "chronuxSpectrum", what = "Power spectrum";
    case "chronuxSpecgram", what = "Spectrogram";
    case "chronuxCoherence", what = "Coherence";
    case "chronuxCohgram", what = "Coherogram";
    case "chronuxSpikeSpectrum", what = "Spike spectrum";
    case "chronuxSpikeField", what = "Spike-field coherence";
    case "chronuxUnitCoherence", what = "Unit-unit coherence";
end
if isfield(R, 'signal')
    of = string(R.signal);
else
    of = string(R.source);   % a unit-unit coherence: the trains' source
end
t = what + ": " + of + ", " + R.timeBase.label;
end


function [D, follows] = designFor(design)
follows = false;
if isstruct(design)
    D = design;
elseif string(design) ~= ""
    D = PlotDesign.load(string(design));
else
    D = PlotDesign.current();
    follows = true;
end
end


function tf = editable(mode, target)
if isstring(mode) || ischar(mode)
    fig = ancestor(target, 'figure');
    tf = ~isempty(fig) && strcmp(fig.Visible, 'on');
else
    tf = logical(mode);
end
end
