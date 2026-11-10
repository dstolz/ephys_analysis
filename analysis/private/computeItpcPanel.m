function P = computeItpcPanel(src, panel, E, G, ctx)
%computeItpcPanel  A figure's phase coherence panel: the inter-trial phase coherence (ITPC) of a signal over the epochs.
%   P = computeItpcPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "itpc"; CTX from EphysAnalysisRunner.computeFigure) has
%   P.layers, one per layer of PANEL (figurePanelLayers). The first
%   enabled layer is read by figureChronuxLayer (LFP, MUA, SPIKE or AUX:
%   its channels, or with aggregate "magnitude" their vector magnitude as
%   one item) and analyzed by phaseCoherence over the panel's epochs E and
%   every trial group G (chronuxTimeBaseOf), with the settings
%   figureChronuxSettings builds from the panel's options (the tapers,
%   fpass, detrend, err / errP, overTime, the moving window), at most
%   2000 MB:
%     overTime false   each channel's ITPC by frequency over the whole
%                      window (R.C [nF x nCh x nG], the jackknife bars
%                      R.Clo / R.Chi, the level of random phases R.confC)
%     overTime true    the ITPC over the moving window (R.t, R.C [nT x nF
%                      x nCh x nG]): drawn as an image of the first channel
%   R: phaseCoherence's with names (each item's: "LFP ch 12"), filters (the
%   filters the signal was read through, 1x0 for none), layer, epochs and
%   dataset. A further enabled layer is skipped ("A phase coherence panel
%   draws its first enabled layer only"). Data the dataset lacks, a moving
%   window longer than the epoch (phaseCoherence:Short), no frequency in
%   fpass (phaseCoherence:Fpass), a result over the limit
%   (phaseCoherence:TooLarge) or settings chronuxSettings refuses skip the
%   layer with the reason. options.group, stack, stackSpacing, freqScale,
%   yLimMode, yLim, cLim and band are the draw function's.
%
%   See also figurePanelRegistry, phaseCoherence, drawItpcPanel.
maxMB = 2000;   % the result's limit
o = panel.options;
w = panel.window;
P = struct('layers', figurePanelLayers(panel, ctx.skips));
mapped = false;
for j = 1:numel(P.layers)
    if P.layers(j).skip == "disabled"; continue; end
    if mapped
        if P.layers(j).skip == ""; P.layers(j).skip = "A phase coherence panel draws its first enabled layer only"; end
        continue
    end
    mapped = true;
    if P.layers(j).skip ~= ""; continue; end
    [X, lay] = figureChronuxLayer(src, panel.layers(j), P.layers(j), ctx);
    if lay.skip ~= ""; P.layers(j) = lay; continue; end
    if X.kind ~= "signal"
        lay.skip = "A phase coherence panel draws a signal (LFP, MUA, SPIKE or AUX)";
        P.layers(j) = lay;
        continue
    end
    try
        TB = chronuxTimeBaseOf(src, E, G, panel);
        S = figureChronuxSettings("itpc", o, [w.pre w.post]);
        R = phaseCoherence(X.D, TB, S, Check=ctx.check, MaxMB=maxMB, Dataset=src.name);
    catch ME
        lay.skip = figureLayerError(ME);
        P.layers(j) = lay;
        continue
    end
    R.names = X.names;
    R.filters = X.filters;   % the filters the signal was read through (1x0: none)
    R.layer = j;
    R.epochs = E;
    R.dataset = src.name;
    lay.R = R;
    P.layers(j) = lay;
end
end
