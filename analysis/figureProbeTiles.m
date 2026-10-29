function [T, left, sites] = figureProbeTiles(src, spec)
%figureProbeTiles  The tiles of a probe figure on one dataset: its units or channels at their sites on the probe.
%   [T, LEFT] = figureProbeTiles(SRC, SPEC) lists the observations the
%   probe figure SPEC (EphysAnalysisConfig.figureFor of a figure whose
%   probe.enabled is true) lays out on the probe of the dataset SRC
%   (loadAnalysisSource), a tile each, in probe order:
%     1. figureObservations(SRC, SPEC) with observe.perGroup off (a probe
%        figure draws each observation once); observe.units and
%        observe.starred filter as for every figure
%     2. the rows with a finite position: a unit's meta{1}.x and .y
%        (selectUnits: its site on the probe map), a channel's
%        (selectChannels); T.shank and T.depth as figureObservations gives
%        them
%     3. the sites probe.shanks (kcoords shank numbers), probe.channels
%        (recording channels) and probe.depthRange ([lo hi] µm of y) keep
%        ([] = all)
%     4. at most probe.maxPerSite rows on one recording channel, the first
%        in probe order
%     5. at most probe.maxTiles rows: more keep every k-th in probe order,
%        round(linspace(1, n, maxTiles))
%   T has figureObservations' columns plus x and y (µm). LEFT counts them:
%   total (the figure's observations), noPosition, filtered (by shanks,
%   channels, depthRange), overSite (beyond maxPerSite), overMax (beyond
%   maxTiles) and kept (height(T)); total is the sum of the others. A
%   dataset with no observation, or none with a position, gives an empty T
%   with these columns.
%
%   [T, LEFT, SITES] = figureProbeTiles(...) also gives every site of the
%   probe map (SRC.probe: chanMap 0-based, xc, yc, kcoords), a row each:
%   channel (1-based), x, y, shank (kcoords; 0 without) and included (it
%   passes shanks, channels and depthRange). No probe map: no row.
%
%   It is pure: figureProbeCompute, EphysAnalysisRunner.runDataset and the
%   app's Probe layout section call it.
%
%   See also figureProbeCompute, figureObservations, probeOrder,
%   EphysAnalysisRunner.computeProbeFigure.

arguments
    src (1,1) struct
    spec (1,1) struct
end

popts = EphysAnalysisConfig.defaults("FigureProbe");
if isfield(spec, 'probe') && isstruct(spec.probe); popts = spec.probe; end
sites = probeSiteTable(src);
sites.included = keeps(popts, sites.shank, sites.channel, sites.y);

one = spec;
one.observe.perGroup = false;   % a tile per observation, not per trial group
T = figureObservations(src, one);
n0 = height(T);
x = NaN(n0, 1);
y = NaN(n0, 1);
for i = 1:n0
    m = T.meta{i};
    if istable(m) && height(m) >= 1 && all(ismember(["x" "y"], string(m.Properties.VariableNames)))
        x(i) = double(m.x(1));
        y(i) = double(m.y(1));
    end
end
T.x = x;
T.y = y;
left = struct('total', n0, 'noPosition', 0, 'filtered', 0, 'overSite', 0, 'overMax', 0, 'kept', 0);

has = isfinite(T.x) & isfinite(T.y);
left.noPosition = nnz(~has);
T = T(has, :);

in = keeps(popts, T.shank, T.channel, T.y);
left.filtered = nnz(~in);
T = T(in, :);

on = true(height(T), 1);   % at most maxPerSite on one recording channel, the first in probe order
ch = T.channel;
for c = unique(ch(isfinite(ch))).'
    at = find(ch == c);
    on(at(popts.maxPerSite + 1:end)) = false;
end
left.overSite = nnz(~on);
T = T(on, :);

n = height(T);
if n > popts.maxTiles
    pick = unique(round(linspace(1, n, popts.maxTiles)));
    left.overMax = n - numel(pick);
    T = T(pick, :);
end
left.kept = height(T);
end


function tf = keeps(popts, shank, channel, y)
%keeps  The sites (or tiles) probe.shanks, probe.channels and probe.depthRange keep ([] = all).
tf = true(numel(y), 1);
if ~isempty(popts.shanks); tf = tf & ismember(shank(:), popts.shanks); end
if ~isempty(popts.channels); tf = tf & ismember(channel(:), popts.channels); end
d = popts.depthRange;
if numel(d) == 2; tf = tf & y(:) >= d(1) & y(:) <= d(2); end
end


function S = probeSiteTable(src)
%probeSiteTable  Every site of the probe map: channel (1-based), x, y, shank (kcoords); no map, no row.
S = table(zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), 'VariableNames', {'channel', 'x', 'y', 'shank'});
p = [];
if isfield(src, 'probe'); p = src.probe; end
if isempty(p) || ~isstruct(p) || ~all(isfield(p, {'chanMap', 'xc', 'yc'})); return; end
ch = double(p.chanMap(:)) + 1;
n = min([numel(ch) numel(p.xc) numel(p.yc)]);
kc = zeros(n, 1);
if isfield(p, 'kcoords') && numel(p.kcoords) >= n; kc = double(reshape(p.kcoords(1:n), [], 1)); end
S = table(ch(1:n), double(reshape(p.xc(1:n), [], 1)), double(reshape(p.yc(1:n), [], 1)), kc, ...
    'VariableNames', {'channel', 'x', 'y', 'shank'});
end
