function layers = trialPanelStats(layers, panel)
%trialPanelStats  A trial panel's grouping and statistics over all its computed layers.
%   LAYERS = trialPanelStats(LAYERS, PANEL) takes the layer results of a
%   trial panel (trialDist, trialHist, trialScatter; figurePanelLayers'
%   shape, each computed layer with R from computeTrialPanel), stacks the
%   computed layers' R.values (their layer column says whose), groups the
%   values by PANEL.options' categories (trialDist only; the others have
%   one category) and series (trialGrouping) and runs trialStats once (the
%   pairs' sig at options.testAlpha, 0.05 when the panel has none). Every
%   computed layer gets the same
%     R.categories, R.series   the levels (trialGrouping's G: index,
%                              label, color, n, value)
%     R.stats                  trialStats' S
%   and its own R.values gains the columns category and series (0: in no
%   level). The session grouping reads R.sessions when present (a merged
%   session figure), else the values' session column.
%
%   It runs twice for a session figure: at the end of each dataset's
%   compute (computeTrialPanel), and again by figureSessionCompute after the
%   datasets' values are merged, since the session grouping and the tests
%   need the merged table. Both runs are needed; do not drop the first, a
%   single-dataset figure has only it.
%
%   Errors: trialGrouping's (trialMeasure:NoParam, trialMeasure:BadParam).
%
%   See also computeTrialPanel, trialGrouping, trialStats.

done = find(arrayfun(@(l) l.skip == "" && isstruct(l.R) && isfield(l.R, 'values'), layers));
if isempty(done); return; end
o = panel.options;

% the values of every computed layer, on the columns they share
cols = string(layers(done(1)).R.values.Properties.VariableNames);
for j = done(2:end)
    cols = intersect(cols, string(layers(j).R.values.Properties.VariableNames), 'stable');
end
parts = cell(numel(done), 1);
rows = zeros(numel(done), 1);
for i = 1:numel(done)
    Vj = layers(done(i)).R.values(:, cols);
    parts{i} = Vj;
    rows(i) = height(Vj);
end
V = vertcat(parts{:});
R1 = layers(done(1)).R;
names = strings(1, numel(layers));
for j = 1:numel(layers); names(j) = string(layers(j).name); end
sessions = [];
if isfield(R1, 'sessions'); sessions = R1.sessions; end
G0 = [];
if isfield(R1, 'groups'); G0 = R1.groups; end

catHow = "none";
if panel.type == "trialDist" && isfield(o, 'categories'); catHow = string(o.categories); end
serHow = "none";
if isfield(o, 'series'); serHow = string(o.series); end
[ci, Gc] = trialGrouping(catHow, [], V, G0, Param=optOr(o, 'categoryParam', ""), Bins=optOr(o, 'categoryBins', []), ...
    Sessions=sessions, Layers=names);
[si, Gs] = trialGrouping(serHow, [], V, G0, Param=optOr(o, 'seriesParam', ""), Bins=optOr(o, 'seriesBins', []), ...
    Sessions=sessions, Layers=names);
xs = "linear";
if isfield(o, 'xScale'); xs = string(o.xScale); end
ys = "linear";
if isfield(o, 'yScale'); ys = string(o.yScale); end
[eType, nBoot] = figureErrorType(panel);   % the bands' error ("sem" where the panel draws none)
testAlpha = optOr(o, 'testAlpha', 0.05);   % the tests' level (options.alpha is a histogram's or scatter's opacity)
S = trialStats(V, ci, si, NCategories=height(Gc), NSeries=height(Gs), ...
    Summary=optOr(o, 'summary', "mean"), ErrorType=eType, ErrorResamples=nBoot, ...
    Test=optOr(o, 'test', "auto"), TestPairs=optOr(o, 'testPairs', "all"), Adjust=optOr(o, 'adjust', "holm"), ...
    Alpha=testAlpha, Fit=optOr(o, 'fit', "none"), FitWindow=optOr(o, 'fitWindow', 10), ...
    Corr=optOr(o, 'corr', "none"), XScale=xs, YScale=ys);
if panel.type ~= "trialScatter"   % hist and dist have no x measure
    S.fit = S.fit([]); S.corr = S.corr([]);
end

last = cumsum(rows);
for i = 1:numel(done)
    r = last(i) - rows(i) + 1:last(i);
    R = layers(done(i)).R;
    R.values.category = ci(r);
    R.values.series = si(r);
    R.categories = Gc;
    R.series = Gs;
    R.stats = S;
    layers(done(i)).R = R;
end
end


function v = optOr(o, name, default)
v = default;
if isfield(o, name) && ~isempty(o.(name)); v = o.(name); end
if isstring(default) || ischar(default); v = string(v); end
end
