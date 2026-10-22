function hk = drawContinuousPanel(ax, P, look)
%drawContinuousPanel  Draw a figure's continuous signal panel: each layer's epoch mean per trial group.
%   HK = drawContinuousPanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure) into the axes AX,
%   as renderFigure asks (LOOK: style, colors, W, spec, panel, panelId,
%   isTop, isBottom, epochs, groups, observation, isTime). Each signal
%   layer (LFP, MUA, SPIKE, AUX: an evokedPotential result) gives its
%   items: each channel in probe order, or with aggregate "mean" the mean
%   over its channels (R.layerMean, its band across them). Every item and
%   trial group is a trace (role "trace"; a channel of a layer that draws
%   several, "channelTrace") over its band (options.errorType not "off":
%   R.err, errorPatch, role "sem"), in the group's color (or the layer's)
%   and the item's line style (the layer's lineStyle, else by order).
%   options.stack:
%     "off"      every trace on one axis, y label "Amplitude (<units>)";
%                options.yLimMode sets it (panelYLimits: "fixed" at
%                options.yLim, "batch" at the run's range, else from the
%                traces)
%     "items"    every item a row of its own, the groups overlaid in each
%                row (the layer's lineStyle, else solid), the rows named on
%                the left y axis
%     "groups"   every trial group a row of its own, the first on top (as
%                a raster lists them), the items overlaid in each row by
%                line style, the rows named by the groups' values
%                (rowLabels)
%   A stack's rows go where stackLayout puts them, the row step
%   options.stackSpacing x the row height (the tallest row's reach: its
%   means and bands, or with trials "only" its traces): each row scaled to
%   its own reach (options.yLimMode "auto"), or every row on one scale
%   ("rows": the reach of them all; "batch": the run's range; "fixed":
%   options.yLim), a gray line along each row (stackBaseLines), each row's
%   top value on the right y axis (stackAxes); y label "Channel (<height>
%   <units> per row)" on one scale, "Channel (each row on its own scale)"
%   else (stackYName; a stack of groups: the groups' parameters). HK.yExtent:
%   a stack's reach in the signal's units, for a run's batch range.
%   options.trials "faint" draws each epoch's trace (R.data, at most
%   options.maxTrials of them: computeContinuousPanel) of every item and
%   group as one NaN-joined line (role "trialTrace") in the group's color
%   paled, thin, over the band and under the mean; "only" draws the traces
%   in the group's color, without band or mean (they then stand for the
%   groups in the legend; a layer whose traces were not kept is drawn as
%   its mean). With aggregate "mean" each trace is the epoch's mean over
%   the layer's channels.
%   The components' group is the trial group's label, with several items
%   "<item> · <group>" (the item alone for one group). Style.ShowZeroLine
%   draws the event's line; the events layers drawn as marks become latency
%   lines and a rug (figEventMarks), also on a panel whose signal layers
%   are all skipped (then on a plain axis, whatever the display). Skipped
%   layers are noted (figLayerNotes). A result merged across sessions
%   (figureSessionCompute) draws its series as the groups, each member
%   session (R.members) a pale line under them (memberLines), and the
%   trial groups of trialGroups "combine" by line style (figSeriesStyle). The legend offers the groups, then
%   the items when there are several, then the marks.
%
%   See also renderFigure, evokedPotential, figurePanelRegistry.

style = look.style;
o = look.panel.options;
Ls = look.panel.layers;
hk = figDrawResult(ax);
tagPart(ax, "axes", "", look.panelId);

items = zeros(0, 2);   % [layer, channel index of R.mean] (0: the layer's mean)
for j = 1:numel(P.layers)
    R = P.layers(j).R;
    if P.layers(j).skip ~= "" || ~isstruct(R) || ~isfield(R, 'mean') || ~isfield(R, 'kind') || R.kind ~= "evoked"; continue; end
    if j <= numel(Ls) && Ls(j).aggregate == "mean" && isfield(R, 'layerMean')
        items(end+1, :) = [j 0]; %#ok<AGROW>
    else
        nC = size(R.mean, 2);
        items = [items; repmat(j, nC, 1) probeOrder(R.meta, nC, style)]; %#ok<AGROW>
    end
end
nI = size(items, 1);
hasMarks = any(arrayfun(@(l) l.skip == "" && isstruct(l.R) && isfield(l.R, 'kind') && l.R.kind == "events", P.layers));
if nI == 0 && ~hasMarks
    figLayerNotes(ax, P, look, false);
    return
end

% each item's traces: mean, band edges [nTime x nGroups]
trials = "off";   % each epoch's trace: "faint" behind the mean, "only" without it
if isfield(o, 'trials'); trials = string(o.trials); end
S = repmat(struct('t', [], 'm', [], 'lo', [], 'hi', [], 'name', "", 'role', "trace", 'R', [], 'X', [], 'xg', [], 'M', []), 1, nI);
for i = 1:nI
    j = items(i, 1);
    c = items(i, 2);
    R = P.layers(j).R;
    S(i).R = R;
    S(i).t = R.t(:);
    if trials ~= "off" && isfield(R, 'data') && ~isempty(R.data) && isfield(R, 'trialGroup')
        if c == 0   % a layer's mean: each epoch's mean over its channels (single, as kept: no double copy)
            S(i).X = reshape(mean(R.data, 2, 'omitnan'), size(R.data, 1), []);
        else
            S(i).X = reshape(R.data(:, c, :), size(R.data, 1), []);
        end
        S(i).xg = R.trialGroup(:);
    end
    if isfield(R, 'members') && isstruct(R.members) && isfield(R.members, 'mean') && ~isempty(R.members.mean)
        Mm = R.members.mean;   % [nTime x nChannels x nMembers]: the member sessions (merged across sessions, ShowMembers)
        if c == 0
            S(i).M = reshape(mean(Mm, 2, 'omitnan'), size(Mm, 1), []);
        else
            S(i).M = reshape(Mm(:, c, :), size(Mm, 1), []);
        end
    end
    if c == 0
        S(i).m = squeeze3(R.layerMean.mean);
        S(i).lo = squeeze3(R.layerMean.lo);
        S(i).hi = squeeze3(R.layerMean.hi);
        S(i).name = P.layers(j).name;
    else
        [lo, hi] = resultBounds(R, 'mean');
        S(i).m = squeeze3(R.mean(:, c, :));
        S(i).lo = squeeze3(lo(:, c, :));
        S(i).hi = squeeze3(hi(:, c, :));
        S(i).name = channelName(P.layers(j), R, c);
        if size(R.mean, 2) > 1; S(i).role = "channelTrace"; end
    end
end

stack = "off";   % marks alone (every signal layer skipped): a plain axis for them
if nI > 0 && isfield(o, 'stack'); stack = string(o.stack); end
stacked = stack ~= "off";
band = o.errorType ~= "off";
nGmax = 0;
for i = 1:nI; nGmax = max(nGmax, size(S(i).m, 2)); end
rowOf = @(i, g) 1;   % the row item I's group G is drawn in
rowNames = strings(1, 0);
groupsName = "Group";
L = [];
if stacked
    if stack == "items"
        rowOf = @(i, g) i;
        rowNames = [S.name];
    else   % "groups": a row per trial group, the items overlaid in it
        rowOf = @(i, g) g;
        [rowNames, groupsName] = rowLabels(S(1).R);
        rowNames = reshape(string(rowNames), 1, []);
        rowNames(end+1:nGmax) = "";
        rowNames = rowNames(1:nGmax);
    end
    nR = numel(rowNames);
    rlo = NaN(1, nR);   % each row's reach: its means and bands (with trials "only": its traces)
    rhi = NaN(1, nR);
    for i = 1:nI
        for g = 1:size(S(i).m, 2)
            r = rowOf(i, g);
            if trials == "only" && ~isempty(S(i).X)
                v = S(i).X(:, S(i).xg == g);
            else
                v = S(i).m(:, g);
                if band; v = [v; S(i).lo(:, g); S(i).hi(:, g)]; end %#ok<AGROW>
            end
            v = double(v(isfinite(v)));
            if isempty(v); continue; end
            rlo(r) = min([rlo(r); v]);
            rhi(r) = max([rhi(r); v]);
        end
    end
    [ymode, ylimits] = panelYLimits(look);
    L = stackLayout(rlo, rhi, o.stackSpacing, Mode=ymode, Limits=ylimits);
    hk.yExtent = [min(rlo) max(rhi)];
end
hold(ax, 'on');
if stacked; stackBaseLines(ax, S(1).t([1 end]), L, rowNames); end
lss = strings(1, nI);
traces = cell(1, nI);   % each item's trial lines, per group: drawn first, so every band and mean lies over every trace
for pass = 1:2
    for i = 1:nI
        j = items(i, 1);
        R = S(i).R;
        colors = look.colors;
        if size(colors, 1) ~= height(R.groups); colors = groupPalette(R.groups, style); end
        nG = size(S(i).m, 2);
        if pass == 1; traces{i} = gobjects(1, nG); end
        if pass == 2 && ~isempty(S(i).M)   % each member session, faint, under its series (in its row)
            if stacked
                sr = arrayfun(@(g) rowOf(i, g), double(R.members.series(:)).');
                memberLines(ax, S(i).t, S(i).M .* L.scale(sr) + L.offset(sr), R, colors, style);
            else
                memberLines(ax, S(i).t, S(i).M, R, colors, style);
            end
        end
        for g = 1:nG
            off = 0; k = 1;
            if stacked; off = L.offset(rowOf(i, g)); k = L.scale(rowOf(i, g)); end
            gl = string(R.groups.label(g));
            [c, ls] = figLayerLook(Ls(j), i, colors(g, :));
            if stack == "items"; ls = string(Ls(j).lineStyle); if ~ismember(ls, ["-" "--" ":" "-."]); ls = "-"; end; end
            ls = figSeriesStyle(R, g, ls, Ls(j));
            lss(i) = ls;
            tg = gl;
            if nI > 1
                tg = S(i).name;
                if nG > 1; tg = S(i).name + " · " + gl; end
            end
            if pass == 1
                if ~isempty(S(i).X)
                    traces{i}(g) = stackMark(trialLines(ax, S(i).t, S(i).X(:, S(i).xg == g), off, k, c, trials, ls, style, tg), off, k);
                end
                continue
            end
            only = trials == "only" && ~isempty(S(i).X);   % the traces alone: no band, no mean
            if band && ~only
                stackMark(errorPatch(ax, S(i).t, k * S(i).lo(:, g) + off, k * S(i).hi(:, g) + off, c, tg, style), off, k);
            end
            h1 = traces{i}(g);
            if ~only
                h1 = stackMark(tagPart(plot(ax, S(i).t, k * S(i).m(:, g) + off, 'Color', c, 'LineWidth', style.LineWidth, 'LineStyle', ls), S(i).role, tg), off, k);
            end
            if i == 1 && nG > 1 && isgraphics(h1)
                hk.legendHandles(end+1) = h1;
                hk.legendLabels(end+1) = gl;
                hk.legendGroup(end+1) = true;
            end
        end
    end
end
if nI > 1 && stack ~= "items"   % the items, by line style (a row per item: named on the y axis)
    for i = 1:nI
        j = items(i, 1);
        colors = look.colors;
        if size(colors, 1) ~= height(S(i).R.groups); colors = groupPalette(S(i).R.groups, style); end
        c = [0.25 0.25 0.25];
        if size(colors, 1) == 1; c = colors(1, :); end
        c = figLayerLook(Ls(j), i, c);
        hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'Color', c, 'LineStyle', lss(i), 'LineWidth', style.LineWidth), ...
            S(i).role, S(i).name);
        hk.legendLabels(end+1) = S(i).name;
        hk.legendGroup(end+1) = false;
    end
end
if style.ShowZeroLine
    tagPart(xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'), "zeroLine");
end
hold(ax, 'off');
if numel(look.W) == 2 && look.W(2) > look.W(1); xlim(ax, look.W); end
flat = style;
flat.XLim = [];
flat.YLim = [];
units = "";
if nI > 0; units = unitText(S(1).R.units); end
if stacked
    styleAxes(ax, flat);
    rightName = "Row top";
    if units ~= ""; rightName = "Row top (" + units + ")"; end
    stackAxes(ax, L, rowNames, rightName);
    what = "Channel";
    if stack == "groups"; what = groupsName; end
    hk.yName = stackYName(what, L, units);
else
    [~, flat.YLim] = panelYLimits(look);
    styleAxes(ax, flat);
    if units ~= ""; hk.yName = "Amplitude (" + units + ")"; end
end

nGroups = size(look.colors, 1);
if nI > 0; nGroups = height(S(1).R.groups); end
[hm, lm] = figEventMarks(ax, P, look, 1:max(1, nGroups), "group");
for m = 1:numel(hm)
    hk.legendHandles(end+1) = hm(m);
    hk.legendLabels(end+1) = lm(m);
    hk.legendGroup(end+1) = false;
end
figLayerNotes(ax, P, look, true);
end


function h = trialLines(ax, t, X, off, k, c, mode, ls, style, tg)
%trialLines  The epochs' traces X [nTime x nEpochs] (x K + OFF: a stack's row) as one NaN-joined line: pale and thin behind the mean ("faint"), else in C.
%   X stays in its class (single, as computeContinuousPanel keeps it): the
%   line's y data is built from it directly, with no double copy.
lw = max(0.25, 0.5 * style.LineWidth);
if mode == "faint"
    c = paleColor(c, 0.6, style);
    lw = max(0.25, 0.4 * style.LineWidth);
end
k = size(X, 2);
xx = NaN;
yy = NaN;
if k > 0
    xx = repmat([t(:); NaN], k, 1);
    yy = [X; NaN(1, k, 'like', X)];
    if k ~= 1; yy = yy * cast(k, 'like', X); end
    if off ~= 0; yy = yy + cast(off, 'like', X); end
    yy = reshape(yy, [], 1);
end
h = tagPart(line(ax, xx, yy, 'Color', c, 'LineWidth', lw, 'LineStyle', ls), "trialTrace", tg);
end


function X = squeeze3(X)
%squeeze3  [nTime x 1 x nGroups] as [nTime x nGroups].
X = reshape(X, size(X, 1), []);
end


function name = channelName(lay, R, c)
%channelName  One channel of a signal layer: the layer's name when it holds one, else "<source> ch <N>".
name = lay.name;
if size(R.mean, 2) == 1 && name ~= ""; return; end
name = lay.source + " " + string(R.labels(c));
if isfield(R, 'meta') && istable(R.meta) && ismember("recordingChannel", string(R.meta.Properties.VariableNames)) ...
        && height(R.meta) >= c && isfinite(R.meta.recordingChannel(c))
    name = lay.source + " ch " + R.meta.recordingChannel(c);
end
end


function s = unitText(u)
%unitText  A signal's unit for a label (µV for uV).
s = replace(string(u), "uV", "µV");
end

