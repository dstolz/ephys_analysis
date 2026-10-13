function h = renderChronux(R, target, opts)
%renderChronux  Draw a Chronux analysis (the analysis app's Chronux tab).
%   H = renderChronux(R, TARGET, Name=Value) draws R from chronuxSpectrum
%   or chronuxSpecgram into TARGET (an axes, uiaxes, figure, uifigure,
%   panel, tab, grid or tiled layout; never a new figure), as its
%   display settings say (chronuxSettings' display):
%     chronuxSpectrum  layout "grid": a tile per channel, the groups
%                      overlaid in their colors, each with its error bars
%                      (R.Slo / R.Shi, showErr) as a band; "overlay": a tile
%                      per group, its channels overlaid, colored from the
%                      top of the list to its end. scale "db" (10 log10),
%                      "log" (a log y axis) or "linear"
%     chronuxSpecgram  a tile per channel and group: the power over time
%                      and frequency as an image, in dB ("db" or "log"
%                      scale) or as is ("linear"); a baseline-normalized
%                      one in its own units on a diverging colormap
%                      centered on no change. One color scale for the
%                      page (clim, else from its tiles), the event at 0
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
    case "chronuxSpectrum"
        [h, n] = drawSpectrum(R, target, d, style, page);
        mapField = "";
    case "chronuxSpecgram"
        [h, n, mapField] = drawSpecgram(R, target, d, style, page);
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
[Y, lo, hi] = scaled(R.S, R.Slo, R.Shi, d.scale);
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
    cl = autoLimits(v, signed);
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


function finishAxes(ax, f, d, style)
if numel(f) > 1; xlim(ax, f([1 end])); end
if d.scale == "log"; set(ax, 'YScale', 'log'); end
styleAxes(ax, style);
end


function [Y, lo, hi] = scaled(S, lo, hi, scale)
Y = S;
if scale == "db"
    Y = 10 * log10(S);
    if ~isempty(lo); lo = 10 * log10(max(lo, realmin)); hi = 10 * log10(hi); end
end
end


function cl = autoLimits(v, signed)
if isempty(v); cl = [0 1]; return; end
v = sort(v);
lo = v(max(1, ceil(0.01 * numel(v))));
hi = v(max(1, ceil(0.99 * numel(v))));
if signed
    m = max(abs([lo hi]));
    if ~(m > 0); m = 1; end
    cl = [-m m];
elseif hi > lo
    cl = [lo hi];
else
    cl = lo + [-0.5 0.5];
end
end


function t = titleOf(R)
switch R.kind
    case "chronuxSpectrum", what = "Power spectrum";
    case "chronuxSpecgram", what = "Spectrogram";
end
t = what + ": " + R.signal + ", " + R.timeBase.label;
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
