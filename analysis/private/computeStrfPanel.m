function P = computeStrfPanel(src, panel, E, G, ctx)
%computeStrfPanel  A figure's STRF panel: the spectrotemporal receptive field of a spike train from TORC or DMR stimuli.
%   P = computeStrfPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "strf"; CTX from EphysAnalysisRunner.computeFigure) has
%   P.layers, one per layer of PANEL (figurePanelLayers). The first
%   enabled layer (units or detected spikes, resolved for the observation
%   by figureLayerItems: the observed unit, or the fixed units it names,
%   their spikes pooled) is analyzed:
%     S = rippleStimuli(SRC, E, CTX.ref, options.stim)   which stimulus
%         each epoch presented (its stimgen generation record)
%     the spikes of each epoch from its event to the end of its stimulus
%         (epochSpikes: s from the event, on the clock of the spikes)
%     R = rippleStrf(spikes, S.records, S.index, sets, ...) with the
%         panel's rate, maxLag, skip, sigAlpha, rtfPad, crhBins and crhLag;
%         sets = the trial groups (options.split "groups": G's labels) or
%         the bank items (split "item": S.itemNames)
%   An epoch whose stimulus runs past the end of the recording, or (the
%   selection's excludeArtifacts) over an artifact period at least
%   minArtifactSec long, is left out: the time analyzed would count time
%   with no spikes recorded. The panel's window is not read: each
%   presentation is analyzed over its own stimulus.
%   R: rippleStrf's, with stimulus (S without its records: file, source,
%   check, dropped, kinds, itemNames), nIncomplete and nArtifact (epochs
%   left out so), names (the layer's units), layer, dataset and epochs.
%   A further enabled layer is skipped ("An STRF panel draws its first
%   enabled layer only"). What the dataset or the stimulus file lacks
%   (figureLayerError: no stimulus file, a log that does not match the
%   line, no stimgen, settings rippleStrf refuses, no epoch with a TORC
%   or DMR: rippleStrf:NoStimulus) skips the layer with the reason.
%   options.view, showSig, contour, crhScale, stats, cLim, group, stack
%   and stackSpacing are the draw function's.
%
%   See also figurePanelRegistry, rippleStimuli, rippleStrf, drawStrfPanel.
o = panel.options;
P = struct('layers', figurePanelLayers(panel, ctx.skips));
mapped = false;
for j = 1:numel(P.layers)
    if P.layers(j).skip == "disabled"; continue; end
    if mapped
        if P.layers(j).skip == ""; P.layers(j).skip = "An STRF panel draws its first enabled layer only"; end
        continue
    end
    mapped = true;
    if P.layers(j).skip ~= ""; continue; end
    L = panel.layers(j);
    lay = P.layers(j);
    ctx.checkpoint();
    it = figureLayerItems(L, ctx.observation, ctx.observe, []);
    if it.skip ~= ""; P.layers(j).skip = it.skip; continue; end
    try
        [st, meta] = selectUnits(src, it.units, Ref=ctx.ref, Selection=ctx.selection);
        S = rippleStimuli(src, E, ctx.ref, o.stim);
        R = analyze(src, E, G, S, st, o, ctx);
    catch ME
        P.layers(j).skip = figureLayerError(ME);
        continue
    end
    R.names = string(meta.label(:)).';
    R.layer = j;
    R.dataset = src.name;
    R.epochs = E;
    lay.R = R;
    lay.meta = meta;
    if lay.name == ""; lay.name = figureUnitsName(meta, L); end
    P.layers(j) = lay;
end
end


function R = analyze(src, E, G, S, st, o, ctx)
%analyze  Each used epoch's spikes over its stimulus, its set, and rippleStrf over them.
idx = S.index;
D = NaN(height(E), 1);
for e = find(isfinite(idx)).'
    r = S.records{idx(e)};
    D(e) = double(r.N) / double(r.Fs);
end
t0c = double(E.t0Continuous(:));
nIncomplete = 0;
if isfield(src, 'durationSec') && isfinite(src.durationSec)
    bad = isfinite(idx) & t0c + D > src.durationSec + 1e-9;
    nIncomplete = nnz(bad);
    idx(bad) = NaN;
end
nArtifact = 0;
sel = trialSelection(ctx.selection);
if sel.excludeArtifacts && isfield(src, 'artifacts') && ~isempty(src.artifacts)
    art = src.artifacts(src.artifacts(:, 2) - src.artifacts(:, 1) >= sel.minArtifactSec, :);
    if ~isempty(art)
        u = find(isfinite(idx));
        hit = EphysDataset.overlapsIntervals(t0c(u), t0c(u) + D(u), art);
        nArtifact = nnz(hit);
        idx(u(hit)) = NaN;
    end
end
if ~any(isfinite(idx))
    d = S.dropped;
    error('rippleStrf:NoStimulus', ['No epoch presented a TORC or DMR it can be analyzed with (%d epochs: %d not matched to a ' ...
        'presentation, %d of another item, %d not a TORC or DMR, %d without a record, %d without a variant value, %d past ' ...
        'the recording''s end, %d over an artifact period).'], height(E), d.noPresentation, d.otherItem, d.notRipple, ...
        d.noRecord, d.noValue, nIncomplete, nArtifact);
end

% the pooled spikes of each used epoch, from its event to its stimulus's end
pooled = sort(vertcat(zeros(0, 1), st{:}));
u = find(isfinite(idx));
Eu = E(u, :);
Eu.tStart = double(Eu.t0);
Eu.tStop = double(Eu.t0) + D(u);
spk = epochSpikes(pooled, Eu);

switch o.split
    case "item"
        sets = S.item(u);
        labels = S.itemNames;
    otherwise
        sets = double(E.groupIndex(u));
        labels = string(G.label(:)).';
end
R = rippleStrf(spk(:, 1), S.records, idx(u), sets, SetLabels=labels, Rate=o.rate, MaxLag=o.maxLag, ...
    Skip=o.skip, Alpha=o.sigAlpha, RtfPad=o.rtfPad, CrhBins=o.crhBins, CrhLag=o.crhLag, Check=ctx.check);
R.stimulus = rmfield(S, 'records');
R.nIncomplete = nIncomplete;
R.nArtifact = nArtifact;
end
