function hk = drawSpectrumPanel(ax, P, look)
%drawSpectrumPanel  Draw a figure's power spectrum panel: each layer's spectra per trial group, overlaid.
%   HK = drawSpectrumPanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure) into the axes AX,
%   as renderFigure asks (LOOK: style, colors, W, spec, panel, panelId,
%   isTop, isBottom, epochs, groups, observation, isTime). Each computed
%   layer (chronuxSpectrum or chronuxSpikeSpectrum: computeSpectrumPanel)
%   gives its items, its channels or units. Every item and trial group is
%     a band    the error bars (R.Slo / R.Shi, options.err not "none"),
%               errorPatch, role "sem"
%     a trace   the power in options.scale (chronuxScaled: "db" 10 log10,
%               "log" a log y axis, "linear"), role "trace"
%     a line    a spike spectrum's mean rate, dotted (what it tends to at
%               high frequencies), role "rateLine"
%   A layer of one item draws it in the group's color (or the layer's) and
%   its line style (the layer's lineStyle, else by order, as a PSTH panel
%   does); a layer of several items (a fixed multi-channel layer) colors
%   them along the design's sequential colormap (role "channelTrace"), its
%   trial groups by line style. The components' group is the trial
%   group's label, with several items "<item> · <group>". x: "Frequency
%   (Hz)" over the frequencies computed; y: "Power (dB re 1 <units>)" or
%   "Power (<units>)" (units: µV²/Hz, spikes/s), options.yLimMode setting
%   it (panelYLimits: "fixed" at options.yLim, "batch" at the run's range,
%   else from the data).
%   options.stack "groups" draws a row per trial group instead, the first
%   on top (as a raster lists them), every item overlaid in each row (a
%   layer of several items keeps its colormap, all solid), in the rows of
%   stackLayout (the row step options.stackSpacing x the row height, the
%   tallest row's reach of spectra and bands; each row on its own scale
%   with options.yLimMode "auto", else one: stackYName), a gray line
%   along each row (stackBaseLines), the rows named by the groups' values
%   on the left y axis and each row's top on the right (stackAxes); y label
%   "<groups' parameters> (<height> dB per row)". A log axis holds no
%   offset rows: scale "log" draws log10 of the power in a stack.
%   Skipped layers are noted (figLayerNotes). The legend offers the groups
%   (from a one-item layer), then the items when there are several.
%
%   See also renderFigure, renderChronux, computeSpectrumPanel, figurePanelRegistry.
style = look.style;
o = look.panel.options;
Ls = look.panel.layers;
hk = figDrawResult(ax);
tagPart(ax, "axes", "", look.panelId);

items = zeros(0, 2);   % [layer, item of R.S]
for j = 1:numel(P.layers)
    R = P.layers(j).R;
    if P.layers(j).skip ~= "" || ~isSpectrum(R); continue; end
    n = size(R.S, 2);
    items = [items; repmat(j, n, 1) (1:n).']; %#ok<AGROW>
end
nI = size(items, 1);
if nI == 0
    figLayerNotes(ax, P, look, false);
    return
end
scale = string(o.scale);
stacked = isfield(o, 'stack') && o.stack == "groups";
logRows = stacked && scale == "log";   % a log axis holds no offset rows: the stack draws log10 of the power
% each item's spectra in the scale drawn, and each row's reach (a stack's: a row per trial group)
Yc = cell(1, nI); loc = cell(1, nI); hic = cell(1, nI);
nGmax = 0;
for i = 1:nI
    R = P.layers(items(i, 1)).R;
    [Yc{i}, loc{i}, hic{i}] = chronuxScaled(R.S, R.Slo, R.Shi, scale);
    if logRows
        Yc{i} = log10(max(Yc{i}, realmin));
        if ~isempty(loc{i}); loc{i} = log10(max(loc{i}, realmin)); hic{i} = log10(max(hic{i}, realmin)); end
    end
    nGmax = max(nGmax, size(R.S, 3));
end
L = [];
rowNames = strings(1, 0);
groupsName = "Group";
if stacked
    [rowNames, groupsName] = rowLabels(P.layers(items(1, 1)).R);
    rowNames = reshape(string(rowNames), 1, []);
    rowNames(end+1:nGmax) = "";
    rowNames = rowNames(1:nGmax);
    rlo = NaN(1, nGmax);
    rhi = NaN(1, nGmax);
    for i = 1:nI
        c = items(i, 2);
        bandI = o.err ~= "none" && ~isempty(loc{i});
        for g = 1:size(Yc{i}, 3)
            v = Yc{i}(:, c, g);
            if bandI; v = [v; loc{i}(:, c, g); hic{i}(:, c, g)]; end %#ok<AGROW>
            v = double(v(isfinite(v)));
            if isempty(v); continue; end
            rlo(g) = min([rlo(g); v]);
            rhi(g) = max([rhi(g); v]);
        end
    end
    [ymode, ylimits] = panelYLimits(look);
    L = stackLayout(rlo, rhi, o.stackSpacing, Mode=ymode, Limits=ylimits);
    hk.yExtent = [min(rlo) max(rhi)];
end
hold(ax, 'on');
f = [];
units = strings(1, 0);
names = strings(1, nI);
legendLook = cell(nI, 2);   % each item's legend color and line style
for i = 1:nI
    j = items(i, 1);
    c = items(i, 2);
    R = P.layers(j).R;
    f = R.f;
    if stacked && i == 1; stackBaseLines(ax, double(f([1 end])), L, rowNames); end
    units(end+1) = string(R.units); %#ok<AGROW>
    Y = Yc{i}; lo = loc{i}; hi = hic{i};
    band = o.err ~= "none" && ~isempty(lo);
    nG = size(R.S, 3);
    nC = size(R.S, 2);
    colors = look.colors;
    if size(colors, 1) ~= height(R.groups); colors = groupPalette(R.groups, style); end
    names(i) = itemName(P.layers(j), R, c);
    multi = nC > 1;   % a layer of several items: a colormap over them, the groups by line style
    if multi
        cm = designColormap(style, "sequential", "parula", max(nC, 2));
        cm = cm(round(linspace(1, size(cm, 1) * 0.85, nC)), :);
    end
    for g = 1:nG
        off = 0; k = 1;
        if stacked; off = L.offset(g); k = L.scale(g); end
        gl = string(R.groups.label(g));
        if multi
            styles = ["-" "--" ":" "-."];
            col = cm(c, :);
            ls = styles(mod(g - 1, 4) + 1);
            if stacked; ls = "-"; end   % a row per group: the groups need no line style
            role = "channelTrace";
        else
            [col, ls] = figLayerLook(Ls(j), i, colors(g, :));
            role = "trace";
        end
        tg = gl;
        if nI > 1
            tg = names(i);
            if nG > 1; tg = names(i) + " · " + gl; end
        end
        if band
            stackMark(errorPatch(ax, f, k * lo(:, c, g) + off, k * hi(:, c, g) + off, col, tg, style), off, k);
        end
        h1 = stackMark(tagPart(plot(ax, f, k * Y(:, c, g) + off, 'Color', col, 'LineWidth', style.LineWidth, 'LineStyle', ls), role, tg), off, k);
        if isfield(R, 'rate')
            rateLine(ax, f, R.rate(c, g), scale, col, tg, off, k, logRows);
        end
        if g == 1; legendLook(i, :) = {col, ls}; end
        if ~multi && i == firstSingle(items, P) && nG > 1
            hk.legendHandles(end+1) = h1;
            hk.legendLabels(end+1) = gl;
            hk.legendGroup(end+1) = true;
        end
    end
end
hold(ax, 'off');
if nI > 1   % the items, by their color and line style
    for i = 1:nI
        role = "trace";
        if size(P.layers(items(i, 1)).R.S, 2) > 1; role = "channelTrace"; end
        hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'Color', legendLook{i, 1}, 'LineStyle', legendLook{i, 2}, ...
            'LineWidth', style.LineWidth), role, names(i));
        hk.legendLabels(end+1) = names(i);
        hk.legendGroup(end+1) = false;
    end
end
if numel(f) > 1; xlim(ax, double(f([1 end]).')); end
if scale == "log" && ~stacked; set(ax, 'YScale', 'log'); end
flat = style;
flat.XLim = [];
[~, flat.YLim] = panelYLimits(look);
if stacked; flat.YLim = []; end
styleAxes(ax, flat);
xlabel(ax, "Frequency (Hz)");
u = unique(units, 'stable');
uTxt = "";   % the power's unit as drawn
if isscalar(u)
    uTxt = u;
    if scale == "db"; uTxt = "dB re 1 " + u; end
    if logRows; uTxt = "log10 " + u; end
    hk.yName = "Power (" + uTxt + ")";
else   % channels and spike trains overlaid: no one unit
    hk.yName = "Power";
    if scale == "db"; uTxt = "dB"; hk.yName = "Power (dB)"; end
    if logRows; uTxt = "log10"; hk.yName = "Power (log10)"; end
end
if stacked
    rightName = "Row top";
    if uTxt ~= ""; rightName = "Row top (" + uTxt + ")"; end
    stackAxes(ax, L, rowNames, rightName);
    hk.yName = stackYName(groupsName, L, uTxt);
end
figLayerNotes(ax, P, look, true);
end


function tf = isSpectrum(R)
%isSpectrum  A computed power spectrum (of a signal or of spike trains).
tf = isstruct(R) && isfield(R, 'kind') && ismember(R.kind, ["chronuxSpectrum" "chronuxSpikeSpectrum"]);
end


function i = firstSingle(items, P)
%firstSingle  The first item of a one-item layer (it offers the trial groups to the legend); 0 when none.
i = 0;
for k = 1:size(items, 1)
    if size(P.layers(items(k, 1)).R.S, 2) == 1
        i = k;
        return
    end
end
end


function name = itemName(lay, R, c)
%itemName  One item of a layer: the layer's name when it holds one item, else the item's own name.
name = lay.name;
if size(R.S, 2) == 1 && name ~= ""; return; end
if isfield(R, 'names') && numel(R.names) >= c
    name = string(R.names(c));
else
    name = string(R.labels(c));
end
end


function rateLine(ax, f, r, scale, color, group, off, k, logRows)
%rateLine  A spike spectrum's mean rate, where it tends at high frequencies, in the units drawn (renderChronux's rateMark).
%   In a stack's row: x K + OFF (LOGROWS: the row draws log10 of the power).
if ~isfinite(r) || r <= 0 || numel(f) < 2; return; end
y = r;
if scale == "db"; y = 10 * log10(r); end
if logRows; y = log10(r); end
y = k * y + off;
tagPart(plot(ax, f([1 end]), [y y], ':', 'Color', color, 'LineWidth', 1, 'HandleVisibility', 'off'), "rateLine", group);
end
