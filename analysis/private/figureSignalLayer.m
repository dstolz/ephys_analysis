function lay = figureSignalLayer(src, L, lay, E, G, ctx, opts)
%figureSignalLayer  One continuous layer of a continuous or heat map panel: LFP, MUA, SPIKE or AUX channels.
%   LAY = figureSignalLayer(SRC, L, LAY, E, G, CTX, Name=Value) computes the
%   layer L (figureFor's spec) of a panel over its epochs E and groups G
%   (epochTable) for the dataset SRC and fills LAY (figurePanelLayers'
%   entry for it): R, meta, name ("" = automatic) and skip.
%   [Y, fs, metaAll] = selectChannels(src, L.source, Channels=[]) takes the
%   extract as cached (no copy); figureLayerItems picks its columns for
%   CTX.observation (the observed unit's recording channel, the observed
%   channel, or the fixed L.channels); then
%     R = evokedPotential(Y, fs, E, Window=, Channels=cols, Baseline=,
%         Groups=G, Meta=metaAll(cols,:), Units=, Check=CTX.check,
%         Rectify=, Statistic=, ErrorType=CTX.errorType, ErrorResamples=)
%   reads only those columns' epochs. aggregate "mean" adds R.layerMean
%   (figureLayerMean: the mean over the channels, a band across them). R
%   also gets epochs (E) and dataset. A missing extract, a channel it
%   lacks or a baseline with no sample in the window skips the layer with
%   the reason; EphysAnalysisRunner:Canceled passes through.
%
%   Options: Window [pre post], Baseline ([] or [b0 b1]: subtract each
%   epoch's mean over it), Rectify, Statistic ("mean" | "median"),
%   KeepEpochs (false: true keeps the epochs' traces, as averaged --
%   baseline and rectification applied -- in R.data [nTime x nChannels x
%   nTrials] single, with R.trialEpochs (their epoch numbers) and
%   R.trialGroup (their group, a row of G)) and MaxTrials (Inf: with
%   KeepEpochs, at most this many epochs kept, picked evenly over their
%   order).
%
%   See also EphysAnalysisRunner.computeFigure, figureLayerItems, evokedPotential.

arguments
    src (1,1) struct
    L (1,1) struct
    lay (1,1) struct
    E table
    G table
    ctx (1,1) struct
    opts.Window (1,2) double
    opts.Baseline double = []
    opts.Rectify (1,1) logical = false
    opts.Statistic (1,1) string = "mean"
    opts.KeepEpochs (1,1) logical = false
    opts.MaxTrials (1,1) double = Inf
end

ctx.checkpoint();
try
    [Y, fs, metaAll] = selectChannels(src, L.source, Channels=[]);   % every column in order: the cached signal itself
catch ME
    lay.skip = figureLayerError(ME);
    return
end
it = figureLayerItems(L, ctx.observation, ctx.observe, metaAll);
if it.skip ~= ""; lay.skip = it.skip; return; end
nCh = height(metaAll);
cols = reshape(double(it.columns), 1, []);
if isempty(cols); cols = 1:nCh; end
if any(cols < 1 | cols > nCh | cols ~= round(cols))
    lay.skip = sprintf("the %s extract has %d channel(s); the layer asks for %s", L.source, nCh, mat2str(cols));
    return
end
metaC = metaAll(cols, :);
ctx.checkpoint();
try
    R = evokedPotential(Y, fs, E, Window=opts.Window, Channels=cols, Baseline=opts.Baseline, Groups=G, Meta=metaC, ...
        Units=metaC.units(1), Check=ctx.check, Rectify=opts.Rectify, Statistic=opts.Statistic, ...
        ErrorType=ctx.errorType, ErrorResamples=ctx.nBoot, KeepEpochs=opts.KeepEpochs);
catch ME
    lay.skip = figureLayerError(ME);   % e.g. a baseline with no sample in the window; a cancel passes through
    return
end
if opts.KeepEpochs   % the epochs' traces: at most MaxTrials of them, picked evenly over their order
    [~, rowOf] = ismember(R.keptEpochs(:), E.epoch);
    nK = size(R.data, 3);
    pick = 1:nK;
    if nK > opts.MaxTrials
        pick = unique(round(linspace(1, nK, opts.MaxTrials)));
    end
    R.data = R.data(:, :, pick);
    R.trialEpochs = reshape(R.keptEpochs(pick), [], 1);
    R.trialGroup = reshape(E.groupIndex(rowOf(pick)), [], 1);
end
R.epochs = E;
R.dataset = src.name;
if L.aggregate == "mean"
    R.layerMean = figureLayerMean(R.mean, R.t, ctx.errorType, ctx.nBoot, "channels");
end
lay.R = R;
lay.meta = metaC;
if lay.name == ""
    if isscalar(cols)
        rc = metaC.recordingChannel(1);
        if isfinite(rc)
            lay.name = L.source + " ch " + rc;
        else
            lay.name = L.source + " " + metaC.label(1);
        end
    elseif L.aggregate == "mean"
        lay.name = "mean of " + numel(cols) + " " + L.source + " channels";
    else
        lay.name = L.source + " (" + numel(cols) + " channels)";
    end
end
end
