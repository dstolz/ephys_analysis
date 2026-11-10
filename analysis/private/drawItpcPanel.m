function hk = drawItpcPanel(ax, P, look)
%drawItpcPanel  Draw a figure's phase coherence panel: the inter-trial phase coherence (ITPC) by frequency, or over time and frequency.
%   HK = drawItpcPanel(AX, P, LOOK) draws the panel result P (F.panels(k)
%   of EphysAnalysisRunner.computeFigure) into the axes AX, as renderFigure
%   asks (LOOK: style, colors, W, spec, panel, panelId, epochs, groups,
%   observation, isTime). Its layer's R (phaseCoherence:
%   computeItpcPanel) is drawn
%     by frequency (options.overTime false)   per channel and trial group:
%       a band    the jackknife bars (R.Clo / R.Chi), errorPatch, role "sem"
%                 (in options.band's look)
%       a trace   the ITPC, 0 to 1 (options.yLimMode "fixed": options.yLim;
%                 "batch": the run's range), role "trace"; several channels:
%                 colored along the design's sequential colormap (role
%                 "channelTrace"), the trial groups by line style
%       a line    the level random phases stay under (R.confC), dashed,
%                 role "confLine"
%       in the group's color (or the layer's color and line style).
%       options.stack "groups" draws a row per trial group instead, the
%       first on top, every channel overlaid in each (stackLayout,
%       stackBaseLines, stackAxes; each row on its own scale with yLimMode
%       "auto", else one), as a coherence panel stacks. x: "Frequency
%       (Hz)", y "ITPC". HK.yExtent: a stack's reach.
%     over time (options.overTime true)   an image of the first channel's
%       ITPC over time from the event (x, the panel's window: it shares
%       the figure's time axis) and frequency (y) for the trial group
%       options.group, 0 to 1 (options.cLim) in the design's heat colormap,
%       with a color bar ("ITPC"; inside the axes at their right edge when
%       another time panel shares the column) and the event's line
%       (Style.ShowZeroLine); options.stack "groups" draws every group as
%       an image row (drawImageStack: the first on top, its color strip at
%       the left, one color scale and color bar), the groups offered to the
%       legend. y: "Frequency (Hz)" (a stack: "<groups' parameters>
%       (<f1>-<f2> Hz per row)").
%   options.freqScale "log" draws the frequency axis logarithmic: by
%   frequency a log x axis, over time the image on rows evenly spaced in
%   log10 Hz (logFrequencyRows, logFrequencyTicks), as a spectrogram's.
%   Skipped layers are noted (figLayerNotes). The legend offers the groups,
%   then the channels when there are several.
%
%   See also renderFigure, computeItpcPanel, phaseCoherence, drawCoherencePanel,
%   drawSpectrogramPanel, figurePanelRegistry.
hk = figDrawResult(ax);
j = find(arrayfun(@(l) l.skip == "" && isstruct(l.R) && isfield(l.R, 'kind') && l.R.kind == "phaseCoherence", P.layers), 1);
if isempty(j)
    tagPart(ax, "axes", "", look.panelId);
    figLayerNotes(ax, P, look, false);
    return
end
if P.layers(j).R.overTime
    hk = drawOverTime(ax, P, look, j, hk);
else
    hk = drawByFrequency(ax, P, look, j, hk);
end
end


function hk = drawByFrequency(ax, P, look, j, hk)
%drawByFrequency  Each channel's ITPC by frequency per trial group: a band, a trace and the level of random phases.
style = look.style;
o = look.panel.options;
Ls = look.panel.layers;
R = P.layers(j).R;
[~, nP, nG] = size(R.C);
f = R.f;
names = reshape(string(R.names), 1, []);
colors = look.colors;
if size(colors, 1) ~= height(R.groups); colors = groupPalette(R.groups, style); end
band = ~isempty(R.Clo);
tagPart(ax, "axes", "", look.panelId);
if nP > 1
    cm = designColormap(style, "sequential", "parula", max(nP, 2));
    cm = cm(round(linspace(1, size(cm, 1) * 0.85, nP)), :);
end
styles = ["-" "--" ":" "-."];
stacked = isfield(o, 'stack') && o.stack == "groups";   % a row per trial group, the channels overlaid in it
L = [];
rowNames = strings(1, 0);
groupsName = "Group";
if stacked
    [rowNames, groupsName] = rowLabels(R);
    rowNames = reshape(string(rowNames(1:nG)), 1, []);
    rlo = NaN(1, nG);
    rhi = NaN(1, nG);
    for g = 1:nG
        v = reshape(R.C(:, :, g), [], 1);
        if band; v = [v; reshape(R.Clo(:, :, g), [], 1); reshape(R.Chi(:, :, g), [], 1)]; end %#ok<AGROW>
        v = double(v(isfinite(v)));
        if ~isempty(v); rlo(g) = min(v); rhi(g) = max(v); end
    end
    [ymode, ylimits] = panelYLimits(look);
    L = stackLayout(rlo, rhi, o.stackSpacing, Mode=ymode, Limits=ylimits);
    hk.yExtent = [min(rlo) max(rhi)];
end
hold(ax, 'on');
if stacked; stackBaseLines(ax, double(f([1 end])), L, rowNames); end
legendLook = cell(nP, 2);
for p = 1:nP
    name = names(min(p, numel(names)));
    for g = 1:nG
        off = 0; k = 1;
        if stacked; off = L.offset(g); k = L.scale(g); end
        gl = string(R.groups.label(g));
        if nP > 1
            col = cm(p, :);
            ls = styles(mod(g - 1, 4) + 1);
            if stacked; ls = "-"; end   % a row per group: the groups need no line style
            role = "channelTrace";
            tg = name;
            if nG > 1; tg = name + " · " + gl; end
        else
            [col, ls] = figLayerLook(Ls(j), 1, colors(g, :));
            role = "trace";
            tg = gl;
        end
        if band
            stackMark(errorPatch(ax, f, k * R.Clo(:, p, g) + off, k * R.Chi(:, p, g) + off, col, tg, style, "sem", o.band), off, k);
        end
        h1 = stackMark(tagPart(plot(ax, f, k * R.C(:, p, g) + off, 'Color', col, 'LineWidth', style.LineWidth, ...
            'LineStyle', ls), role, tg), off, k);
        c = R.confC(p, g);
        if isfinite(c) && numel(f) > 1
            tagPart(plot(ax, f([1 end]), k * [c c] + off, '--', 'Color', col, 'LineWidth', 1, 'HandleVisibility', 'off'), "confLine", tg);
        end
        if g == 1; legendLook(p, :) = {col, ls}; end
        if nP == 1 && nG > 1
            hk.legendHandles(end+1) = h1;
            hk.legendLabels(end+1) = gl;
            hk.legendGroup(end+1) = true;
        end
    end
end
hold(ax, 'off');
if nP > 1   % the channels, by color
    for p = 1:nP
        name = names(min(p, numel(names)));
        hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'Color', legendLook{p, 1}, 'LineStyle', legendLook{p, 2}, ...
            'LineWidth', style.LineWidth), "channelTrace", name);
        hk.legendLabels(end+1) = name;
        hk.legendGroup(end+1) = false;
    end
elseif nG == 1   % one channel, one group: the channel names the trace
    name = names(1);
    hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'Color', legendLook{1, 1}, 'LineStyle', legendLook{1, 2}, ...
        'LineWidth', style.LineWidth), "trace", name);
    hk.legendLabels(end+1) = name;
    hk.legendGroup(end+1) = false;
end
flat = style;
flat.XLim = [];
[~, yl] = panelYLimits(look);
flat.YLim = yl;
if stacked; flat.YLim = []; end
styleAxes(ax, flat);
if isempty(yl) && ~stacked; ylim(ax, [0 1]); end
if numel(f) > 1; xlim(ax, double(f([1 end]).')); end
if isfield(o, 'freqScale') && o.freqScale == "log"; set(ax, 'XScale', 'log'); end   % (f > 0: phaseCoherence leaves 0 Hz out)
hk.yName = "ITPC";
if stacked
    stackAxes(ax, L, rowNames, "Row top (ITPC)");
    hk.yName = stackYName(groupsName, L, "ITPC");
end
xlabel(ax, "Frequency (Hz)");
hk.axes = ax;
figLayerNotes(ax, P, look, true);
end


function hk = drawOverTime(ax, P, look, j, hk)
%drawOverTime  The first channel's ITPC over time and frequency, one trial group (or every group, stacked).
style = look.style;
o = look.panel.options;
R = P.layers(j).R;
nG = size(R.C, 4);
g = min(max(1, round(o.group)), nG);
stacked = isfield(o, 'stack') && o.stack == "groups";   % every group: an image row each, the first on top
gs = g;
if stacked; gs = 1:nG; end
name = string(R.names(1));
Z = permute(R.C(:, :, 1, gs), [2 1 4 3]);   % [nF x nT x groups drawn]
f = reshape(double(R.f), [], 1);
fIn = f;
logF = isfield(o, 'freqScale') && o.freqScale == "log";
fRow = f;
if logF; [f, Z, fRow] = logFrequencyRows(f, Z); end   % rows evenly spaced in log10 Hz, on a y axis of log10 Hz
if stacked
    colors = look.colors;
    if size(colors, 1) ~= nG; colors = groupPalette(R.groups, style); end
    [rowNames, gName] = rowLabels(R);
    rowNames = reshape(string(rowNames), 1, []);
    [~, hLeg] = drawImageStack(ax, R.t, f, Z, rowNames(1:nG), colors, o.stackSpacing);
    for q = 1:nG
        hk.legendHandles(end+1) = hLeg(q);
        hk.legendLabels(end+1) = string(R.groups.label(q));
        hk.legendGroup(end+1) = true;
    end
else
    hIm = tagPart(imagesc(ax, R.t, f, Z, 'AlphaData', double(isfinite(Z))), "image", name);
    if logF; setappdata(hIm, 'RowLabels', compose("%.3g Hz", fRow)); end   % (the data tips: a row's frequency)
end
tagPart(ax, "axes", "", look.panelId);   % after imagesc, which resets a replaced axes' properties
set(ax, 'YDir', 'normal', 'Layer', 'top');
colormap(ax, designColormap(style, "heat", "parula"));
cl = o.cLim;
if ~(numel(cl) == 2 && cl(2) > cl(1)); cl = [0 1]; end
clim(ax, cl);
if style.ShowZeroLine
    hold(ax, 'on');
    tagPart(xline(ax, 0, ':', 'Color', [0.2 0.2 0.2], 'LineWidth', 1, 'HandleVisibility', 'off'), "zeroLine");
    hold(ax, 'off');
end
st = style;
st.XLim = [];
st.YLim = [];
st.CLim = [];
styleAxes(ax, st);
grid(ax, 'off');
W = look.W;
if numel(W) == 2 && W(2) > W(1)
    xlim(ax, W);
elseif numel(R.t) > 1
    xlim(ax, double(R.t([1 end]).'));
end
if ~stacked && logF
    if numel(fIn) > 1; ylim(ax, log10(reshape(fIn([1 end]), 1, 2))); end
    logFrequencyTicks(ax);
elseif ~stacked && numel(fIn) > 1
    ylim(ax, fIn([1 end]).');
end
cb = tagPart(colorbar(ax), "colorbar");
cb.Label.String = "ITPC";
if look.panel.sharesTime && inTimeColumn(look)
    cb.Location = 'east';   % beside the axes it would narrow them, out of line with the time panels above and below
end
ttl = name;
if nG > 1 && ~stacked; ttl = sprintf('%s · %s (n = %d)', name, string(R.groups.label(g)), R.nTrials(1, g)); end
title(ax, ttl, 'FontWeight', 'normal', 'Interpreter', 'none');
figLayerNotes(ax, P, look, true);
hk.axes = ax;
hk.yName = "Frequency (Hz)";
if stacked && logF
    hk.yName = sprintf("%s (%.3g-%.3g Hz per row, log scale)", gName, fIn(1), fIn(end));
elseif stacked
    hk.yName = sprintf("%s (%.3g-%.3g Hz per row)", gName, fIn(1), fIn(end));
end
end
