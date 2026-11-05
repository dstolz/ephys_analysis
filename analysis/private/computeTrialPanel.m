function P = computeTrialPanel(src, panel, ctx, kind)
%computeTrialPanel  A trial panel's layers: each trials layer's measure per trial, grouped, with its statistics.
%   P = computeTrialPanel(SRC, PANEL, CTX, KIND) is the compute behind
%   computeTrialDistPanel, computeTrialHistPanel and
%   computeTrialScatterPanel (KIND "trialDist" | "trialHist" |
%   "trialScatter"; CTX from EphysAnalysisRunner.computeFigure). P.layers
%   is figurePanelLayers(PANEL, CTX.skips) with each enabled trials layer
%   computed:
%     [MASK, G, GI] = selectTrials(SRC, CTX.selection)   (the panel's own
%         trial selection, else the figure's; once for all layers)
%     [T, INFO] = trialMeasure(SRC, L.measure, MASK)     (the y value)
%     a scatter also trialMeasure(SRC, L.xMeasure, MASK), joined on the
%         trial: the first value of each side per trial (a measure with
%         several values per trial, which "all", pairs its first); values
%         without a partner are counted (drops.nUnpaired)
%   and then trialPanelStats over all of them (categories, series, stats).
%   A selection error (selectTrials:*, trialSelection:BadFilter) skips
%   every layer with its message, a measure's error (trialMeasure:*,
%   resolveEvents:*) its layer (figureLayerError).
%
%   Each computed layer's R:
%     kind       KIND
%     measure, label, unit      L.measure, its label and unit (trialMeasure)
%     xMeasure, xLabel, xUnit   a scatter's x measure ([], "", "" otherwise)
%     values     table, one row per value: trial, value (in unit), x (the
%                x measure's value; NaN off a scatter), tA, tB (s), k,
%                group (the row of groups, 0: none), session (1), sessionKey
%                (SRC.key), layer (the layer's index in the panel), then the
%                selection's groupBy columns and the categories' and
%                series' parameter columns (categoryParam, seriesParam),
%                copied from SRC.trials; trialPanelStats adds category and
%                series
%     groups     selectTrials' groups table, n recounted: the trials with a
%                value in each group
%     groupIndex values.group
%     n          height(values)
%     drops      nTrials (rows of SRC.trials), nKept (trials the selection
%                kept), nA, nNoB, nNoValue (the y measure's, trialMeasure's
%                info), xA, xNoB, xNoValue (the x measure's; 0 off a
%                scatter), nUnpaired (scatter values without a partner)
%     options    PANEL.options
%     dataset    SRC.name
%     params     struct: measure, xMeasure, selection
%     created    when it was computed (text)
%     categories, series, stats   trialPanelStats', the same in every layer
%   A layer's name defaults to its label ("y vs x" for a scatter).
%
%   See also computeTrialDistPanel, trialMeasure, trialPanelStats, selectTrials.

o = panel.options;
P = struct('layers', figurePanelLayers(panel, ctx.skips));   % the error bands' type: figureErrorType, in trialPanelStats
todo = find(arrayfun(@(l) l.skip == "", P.layers));
if isempty(todo); return; end
sel = [];
if isfield(ctx, 'selection'); sel = ctx.selection; end
try
    [mask, G, gi] = selectTrials(src, sel);
catch ME
    reason = figureLayerError(ME);
    for j = todo; P.layers(j).skip = reason; end
    return
end
if isempty(mask); mask = []; end   % no paired trials: every event, one group
sel = trialSelection(sel);
cols = paramColumns(src, sel, o);
nTrials = 0;
if istable(src.trials); nTrials = height(src.trials); end
for j = todo
    L = panel.layers(j);
    lay = P.layers(j);
    checkpoint(ctx);
    try
        [T, info] = trialMeasure(src, L.measure, mask);
        x = NaN(height(T), 1);
        xm = []; xl = ""; xu = "";
        dx = struct('nA', 0, 'nNoB', 0, 'nNoValue', 0);
        nUnpaired = 0;
        if kind == "trialScatter"
            xm = L.xMeasure;
            [TX, infoX] = trialMeasure(src, xm, mask);
            xl = infoX.label; xu = infoX.unit;
            dx = infoX;
            [T, x, nUnpaired] = pairOnTrial(T, TX);
            if height(T) == 0
                error('trialMeasure:NoValues', '%s: no trial has both a value of "%s" and of "%s".', src.name, info.label, xl);
            end
        end
    catch ME
        P.layers(j).skip = figureLayerError(ME);
        continue
    end
    nV = height(T);
    group = ones(nV, 1);
    if ~isempty(gi)
        group = zeros(nV, 1);
        ok = isfinite(T.trial) & T.trial >= 1 & T.trial <= numel(gi);
        group(ok) = gi(T.trial(ok));
    end
    V = [T(:, {'trial', 'value'}), table(x, 'VariableNames', {'x'}), T(:, {'tA', 'tB', 'k'}), ...
        table(group, ones(nV, 1), repmat(string(src.key), nV, 1), repmat(j, nV, 1), ...
        'VariableNames', {'group', 'session', 'sessionKey', 'layer'})];
    for c = cols
        w = src.trials.(c);
        if ~(isnumeric(w) || islogical(w)); w = string(w); end
        v = repmat(missingOf(w), nV, 1);
        ok = isfinite(T.trial) & T.trial >= 1;
        v(ok) = w(T.trial(ok));
        V.(c) = v;
    end
    Gr = G;
    for g = 1:height(Gr)
        Gr.n(g) = numel(unique(V.trial(V.group == g & isfinite(V.trial))));
    end
    if isempty(gi); Gr.n(1) = nV; end
    R = struct();
    R.kind = kind;
    R.measure = L.measure;
    R.label = info.label;
    R.unit = info.unit;
    R.xMeasure = xm;
    R.xLabel = xl;
    R.xUnit = xu;
    R.values = V;
    R.groups = Gr;
    R.groupIndex = V.group;
    R.n = nV;
    R.drops = struct('nTrials', nTrials, 'nKept', nnz(mask), 'nA', info.nA, 'nNoB', info.nNoB, 'nNoValue', info.nNoValue, ...
        'xA', dx.nA, 'xNoB', dx.nNoB, 'xNoValue', dx.nNoValue, 'nUnpaired', nUnpaired);
    R.options = o;
    R.dataset = src.name;
    R.params = struct('measure', L.measure, 'xMeasure', xm, 'selection', sel);
    R.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    lay.R = R;
    if lay.name == ""
        lay.name = info.label;
        if kind == "trialScatter"; lay.name = info.label + " vs " + xl; end
    end
    P.layers(j) = lay;
end
try
    P.layers = trialPanelStats(P.layers, panel);
catch ME
    reason = figureLayerError(ME);
    for j = todo
        if P.layers(j).skip == ""; P.layers(j).skip = reason; P.layers(j).R = []; end
    end
end
end


function [T, x, nUnpaired] = pairOnTrial(T, TX)
%pairOnTrial  The first y and the first x value of each trial both have (scatter).
[uy, iy] = unique(T.trial(isfinite(T.trial)), 'first');
fy = find(isfinite(T.trial));
iy = fy(iy);
[ux, ix] = unique(TX.trial(isfinite(TX.trial)), 'first');
fx = find(isfinite(TX.trial));
ix = fx(ix);
[both, ay, ax] = intersect(uy, ux);
nUnpaired = (height(T) - numel(both)) + (height(TX) - numel(both));
T = T(iy(ay), :);
x = TX.value(ix(ax));
if isempty(both); x = zeros(0, 1); end
end


function cols = paramColumns(src, sel, o)
%paramColumns  The trial columns a trial panel's values carry: groupBy, categoryParam, seriesParam.
cols = string.empty(1, 0);
if ~src.hasTrials || ~istable(src.trials); return; end
want = reshape(string(sel.groupBy), 1, []);
if isfield(o, 'categories') && string(o.categories) == "param" && isfield(o, 'categoryParam'); want(end+1) = string(o.categoryParam); end
if isfield(o, 'series') && string(o.series) == "param" && isfield(o, 'seriesParam'); want(end+1) = string(o.seriesParam); end
reserved = ["trial" "value" "x" "tA" "tB" "k" "group" "session" "sessionKey" "layer" "category" "series"];
vars = string(src.trials.Properties.VariableNames);
for c = unique(want(want ~= ""), 'stable')
    if ismember(c, vars) && ~ismember(c, reserved) && size(src.trials.(c), 2) == 1 && ~isstruct(src.trials.(c))
        cols(end+1) = c; %#ok<AGROW>
    end
end
end


function m = missingOf(w)
%missingOf  The missing value of a column's type.
if isnumeric(w)
    m = NaN;
elseif islogical(w)
    m = false;
else
    m = string(missing);
end
end


function checkpoint(ctx)
if isfield(ctx, 'checkpoint') && isa(ctx.checkpoint, 'function_handle'); ctx.checkpoint(); end
end
