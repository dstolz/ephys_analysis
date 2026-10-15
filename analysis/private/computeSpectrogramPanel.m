function P = computeSpectrogramPanel(src, panel, E, G, ctx)
%computeSpectrogramPanel  A figure's spectrogram panel: one channel's multitaper power over time from the event (Chronux).
%   P = computeSpectrogramPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "spectrogram"; CTX from EphysAnalysisRunner.computeFigure)
%   has P.layers, one per layer of PANEL (figurePanelLayers). The first
%   enabled layer that is not events marks is the image: a signal layer
%   read by figureChronuxLayer, its first column analyzed by
%   chronuxSpecgram over the panel's epochs E (every trial group G; the
%   settings from figureChronuxSettings: tapers, fpass, detrend, the
%   moving window, the baseline Mode / Window), at most 2000 MB.
%   R: chronuxSpecgram's (t [nT x 1] s from the event, f, S [nT x nF x 1 x
%   nGroups], baseline, units, groups, nTrials) with names, layer, epochs
%   and dataset. A further map layer is skipped ("A spectrogram draws its
%   first enabled layer only"); events marks are computed as latency lines
%   (figurePointLayer). A missing Chronux, a moving window longer than the
%   epoch (chronuxSpecgram:Short), a result over the limit
%   (chronuxSpecgram:TooLarge) or settings chronuxSettings refuses skip the
%   layer with the reason. options.group, scale and cLim are the draw
%   function's.
%
%   See also figurePanelRegistry, chronuxSpecgram, drawSpectrogramPanel.
maxMB = 2000;   % the result's limit (the Chronux tab's ChronuxMaxMB is the app's own)
o = panel.options;
w = panel.window;
P = struct('layers', figurePanelLayers(panel, ctx.skips));
mapped = false;
for j = 1:numel(P.layers)
    if P.layers(j).skip == "disabled"; continue; end
    L = panel.layers(j);
    isMarks = L.source == "events";
    if ~isMarks
        if mapped
            P.layers(j).skip = "A spectrogram draws its first enabled layer only";
            continue
        end
        mapped = true;
    end
    if P.layers(j).skip ~= ""; continue; end
    if isMarks
        P.layers(j) = figurePointLayer(src, L, P.layers(j), E, G, ctx, Window=[w.pre w.post], Raster=false);
        continue
    end
    [X, lay] = figureChronuxLayer(src, L, P.layers(j), ctx);
    if lay.skip ~= ""; P.layers(j) = lay; continue; end
    if X.kind ~= "signal"
        lay.skip = "A spectrogram draws a signal (LFP, MUA, SPIKE or AUX)";
        P.layers(j) = lay;
        continue
    end
    D = X.D;   % its first channel only: one image
    D.data = D.data(:, 1);
    D.channels = 1;
    D.labels = D.labels(1);
    try
        S = figureChronuxSettings("spectrogram", o, [w.pre w.post]);
        TB = chronuxTimeBaseOf(src, E, G, panel);
        R = chronuxSpecgram(D, TB, S, Check=ctx.check, MaxMB=maxMB, Dataset=src.name);
    catch ME
        lay.skip = figureLayerError(ME);
        P.layers(j) = lay;
        continue
    end
    R.names = X.names(1);
    R.layer = j;
    R.epochs = E;
    R.dataset = src.name;
    lay.R = R;
    lay.meta = lay.meta(1, :);
    if numel(X.names) > 1 && L.name == ""; lay.name = X.names(1); end   % the channel drawn
    P.layers(j) = lay;
end
end
