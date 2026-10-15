function P = computeCoherencePanel(src, panel, E, G, ctx)
%computeCoherencePanel  A figure's coherence panel: a seed layer's coherence with its partner layer (Chronux).
%   P = computeCoherencePanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "coherence"; CTX from EphysAnalysisRunner.computeFigure) has
%   P.layers, one per layer of PANEL (figurePanelLayers). It takes exactly
%   two enabled layers, the first the seed, the second its partner, each
%   read by figureChronuxLayer; the seed's first item (channel or unit) is
%   paired with each item of the partner (an item that is the seed itself
%   is left out), with the settings figureChronuxSettings builds from the
%   panel's options over the trials of chronuxTimeBaseOf (the panel's
%   epochs and groups, or with timeBase "range" segments of the recording):
%     signal x signal   chronuxCoherence (pairMode "seed": the seed's column
%                       with each partner column; both signals at one
%                       rate); options.overTime: a coherogram (cohgramc)
%                       over the moving window, at most 2000 MB
%     spikes x signal   chronuxSpikeField: the seed unit with each partner
%                       column (one call per column)
%     signal x spikes   chronuxSpikeField: each partner unit with the seed's
%                       column
%     spikes x spikes   chronuxUnitCoherence: the seed unit with each
%                       partner unit
%   The result goes to the seed layer's R (C, phi [nF x nPairs x nGroups],
%   Clo / Chi, confC, pairs, labels, nTrials, groups; a coherogram's t and
%   C [nT x nF x nPairs x nGroups]) with its pairs labeled "<seed> x
%   <partner>" (R.pairs.label, R.labels, R.names), layer, partnerLayer,
%   epochs and dataset; the partner layer's R is a marker (kind
%   "coherencePartner", seedLayer). Any other number of enabled layers, a
%   skipped one, a spike layer over time, signals at two rates, a partner
%   that is only the seed, a missing Chronux or settings chronuxSettings
%   refuses skip both layers with the reason.
%
%   See also figurePanelRegistry, chronuxCoherence, chronuxSpikeField,
%   chronuxUnitCoherence, drawCoherencePanel.
maxMB = 2000;
P = struct('layers', figurePanelLayers(panel, ctx.skips));
on = find(arrayfun(@(l) l.skip ~= "disabled", P.layers));
if numel(on) ~= 2
    for j = on
        if P.layers(j).skip == ""
            P.layers(j).skip = "A coherence panel takes two enabled layers: the seed, then its partner";
        end
    end
    return
end
a = on(1);
b = on(2);
if P.layers(a).skip ~= "" || P.layers(b).skip ~= ""
    P.layers = otherSkipped(P.layers, [a b]);
    return
end
[X1, lay1] = figureChronuxLayer(src, panel.layers(a), P.layers(a), ctx);
P.layers(a) = lay1;
if lay1.skip ~= ""
    P.layers = otherSkipped(P.layers, [a b]);
    return
end
[X2, lay2] = figureChronuxLayer(src, panel.layers(b), P.layers(b), ctx);
P.layers(b) = lay2;
if lay2.skip ~= ""
    P.layers = otherSkipped(P.layers, [a b]);
    return
end
try
    [R, why] = coherenceOf(src, X1, X2, E, G, panel, ctx, maxMB);
catch ME
    R = [];
    why = figureLayerError(ME);
end
if why ~= ""
    P.layers(a).skip = why;
    P.layers(b).skip = why;
    return
end
R.layer = a;
R.partnerLayer = b;
R.epochs = E;
R.dataset = src.name;
P.layers(a).R = R;
P.layers(b).R = struct('kind', "coherencePartner", 'seedLayer', a);
end


function [R, why] = coherenceOf(src, X1, X2, E, G, panel, ctx, maxMB)
%coherenceOf  The seed's first item with each partner item, by the layers' kinds.
R = [];
why = "";
o = panel.options;
W = [panel.window.pre panel.window.post];
if o.timeBase == "range"; W = []; end   % segments of the recording: the panel's window is not used
seedName = X1.names(1);
if X1.kind == "signal" && X2.kind == "signal"
    if X1.D.fs ~= X2.D.fs
        why = sprintf("the seed's %s and the partner's %s are at different rates (%g and %g Hz)", ...
            X1.source, X2.source, X1.D.fs, X2.D.fs);
        return
    end
    keep = ~(X2.source == X1.source & X2.cols == X1.cols(1));
    if ~any(keep); why = "the partner is the seed's channel itself: pick another"; return; end
    n = min(X1.nRows, X2.nRows);
    names = [seedName X2.names(keep)];
    sig = X1.source;
    if X2.source ~= X1.source; sig = X1.source + "/" + X2.source; end
    D = chronuxBlockOf([X1.D.data(1:n, 1) X2.D.data(1:n, keep)], X1.D.fs, [], sig, names);
    D.units = X1.D.units;
    S = figureChronuxSettings("coherence", o, W, "coherence");
    S.pairMode = "seed";
    S.seed = 1;
    S.channels = zeros(1, 0);
    seg = [];
    if S.overTime; seg = S.movingwin(1); end
    TB = chronuxTimeBaseOf(src, E, G, panel, Fs=D.fs, NRows=n, Segment=seg);
    R = chronuxCoherence(D, TB, S, Check=ctx.check, MaxMB=maxMB, Dataset=src.name);
    partners = names(2:end);
elseif o.overTime
    why = "A coherogram (over time) takes two signal layers: spike trains give one coherence spectrum";
    return
elseif X1.kind == "spikes" && X2.kind == "spikes"
    keep = ~(X2.source == X1.source & X2.unitIds == X1.unitIds(1));
    if ~any(keep); why = "the partner is the seed unit itself: pick another"; return; end
    t2 = X2.SP.times(keep);
    SP = struct('times', [X1.SP.times(1) t2], 'labels', [seedName X2.names(keep)], 'index', 1:(1 + numel(t2)), ...
        'unitId', [X1.unitIds(1) X2.unitIds(keep)], 'class', [X1.SP.class(1) X2.SP.class(keep)], 'source', X1.source);
    S = figureChronuxSettings("coherence", o, W, "unitCoherence");
    S.pairMode = "seed";
    S.unitSeed = 1;
    TB = chronuxTimeBaseOf(src, E, G, panel, LastSpike=max(X1.lastSpike, X2.lastSpike));
    R = chronuxUnitCoherence(SP, TB, S, Check=ctx.check, Dataset=src.name);
    partners = X2.names(keep);
elseif X1.kind == "spikes"   % the seed unit with each partner column
    S = figureChronuxSettings("coherence", o, W, "spikeField");
    TB = chronuxTimeBaseOf(src, E, G, panel, Fs=X2.D.fs, NRows=X2.nRows);
    SP = oneTrain(X1.SP);
    Rs = cell(1, numel(X2.names));
    for c = 1:numel(X2.names)
        S.fieldChannel = c;
        Rs{c} = chronuxSpikeField(X2.D, SP, TB, S, Check=ctx.check, Dataset=src.name);
    end
    R = catPairs(Rs);
    partners = X2.names;
else   % each partner unit with the seed's column
    D = X1.D;
    D.data = D.data(:, 1);
    D.channels = 1;
    D.labels = D.labels(1);
    S = figureChronuxSettings("coherence", o, W, "spikeField");
    S.fieldChannel = 1;
    TB = chronuxTimeBaseOf(src, E, G, panel, Fs=D.fs, NRows=X1.nRows);
    R = chronuxSpikeField(D, X2.SP, TB, S, Check=ctx.check, Dataset=src.name);
    partners = X2.names;
end
lab = reshape(seedName + " x " + reshape(partners, 1, []), [], 1);
R.pairs.label = lab;
R.labels = reshape(lab, 1, []);
R.names = R.labels;
end


function SP = oneTrain(SP)
%oneTrain  The first train of SP alone.
SP.times = SP.times(1);
SP.labels = SP.labels(1);
SP.index = 1;
SP.unitId = SP.unitId(1);
SP.class = SP.class(1);
end


function R = catPairs(Rs)
%catPairs  Spike-field results of one train with several field channels as one result, a pair per channel.
R = Rs{1};
if numel(Rs) < 2; return; end
for f = ["C" "phi" "Clo" "Chi" "phistd"]
    if ~isempty(R.(f)); R.(f) = catField(Rs, f, 2); end
end
for f = ["confC" "nTrials" "zerosp"]
    R.(f) = catField(Rs, f, 1);
end
R.pairs = catField(Rs, "pairs", 1);
R.labels = catField(Rs, "labels", 2);
R.field = catField(Rs, "field", 2);
end


function v = catField(Rs, f, dim)
%catField  Field F of each result in the cell RS, concatenated along DIM.
c = cellfun(@(x) x.(f), Rs, 'UniformOutput', false);
v = cat(dim, c{:});
end


function layers = otherSkipped(layers, ab)
%otherSkipped  Both layers skipped: the one that is not says its partner is.
for j = ab
    if layers(j).skip == ""
        layers(j).skip = "the coherence's other layer is skipped";
    end
end
end
