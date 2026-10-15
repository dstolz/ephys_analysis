function hk = drawRatePanel(ax, P, look)
%drawRatePanel  Draw a figure's firing rate panel: the trial groups along x, a bar, box or point cloud each.
%   HK = drawRatePanel(AX, P, LOOK) draws the panel result P (F.panels(k)
%   of EphysAnalysisRunner.computeFigure: firingRate results) into the axes
%   AX, as renderFigure asks (LOOK: style, colors, W, spec, panel, panelId,
%   isTop, isBottom, epochs, groups, observation, isTime). The trial groups
%   go along x (ticked with their values, rowLabels; the groupBy
%   parameters label the axis). Each item -- each unit of a layer in probe
%   order, or with aggregate "mean" the layer's mean over its units --
%   draws, per group, as options.display says:
%     bar     the mean over the group's epochs (a unit) or over the units'
%             means (a layer's mean), role "bar", with its error bar
%             (R.err, or the band across the units: Style.ShowSEM), role
%             "errorBar"
%     box     a box of the epochs' rates (a unit) or of the units' means,
%             role "box"
%     points  each epoch's rate (a unit) or each unit's mean as a dot, role
%             "points", over a pale bar of their mean, role "meanBar"
%   One item is drawn in the groups' colors; several (more layers, or a
%   fixed layer of several units drawn each) sit side by side within each
%   group's slot, each in a color of its own (the layer's color when set),
%   and are named in the figure's legend. The components' group is the
%   trial group's label, with several items "<item> · <group>" (the item
%   alone for one group). options.yLim fixes the y axis. Skipped layers are
%   noted (figLayerNotes). HK: figDrawResult's, yName = the rates' unit.
%
%   See also renderFigure, renderRates, firingRate, figurePanelRegistry.

style = look.style;
o = look.panel.options;
Ls = look.panel.layers;
hk = figDrawResult(ax);
tagPart(ax, "axes", "", look.panelId);

items = zeros(0, 2);   % [layer, unit] (unit 0: the layer's mean)
for j = 1:numel(P.layers)
    R = P.layers(j).R;
    if P.layers(j).skip ~= "" || ~isstruct(R) || ~isfield(R, 'meanRate'); continue; end
    if j <= numel(Ls) && Ls(j).aggregate == "mean" && isfield(R, 'layerMean')
        items(end+1, :) = [j 0]; %#ok<AGROW>
    else
        nU = size(R.meanRate, 1);
        items = [items; repmat(j, nU, 1) probeOrder(R.meta, nU, style)]; %#ok<AGROW>
    end
end
nI = size(items, 1);
if nI == 0
    figLayerNotes(ax, P, look, false);
    return
end

R0 = P.layers(items(1, 1)).R;
G = R0.groups;
nG = height(G);
gColors = look.colors;
if size(gColors, 1) ~= nG; gColors = groupPalette(G, style); end
names = strings(1, nI);
for i = 1:nI
    j = items(i, 1);
    u = items(i, 2);
    R = P.layers(j).R;
    if u == 0 || (size(R.meanRate, 1) == 1 && P.layers(j).name ~= "")
        names(i) = P.layers(j).name;
    else
        nm = shortUnitLabels(R.labels);
        names(i) = nm(u);
    end
end
iColors = zeros(nI, 3);
if nI > 1
    Gi = table((1:nI).', names(:), lines(nI), ones(nI, 1), 'VariableNames', {'index', 'label', 'color', 'n'});
    iColors = groupPalette(Gi, style);
end

w = 0.8 / nI;                                  % one item's share of a group's slot
offs = ((1:nI) - (nI + 1) / 2) * w;
hold(ax, 'on');
for i = 1:nI
    j = items(i, 1);
    u = items(i, 2);
    R = P.layers(j).R;
    [m, lo, hi, vals] = itemValues(R, u);
    first = gobjects(0);
    for g = 1:min(nG, numel(m))
        gl = string(G.label(g));
        c = gColors(g, :);
        if nI > 1; c = iColors(i, :); end
        c = figLayerLook(Ls(j), i, c);
        tg = gl;
        if nI > 1
            tg = names(i);
            if nG > 1; tg = names(i) + " · " + gl; end
        end
        x = g + offs(i);
        switch o.display
            case "box"
                y = vals{g};
                y = y(isfinite(y));
                if isempty(y)
                    h = tagPart(plot(ax, NaN, NaN, 's', 'Color', c), "box", tg);
                else
                    h = tagPart(boxchart(ax, repmat(x, numel(y), 1), y, 'BoxWidth', w * 0.8, 'BoxFaceColor', c, ...
                        'MarkerColor', c, 'MarkerStyle', '.'), "box", tg);
                end
            case "points"
                y = vals{g};
                y = y(:);
                jit = (mod((0:numel(y) - 1).', 7) - 3) / 3 * w * 0.3;
                ok = isfinite(y);
                tagPart(bar(ax, x, m(g), w * 0.9, 'FaceColor', paleColor(c, 0.7, style), 'EdgeColor', 'none', ...
                    'HandleVisibility', 'off'), "meanBar", tg);
                h = tagPart(plot(ax, x + jit(ok), y(ok), '.', 'Color', c, 'MarkerSize', 7), "points", tg);
            otherwise   % bar
                h = tagPart(bar(ax, x, m(g), w * 0.9, 'FaceColor', c, 'EdgeColor', 'none'), "bar", tg);
                if style.ShowSEM && isfinite(lo(g)) && isfinite(hi(g))
                    tagPart(errorbar(ax, x, m(g), m(g) - lo(g), hi(g) - m(g), 'LineStyle', 'none', 'Color', [0.2 0.2 0.2], ...
                        'CapSize', 2, 'HandleVisibility', 'off'), "errorBar", tg);
                end
        end
        if nI == 1 && nG > 1
            hk.legendHandles(end+1) = h;
            hk.legendLabels(end+1) = gl;
            hk.legendGroup(end+1) = true;
        end
        if isempty(first); first = h; end
    end
    if nI > 1 && ~isempty(first)
        hk.legendHandles(end+1) = first;
        hk.legendLabels(end+1) = names(i);
        hk.legendGroup(end+1) = false;
    end
end
hold(ax, 'off');
[labels, axName] = rowLabels(R0);
set(ax, 'XTick', 1:nG, 'XTickLabel', labels(1:nG), 'TickLabelInterpreter', 'none');
if nG > 8; ax.XTickLabelRotation = 45; end
xlim(ax, [0.4 nG + 0.6]);
flat = style;
flat.XLim = [];
flat.YLim = o.yLim;
styleAxes(ax, flat);
if axName ~= "Group"; xlabel(ax, axName, 'Interpreter', 'none'); end
figLayerNotes(ax, P, look, true);
hk.yName = R0.units;
end


function [m, lo, hi, vals] = itemValues(R, u)
%itemValues  One item's per-group mean, error edges and the values its box or points show.
%   A unit (U > 0): its mean over each group's epochs, R.err's edges, and
%   each group's epoch rates. A layer's mean (U = 0): the mean over the
%   units' means, the band across them (R.layerMean), and the units' means.
nG = height(R.groups);
vals = cell(1, nG);
if u == 0
    M = R.layerMean;
    m = reshape(M.mean, 1, []);
    lo = reshape(M.lo, 1, []);
    hi = reshape(M.hi, 1, []);
    for g = 1:nG; vals{g} = R.meanRate(:, g); end
    return
end
m = R.meanRate(u, :);
[eLo, eHi] = resultBounds(R, 'meanRate');
lo = eLo(u, :);
hi = eHi(u, :);
for g = 1:nG; vals{g} = R.rate(R.groupIndex == g, u); end
end
