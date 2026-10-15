function P = computeSpectrumPanel(src, panel, E, G, ctx)
%computeSpectrumPanel  A figure's power spectrum panel: each layer's multitaper spectra (Chronux).
%   P = computeSpectrumPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "spectrum"; CTX from EphysAnalysisRunner.computeFigure) has
%   P.layers, one per layer of PANEL (figurePanelLayers). Each enabled
%   layer is read by figureChronuxLayer (the observed unit's channel or
%   the observed unit, or the fixed channels / units) and analyzed with
%   the settings figureChronuxSettings builds from the panel's options
%   (window = the panel's [pre post]) over the trials chronuxTimeBaseOf
%   gives (the panel's epochs E and groups G, or with timeBase "range"
%   segments of the recording clear of its artifact periods):
%     LFP / MUA / SPIKE / AUX   chronuxSpectrum (D: the layer's columns)
%     units / detected          chronuxSpikeSpectrum (SP: the layer's trains)
%   R is the chronux function's result (f, S [nF x nItems x nGroups], Slo /
%   Shi, labels, nTrials, groups, units; a spike spectrum's rate) with
%   names (the items' names), layer (its index), epochs (E) and dataset. A
%   missing Chronux ("Chronux is not on the path"), no trial left, or
%   settings chronuxSettings refuses skip the layer with the reason
%   (figureLayerError). options.scale and yLim are the draw function's.
%
%   See also figurePanelRegistry, chronuxSpectrum, chronuxSpikeSpectrum, drawSpectrumPanel.
o = panel.options;
w = panel.window;
P = struct('layers', figurePanelLayers(panel, ctx.skips));
for j = 1:numel(P.layers)
    if P.layers(j).skip ~= ""; continue; end
    [X, lay] = figureChronuxLayer(src, panel.layers(j), P.layers(j), ctx);
    if lay.skip ~= ""; P.layers(j) = lay; continue; end
    try
        if X.kind == "signal"
            S = figureChronuxSettings("spectrum", o, [w.pre w.post], "spectrum");
            TB = chronuxTimeBaseOf(src, E, G, panel, Fs=X.D.fs, NRows=X.nRows);
            R = chronuxSpectrum(X.D, TB, S, Check=ctx.check, Dataset=src.name);
        else
            S = figureChronuxSettings("spectrum", o, [w.pre w.post], "spikeSpectrum");
            TB = chronuxTimeBaseOf(src, E, G, panel, LastSpike=X.lastSpike);
            R = chronuxSpikeSpectrum(X.SP, TB, S, Check=ctx.check, Dataset=src.name);
        end
    catch ME
        lay.skip = figureLayerError(ME);
        P.layers(j) = lay;
        continue
    end
    R.names = X.names;
    R.layer = j;
    R.epochs = E;
    R.dataset = src.name;
    lay.R = R;
    P.layers(j) = lay;
end
end
