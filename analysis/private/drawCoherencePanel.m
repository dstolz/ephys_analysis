function hk = drawCoherencePanel(ax, P, look)
%drawCoherencePanel  Draw a figure's coherence panel: each pair's coherence per trial group, its phase under it.
%   HK = drawCoherencePanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure) into the axes AX,
%   as renderFigure asks (LOOK: style, colors, W, spec, panel, panelId,
%   isTop, isBottom, epochs, groups, observation, isTime). The seed layer's
%   R (chronuxCoherence, chronuxSpikeField or chronuxUnitCoherence:
%   computeCoherencePanel) holds one pair per partner item, labeled
%   "<seed> x <partner>". As renderChronux draws a pair:
%     a band    the jackknife bars (R.Clo / R.Chi), errorPatch, role "sem"
%     a trace   the coherence magnitude, 0 to 1 (options.yLimMode "fixed":
%               options.yLim; "batch": the run's range),
%               role "trace"; several pairs: colored along the design's
%               sequential colormap (role "channelTrace"), the trial groups
%               by line style
%     a line    the level independent signals stay under (R.confC), dashed,
%               role "confLine"
%   in the group's color (or the seed layer's color and line style). With
%   options.showPhase, in a panel of renderFigure's layout, the panel's
%   axes become two: the magnitude over the top two thirds, the phase
%   (role "phase": the angle where the coherence is over its level,
%   every frequency without one; -pi to pi, "Phase (rad)") flush under it
%   on the one frequency axis. Both axes are tagged with the panel's id;
%   HK.axes is the magnitude's (renderFigure titles and labels it),
%   HK.extraAxes the phase's. Drawn into a single axes there is no phase.
%   options.stack "groups" draws the magnitude as a row per trial group
%   instead, the first on top, every pair overlaid in each row (in its
%   color, solid), in the rows of stackLayout (the row step
%   options.stackSpacing x the row height, the tallest row's reach; each
%   row on its own scale with options.yLimMode "auto", else one), a gray
%   line along each row (stackBaseLines), the rows named on the left y
%   axis and each row's top on the right (stackAxes); the phase strip
%   stays overlaid. HK.yExtent: a stack's reach, for a run's batch range.
%   A coherogram (R.kind "chronuxCohgram", options.overTime; of signals or spike trains) is an image
%   of the first pair's coherence over time and frequency for the trial
%   group options.group, 0 to 1 (options.cLim) in the heat colormap, with
%   a color bar ("Coherence") and the event's line; on the epochs it
%   shares the figure's time axis (renderFigure), on the range time base
%   its x is the recording's time. With options.stack "groups" every group
%   is an image row of its own (drawImageStack: the first on top, its
%   color strip at the left, its name on the y axis, one color scale and
%   color bar for all; y label "<groups' parameters> (<f1>-<f2> Hz per
%   row)"), the groups offered to the legend. x: "Frequency (Hz)", y
%   "Coherence" (a coherogram: "Frequency (Hz)"). Skipped layers are noted
%   (figLayerNotes). The legend offers the groups, then the pairs when
%   there are several.
%
%   See also renderFigure, renderChronux, computeCoherencePanel, figurePanelRegistry.
style = look.style;
o = look.panel.options;
Ls = look.panel.layers;
hk = figDrawResult(ax);
j = find(arrayfun(@(l) l.skip == "" && isstruct(l.R) && isfield(l.R, 'kind') ...
    && ismember(l.R.kind, ["chronuxCoherence" "chronuxSpikeField" "chronuxUnitCoherence" "chronuxCohgram"]), P.layers), 1);
if isempty(j)
    tagPart(ax, "axes", "", look.panelId);
    figLayerNotes(ax, P, look, false);
    return
end
R = P.layers(j).R;
if R.kind == "chronuxCohgram"
    hk = drawCohgram(ax, P, look, j, hk);
    return
end
[~, nP, nG] = size(R.C);
f = R.f;
colors = look.colors;
if size(colors, 1) ~= height(R.groups); colors = groupPalette(R.groups, style); end
band = ~isempty(R.Clo);
withPhase = logical(o.showPhase) && isappdata(ax, 'FigurePanel');   % a panel of renderFigure's layout, not one axes drawn into
px = gobjects(0);
if withPhase
    [ax, px] = splitTile(ax);
end
tagPart(ax, "axes", "", look.panelId);
if nP > 1
    cm = designColormap(style, "sequential", "parula", max(nP, 2));
    cm = cm(round(linspace(1, size(cm, 1) * 0.85, nP)), :);
end
styles = ["-" "--" ":" "-."];
stacked = isfield(o, 'stack') && o.stack == "groups";   % a row per trial group, the pairs overlaid in it
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
    name = string(R.pairs.label(p));
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
            stackMark(errorPatch(ax, f, k * R.Clo(:, p, g) + off, k * R.Chi(:, p, g) + off, col, tg, style), off, k);
        end
        h1 = stackMark(tagPart(plot(ax, f, k * R.C(:, p, g) + off, 'Color', col, 'LineWidth', style.LineWidth, 'LineStyle', ls), role, tg), off, k);
        c = R.confC(p, g);
        if isfinite(c) && numel(f) > 1
            tagPart(plot(ax, f([1 end]), k * [c c] + off, '--', 'Color', col, 'LineWidth', 1, 'HandleVisibility', 'off'), "confLine", tg);
        end
        if ~isempty(px)
            y = double(R.phi(:, p, g));
            if isfinite(c); y(~(R.C(:, p, g) > c)) = NaN; end
            tagPart(plot(px, f, y, '.', 'Color', col, 'MarkerSize', 6, 'HandleVisibility', 'off'), "phase", tg);
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
if nP > 1   % the pairs, by color
    for p = 1:nP
        name = string(R.pairs.label(p));
        hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'Color', legendLook{p, 1}, 'LineStyle', legendLook{p, 2}, ...
            'LineWidth', style.LineWidth), "channelTrace", name);
        hk.legendLabels(end+1) = name;
        hk.legendGroup(end+1) = false;
    end
elseif nG == 1   % one pair, one group: the pair names the trace
    name = string(R.pairs.label(1));
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
hk.yName = "Coherence";
if stacked
    stackAxes(ax, L, rowNames, "Row top (coherence)");
    hk.yName = stackYName(groupsName, L, "coherence");
end
if ~isempty(px)
    tagPart(px, "axes", "", look.panelId);
    if numel(f) > 1; xlim(px, double(f([1 end]).')); end
    ph = style;
    ph.XLim = [];
    ph.YLim = [];
    styleAxes(px, ph);
    ylim(px, [-pi pi]);
    set(px, 'YTick', [-pi 0 pi], 'YTickLabel', {['-' char(960)], '0', char(960)});
    ylabel(px, 'Phase (rad)', 'Interpreter', 'none', 'FontSize', style.FontSize);
    xlabel(px, "Frequency (Hz)");
    set(ax, 'XTickLabel', []);
    hk.extraAxes = px;
else
    xlabel(ax, "Frequency (Hz)");
end
hk.axes = ax;
figLayerNotes(ax, P, look, true);
end


function [ax, px] = splitTile(ax)
%splitTile  The panel's axes as two: the magnitude over the top two thirds, the phase flush under it.
%   (renderFigure's layout keeps them so: a panel's extra axes share its
%   plot area under its axes, the magnitude two shares to the phase's one.)
p = ax.Position;
px = axes(ax.Parent, 'Units', ax.Units, 'Position', [p(1) p(2) p(3) p(4) / 3]);
ax.Position = [p(1) p(2) + p(4) / 3 p(3) 2 * p(4) / 3];
hold(px, 'on');
end


function hk = drawCohgram(ax, P, look, j, hk)
%drawCohgram  A coherogram: the first pair's coherence over time and frequency, one trial group.
style = look.style;
o = look.panel.options;
R = P.layers(j).R;
nG = size(R.C, 4);
g = min(max(1, round(o.group)), nG);
stacked = isfield(o, 'stack') && o.stack == "groups";   % every group: an image row each, the first on top
name = string(R.pairs.label(1));
if stacked
    colors = look.colors;
    if size(colors, 1) ~= nG; colors = groupPalette(R.groups, style); end
    rowNames = reshape(string(rowLabels(R)), 1, []);
    Z = permute(R.C(:, :, 1, :), [2 1 4 3]);   % [nF x nT x nGroups]
    [~, hLeg] = drawImageStack(ax, R.t, R.f, Z, rowNames(1:nG), colors, o.stackSpacing);
    for q = 1:nG
        hk.legendHandles(end+1) = hLeg(q);
        hk.legendLabels(end+1) = string(R.groups.label(q));
        hk.legendGroup(end+1) = true;
    end
else
    x = R.C(:, :, 1, g).';
    tagPart(imagesc(ax, R.t, R.f, x, 'AlphaData', double(isfinite(x))), "image", name);
end
tagPart(ax, "axes", "", look.panelId);   % after imagesc
set(ax, 'YDir', 'normal', 'Layer', 'top');
colormap(ax, designColormap(style, "heat", "parula"));
cl = o.cLim;
if ~(numel(cl) == 2 && cl(2) > cl(1)); cl = [0 1]; end
clim(ax, cl);
if R.aligned && style.ShowZeroLine
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
if R.aligned && numel(W) == 2 && W(2) > W(1)
    xlim(ax, W);
elseif numel(R.t) > 1
    xlim(ax, double(R.t([1 end]).'));
end
if numel(R.f) > 1 && ~stacked; ylim(ax, double(R.f([1 end]).')); end
if ~R.aligned; xlabel(ax, "Time (s)"); end   % the recording's clock (an aligned one: renderFigure's time axis)
cb = tagPart(colorbar(ax), "colorbar");
cb.Label.String = "Coherence";
if look.panel.sharesTime
    cb.Location = 'east';   % inside, so its time axis lines up with the other time panels'
end
ttl = name;
if nG > 1 && ~stacked; ttl = name + " · " + string(R.groups.label(g)); end
title(ax, ttl, 'FontWeight', 'normal', 'Interpreter', 'none');
figLayerNotes(ax, P, look, true);
hk.axes = ax;
hk.yName = "Frequency (Hz)";
if stacked
    [~, gName] = rowLabels(R);
    hk.yName = sprintf("%s (%.3g-%.3g Hz per row)", gName, R.f(1), R.f(end));
end
end
