function [panels, S, C] = figureLatencies(spec, panels, C)
%figureLatencies  A figure's first-spike latencies and response onsets: once per unit and alignment, handed to every panel that reads them.
%   [PANELS, S, C] = figureLatencies(SPEC, PANELS, C) takes, for the
%   computed panels PANELS (figureCompute's F.panels, or a figure merged
%   across sessions: figureSessionCompute) of the figure spec SPEC, the
%   latencies its panels read, by the figure's latency block SPEC.latency
%   (defaults("Latency"); one block for the whole figure, its panels keep
%   only their looks):
%     per trial  each epoch's first-spike latency (firstSpikeLatency with
%                the block's method: "first", "surprise" or "poisson", its
%                window minSec-maxSec, baseline and the rule's options),
%                for a raster with its first-spike marks on
%                (options.firstSpike.enabled) or sorted by latency
%                (rasterSort "latency"), a PSTH with its latency box plot
%                on (options.latencyBox.enabled; not drawn as a heat map)
%                and a heat map of trials sorted by latency (rows "trials",
%                rasterSort "latency")
%     per unit   its response onset by CUSUM (responseOnset with the
%                block's window, baseline and cusum* settings), for a
%                raster or PSTH that draws it (options.onsetLine "unit" or
%                "groups")
%   Each is taken once per unit and alignment: per unit of a layer's
%   raster rows (R.raster(u), with its epochs' groups, the raster's span
%   and the epochs' t0Continuous), so a raster and a PSTH of one unit on
%   the same epochs share one. Every panel layer on those rows gets them
%   in its result: R.latency (firstSpikeLatency's struct for the layer's
%   units, the columns in R.raster's order, plus why: "" or why there is
%   none, as no baseline before the event) and R.onset (responseOnset's,
%   plus why). A heat map of trials sorted by latency gets its rows' order
%   again from them (figEpochOrder: R.trialOrder, R.trialRowsName). A
%   skipped panel or layer, or one without raster rows, gets none.
%
%   C is figureCompute's cache (on, pool, dataset, K: figureReuse,
%   figureKeep): each unit's latencies are kept as kind "latency", its
%   onset as "onset", keyed by its raster rows and the block's settings
%   its rule reads (the method's own: a "first" latency does not read the
%   baseline, nor a per-trial one the CUSUM's), so an edit of the block
%   computes only what reads the settings changed, and an edit of
%   anything else none of them. Without C (or with C.on false) nothing is
%   kept, but each is still taken once in this call.
%
%   S, the figure's summary (F.latency): settings (the block) and entries,
%   one per unit and alignment: panels (the ids of the panels that read
%   it), layer (the first one's name), unit (its label), lat ([nEpochs x 1]
%   its latencies; [] when no panel reads them), epochGroup, onset and
%   groupOnset (its onsets; NaN when no panel draws them) and why.
%
%   See also figureCompute, firstSpikeLatency, responseOnset, figEpochOrder.

arguments
    spec (1,1) struct
    panels struct
    C = []
end
L0 = EphysAnalysisConfig.defaults("Latency");
if isfield(spec, 'latency') && isstruct(spec.latency); L0 = EphysAnalysisConfig.normalizeSection("Latency", spec.latency); end
C0 = C;
keepK = isstruct(C) && isfield(C, 'on') && C.on;
if ~keepK   % taken once in this call all the same
    C = struct('on', true, 'pool', [], 'dataset', "", ...
        'K', struct('kind', {}, 'dataset', {}, 'key', {}, 'value', {}, 'bytes', {}, 'from', {}));
end
[trialOpts, onsetOpts] = optionsOf(L0);
E = struct('panels', {}, 'layer', {}, 'unit', {}, 'rows', {}, 'lat', {}, 'epochGroup', {}, 'onset', {}, ...
    'groupOnset', {}, 'why', {});
for k = 1:min(numel(panels), numel(spec.panels))
    p = spec.panels(k);
    [wantL, wantO] = needs(p);
    if ~(wantL || wantO) || panels(k).skip ~= ""; continue; end
    for j = 1:numel(panels(k).layers)
        lay = panels(k).layers(j);
        R = lay.R;
        if lay.skip ~= "" || ~hasRows(R); continue; end
        nU = numel(R.raster);
        Ls = cell(1, nU);
        Os = cell(1, nU);
        for u = 1:nU
            rows = rowsKey(R, u);
            e = find(arrayfun(@(x) isequaln(x.rows, rows), E), 1);
            if isempty(e)
                E(end+1) = struct('panels', strings(1, 0), 'layer', string(lay.name), 'unit', unitLabel(R, u), ...
                    'rows', rows, 'lat', [], 'epochGroup', double(R.epochGroup(:)), 'onset', NaN, 'groupOnset', [], 'why', ""); %#ok<AGROW>
                e = numel(E);
            end
            if ~ismember(p.id, E(e).panels); E(e).panels(end+1) = p.id; end
            if wantL
                key = struct('rows', rows, 'opts', trialOpts);
                [hit, v, C] = figureReuse(C, "latency", key);
                if ~hit
                    v = trialOf(R, u, trialOpts);
                    C = figureKeep(C, "latency", key, v);
                end
                Ls{u} = v;
                E(e).lat = v.lat(:, 1);
                if v.why ~= ""; E(e).why = v.why; end
            end
            if wantO
                key = struct('rows', rows, 'opts', onsetOpts);
                [hit, v, C] = figureReuse(C, "onset", key);
                if ~hit
                    v = onsetOf(R, u, onsetOpts);
                    C = figureKeep(C, "onset", key, v);
                end
                Os{u} = v;
                E(e).onset = v.onset(1);
                E(e).groupOnset = v.groupOnset(:, 1);
                if v.why ~= "" && E(e).why == ""; E(e).why = v.why; end
            end
        end
        if wantL
            R.latency = joinLatency(Ls, R);
            if p.type == "heatmap" && isfield(R, 'trialMatrix')   % a heat map of trials: its rows by these latencies
                [R.trialOrder, R.trialRowsName] = figEpochOrder(R, p.options);
            end
        end
        if wantO; R.onset = joinOnset(Os, R); end
        panels(k).layers(j).R = R;
    end
end
S = struct('settings', L0, 'entries', rmfield(E, 'rows'));
if ~keepK; C = C0; end
end


function [wantL, wantO] = needs(p)
%needs  Whether panel P reads each epoch's latency (WANTL) and draws the unit's onset (WANTO).
o = p.options;
wantL = false;
wantO = false;
if ~isstruct(o); return; end
sortLat = isfield(o, 'rasterSort') && string(o.rasterSort) == "latency";
onset = isfield(o, 'onsetLine') && string(o.onsetLine) ~= "off";
switch p.type
    case "raster"
        wantL = enabled(o, 'firstSpike') || sortLat;
        wantO = onset;
    case "psth"
        wantL = enabled(o, 'latencyBox') && ~(isfield(o, 'display') && o.display == "heatmap");
        wantO = onset;
    case "heatmap"
        wantL = isfield(o, 'rows') && o.rows == "trials" && sortLat;
end
end


function tf = enabled(o, f)
tf = isfield(o, f) && isstruct(o.(f)) && isfield(o.(f), 'enabled') && o.(f).enabled;
end


function tf = hasRows(R)
%hasRows  Whether a layer's result holds raster rows (spikePSTH with Raster=true).
tf = isstruct(R) && isfield(R, 'raster') && ~isempty(R.raster) && isfield(R, 'epochGroup') && isfield(R, 'edges');
if tf && isfield(R, 'params') && isstruct(R.params) && isfield(R.params, 'Raster') && ~R.params.Raster; tf = false; end
end


function k = rowsKey(R, u)
%rowsKey  What one unit's latencies are taken from: its raster rows, its epochs' groups, the raster's span and the epochs' times.
t0 = [];
if isfield(R, 'epochs') && istable(R.epochs) && ismember('t0Continuous', R.epochs.Properties.VariableNames)
    t0 = R.epochs.t0Continuous(:);
end
nG = 0;
if isfield(R, 'groups') && istable(R.groups); nG = height(R.groups); end
k = struct('times', R.raster(u).times(:), 'epoch', R.raster(u).epoch(:), 'span', R.edges([1 end]), ...
    'groups', double(R.epochGroup(:)), 'nGroups', nG, 't0', t0);
end


function s = unitLabel(R, u)
s = "";
if isfield(R, 'labels') && numel(R.labels) >= u; s = string(R.labels(u)); end
end


function [T, O] = optionsOf(L)
%optionsOf  The block's settings each rule reads, as firstSpikeLatency's (T) and responseOnset's (O) options.
B = [];
if L.baseline == "window"; B = reshape(L.baselineWindow, 1, []); end
T = struct('Method', L.method, 'MinSec', L.minSec, 'MaxSec', L.maxSec);
switch L.method
    case "surprise"
        T.Baseline = B;
        T.BaselineRate = L.baselineRate;
        T.Surprise = L.surprise;
        T.MinSpikes = L.minSpikes;
    case "poisson"
        T.Baseline = B;
        T.BaselineRate = L.baselineRate;
        T.Alpha = L.alpha;
end
O = struct('MinSec', L.minSec, 'MaxSec', L.maxSec, 'Baseline', B, 'BinSec', L.cusumBinSec, ...
    'Threshold', L.cusumThreshold, 'Drift', L.cusumDrift, 'SustainSec', L.cusumSustainSec);
end


function L = trialOf(R, u, o)
%trialOf  Unit U's latencies by the options O (firstSpikeLatency), with why ""; a rule that cannot be followed: NaN and why.
args = namedArgs(o);
try
    L = firstSpikeLatency(R, args{:}, Units=u);
    L.why = "";
catch ME
    if ~startsWith(string(ME.identifier), "firstSpikeLatency:"); rethrow(ME); end
    grp = double(R.epochGroup(:));
    nE = numel(grp);
    G = [];
    if isfield(R, 'groups'); G = R.groups; end
    nG = 0;
    if istable(G); nG = height(G); end
    ok = isfinite(grp) & grp >= 1 & grp <= nG;
    L = struct('lat', NaN(nE, 1), 'spikeTime', NaN(nE, 1), 'rate', NaN(nE, 1), 'window', [NaN NaN], 'baseline', [], ...
        'method', o.Method, 'settings', o, 'units', u, 'labels', unitLabel(R, u), 'epochGroup', grp, 'groups', G, ...
        'n', zeros(nG, 1), 'nEpochs', accumarray(grp(ok), 1, [nG 1]), 'why', string(ME.message));
end
end


function O = onsetOf(R, u, o)
%onsetOf  Unit U's response onset by the options O (responseOnset), with why ""; one that cannot be found: NaN and why.
args = namedArgs(o);
try
    O = responseOnset(R, args{:}, Units=u);
    O.why = "";
catch ME
    if ~startsWith(string(ME.identifier), "responseOnset:"); rethrow(ME); end
    nG = 0;
    G = [];
    if isfield(R, 'groups'); G = R.groups; end
    if istable(G); nG = height(G); end
    O = struct('onset', NaN, 'groupOnset', NaN(nG, 1), 't', zeros(0, 1), 'cusum', zeros(0, 1), 'baselineMean', NaN, ...
        'baselineSD', NaN, 'window', [NaN NaN], 'baseline', [], 'settings', o, 'units', u, 'labels', unitLabel(R, u), ...
        'groups', G, 'why', string(ME.message));
end
end


function a = namedArgs(o)
%namedArgs  A struct's fields as Name, Value pairs.
f = fieldnames(o);
a = cell(1, 2 * numel(f));
a(1:2:end) = f;
a(2:2:end) = struct2cell(o);
end


function L = joinLatency(Ls, R)
%joinLatency  The layer's latencies: each unit's (firstSpikeLatency of one unit) side by side, in R.raster's order.
L = Ls{1};
for f = ["lat" "spikeTime" "rate" "n"]
    L.(f) = cell2mat(cellfun(@(x) x.(f), Ls, 'UniformOutput', false));
end
L.units = 1:numel(Ls);
L.labels = each(Ls, 'labels');
L.why = firstWhy(Ls);
ok = cellfun(@(x) all(isfinite(x.window)), Ls);
if any(ok); L.window = Ls{find(ok, 1)}.window; L.baseline = Ls{find(ok, 1)}.baseline; end
if ~isfield(R, 'labels'); L.labels(:) = ""; end
end


function O = joinOnset(Os, R)
%joinOnset  The layer's onsets: each unit's (responseOnset of one unit) side by side, in R.raster's order.
ok = find(each(Os, 'why') == "", 1);   % the fields of a unit whose onset was found, else the first's
if isempty(ok); ok = 1; end
O = Os{ok};
n = numel(O.t);
nG = 0;
if isfield(R, 'groups') && istable(R.groups); nG = height(R.groups); end
nU = numel(Os);
O.onset = cellfun(@(x) x.onset(1), Os);
O.groupOnset = NaN(nG, nU);
O.cusum = NaN(n, nU);
O.baselineMean = NaN(1, nU);
O.baselineSD = NaN(1, nU);
for u = 1:nU
    x = Os{u};
    if numel(x.groupOnset) == nG; O.groupOnset(:, u) = x.groupOnset(:); end
    if size(x.cusum, 1) == n; O.cusum(:, u) = x.cusum(:, 1); end
    O.baselineMean(u) = x.baselineMean(1);
    O.baselineSD(u) = x.baselineSD(1);
end
O.units = 1:nU;
O.labels = each(Os, 'labels');
O.why = firstWhy(Os);
end


function s = each(X, f)
%each  Field F (a string) of each struct of the cell X, as a string row.
s = strings(1, numel(X));
for i = 1:numel(X); s(i) = string(X{i}.(f)); end
end


function w = firstWhy(X)
%firstWhy  The first reason among the structs of X ("" when none says one).
why = each(X, 'why');
w = "";
if any(why ~= ""); w = why(find(why ~= "", 1)); end
end
