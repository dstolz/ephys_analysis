function D = trialDrawData(P, look)
%trialDrawData  What a trial panel's draw function draws from: its computed layers' values stacked, the levels and their colors.
%   D = trialDrawData(P, LOOK) for a trial panel's result P (F.panels(k):
%   computeTrialPanel's layers, trialPanelStats' categories, series and
%   stats) and renderFigure's LOOK. D.ok is false when no layer was
%   computed (the draw function then notes why: figLayerNotes). Fields:
%     layers   the indices (in P.layers) of the computed layers
%     R        the first computed layer's R (its categories, series and
%              stats are every computed layer's)
%     V        table: every computed layer's R.values stacked (trial,
%              value, x, group, category, series, ...), with lay (the
%              layer's index in P.layers) and row (the row of that
%              layer's R.values): a point's TrialRows are [lay row]
%     C, S     the categories and the series (R.categories, R.series:
%              index, label, color, n, value); nC, nS their counts
%     stats    R.stats (trialStats' S)
%     colors   [nS x 3] each series' color: series "groups" the figure's
%              trial group colors (LOOK.colors when they are as many and
%              the panel's selection is the figure's, else groupPalette
%              of the series); "layer" each layer's own color when it
%              has one (figLayerLook), else the palette's; "param" and
%              "session" groupPalette (ordered levels: a design's
%              sequential colors, isOrdinalGroups)
%     lineStyles  [1 x nS] each series' line style ("-"; a layer's own,
%              figLayerLook, for series "layer")
%     legendGroup  true when the series are the figure's trial groups
%              (renderFigure lists each group once)
%     own      the panel has a trial selection of its own
%     yName    the y measure's label (every layer's when they are alike,
%              else "Value (<unit>)" or "Value"); xName a scatter's x
%     unit, xUnit  the measures' units ("" when the layers differ)
%
%   See also drawTrialDistPanel, drawTrialHistPanel, drawTrialScatterPanel, trialPanelStats.

D = struct('ok', false, 'layers', zeros(1, 0), 'R', [], 'V', table(), 'C', table(), 'S', table(), 'nC', 0, 'nS', 0, ...
    'stats', [], 'colors', zeros(0, 3), 'lineStyles', strings(1, 0), 'legendGroup', false, 'own', false, ...
    'yName', "", 'xName', "", 'unit', "", 'xUnit', "");
done = zeros(1, 0);
for j = 1:numel(P.layers)
    R = P.layers(j).R;
    if P.layers(j).skip == "" && isstruct(R) && isfield(R, 'values') && isfield(R, 'series') && istable(R.values)
        done(end+1) = j; %#ok<AGROW>
    end
end
if isempty(done); return; end
D.ok = true;
D.layers = done;
R1 = P.layers(done(1)).R;
D.R = R1;
D.C = R1.categories;
D.S = R1.series;
D.nC = height(D.C);
D.nS = height(D.S);
D.stats = R1.stats;

% the values of every computed layer, on the columns they share, with where each row came from
cols = string(R1.values.Properties.VariableNames);
for j = done(2:end)
    cols = intersect(cols, string(P.layers(j).R.values.Properties.VariableNames), 'stable');
end
parts = cell(numel(done), 1);
for i = 1:numel(done)
    Vj = P.layers(done(i)).R.values(:, cols);
    Vj.lay = repmat(done(i), height(Vj), 1);
    Vj.row = (1:height(Vj)).';
    parts{i} = Vj;
end
D.V = vertcat(parts{:});

% the axis names: the measure's label when every layer's is the same
labels = strings(1, numel(done));
units = strings(1, numel(done));
xLabels = strings(1, numel(done));
xUnits = strings(1, numel(done));
for i = 1:numel(done)
    R = P.layers(done(i)).R;
    labels(i) = string(R.label);
    units(i) = string(R.unit);
    if isfield(R, 'xLabel'); xLabels(i) = string(R.xLabel); end
    if isfield(R, 'xUnit'); xUnits(i) = string(R.xUnit); end
end
[D.yName, D.unit] = axisName(labels, units);
[D.xName, D.xUnit] = axisName(xLabels, xUnits);

% the series' colors
style = look.style;
o = look.panel.options;
Ls = look.panel.layers;
p = look.panel;
D.own = isfield(p, 'selection') && isstruct(p.selection) && isfield(look, 'spec') && isfield(look.spec, 'selection') ...
    && ~isequaln(p.selection, look.spec.selection);
how = "layer";
if isfield(o, 'series'); how = string(o.series); end
D.lineStyles = repmat("-", 1, D.nS);
if D.nS == 0; return; end
pal = groupPalette(D.S, style);
switch how
    case "groups"   % the figure's groups (its legend lists them once) unless the panel's selection is its own
        D.colors = pal;
        if ~D.own && size(look.colors, 1) == D.nS; D.colors = look.colors; end
        D.legendGroup = ~D.own && istable(look.groups) && height(look.groups) == D.nS && D.nS > 1;
    case "layer"
        D.colors = pal;
        for s = 1:D.nS
            j = D.S.value(s);
            if isfinite(j) && j >= 1 && j <= numel(Ls)
                [D.colors(s, :), D.lineStyles(s)] = figLayerLook(Ls(j), 1, pal(s, :));
            end
        end
    otherwise
        D.colors = pal;
end
end


function [name, unit] = axisName(labels, units)
%axisName  One axis' name for the layers' measures: their label when alike, else "Value (<unit>)" or "Value".
name = "";
unit = "";
keep = labels ~= "" | units ~= "";
labels = labels(keep);
units = units(keep);
if isempty(labels); return; end
u = unique(units);
if isscalar(u); unit = u; end
if isscalar(unique(labels))
    name = labels(1);
elseif isscalar(u) && u ~= ""
    name = "Value (" + u + ")";
else
    name = "Value";
end
end
