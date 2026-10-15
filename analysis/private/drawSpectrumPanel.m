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
%   "Power (<units>)" (units: µV²/Hz, spikes/s), options.yLim fixing it.
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
    units(end+1) = string(R.units); %#ok<AGROW>
    [Y, lo, hi] = chronuxScaled(R.S, R.Slo, R.Shi, scale);
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
        gl = string(R.groups.label(g));
        if multi
            styles = ["-" "--" ":" "-."];
            col = cm(c, :);
            ls = styles(mod(g - 1, 4) + 1);
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
            errorPatch(ax, f, lo(:, c, g), hi(:, c, g), col, tg, style);
        end
        h1 = tagPart(plot(ax, f, Y(:, c, g), 'Color', col, 'LineWidth', style.LineWidth, 'LineStyle', ls), role, tg);
        if isfield(R, 'rate')
            rateLine(ax, f, R.rate(c, g), scale, col, tg);
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
if scale == "log"; set(ax, 'YScale', 'log'); end
flat = style;
flat.XLim = [];
flat.YLim = o.yLim;
styleAxes(ax, flat);
xlabel(ax, "Frequency (Hz)");
u = unique(units, 'stable');
if isscalar(u)
    hk.yName = "Power (" + u + ")";
    if scale == "db"; hk.yName = "Power (dB re 1 " + u + ")"; end
else   % channels and spike trains overlaid: no one unit
    hk.yName = "Power";
    if scale == "db"; hk.yName = "Power (dB)"; end
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


function rateLine(ax, f, r, scale, color, group)
%rateLine  A spike spectrum's mean rate, where it tends at high frequencies, in the units drawn (renderChronux's rateMark).
if ~isfinite(r) || r <= 0 || numel(f) < 2; return; end
y = r;
if scale == "db"; y = 10 * log10(r); end
tagPart(plot(ax, f([1 end]), [y y], ':', 'Color', color, 'LineWidth', 1, 'HandleVisibility', 'off'), "rateLine", group);
end
