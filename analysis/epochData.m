function D = epochData(src, spec, opts)
%epochData  One dataset's epoched data, organized for analysis outside the app.
%   D = epochData(SRC, SPEC) aligns the dataset SRC (loadAnalysisSource) as
%   the plot SPEC (EphysAnalysisConfig plotFor / sessionPlotFor: the
%   effective spec, with its event, window, trial selection and sources
%   filled in) says and returns, for a spike source, every selected unit's
%   spike times and binned counts per epoch, and for a signal source (with
%   Signals=true) the epoched samples. Nothing is averaged. The epochs,
%   units and channels are the ones the plot draws (epochTable,
%   selectUnits, selectChannels). Pure: reads through SRC, no graphics.
%
%   D fields
%     identity  struct: key, name, label (the name; the runner puts the
%               session label here), folder, subject (the behavior's, "" when
%               unknown), date (the recording's start, NaT when unknown), fs
%               (recording rate, Hz), durationSec
%     spec      SPEC
%     E, G      epochTable's result for SPEC: one row per epoch (epoch, trial,
%               t0, t0Continuous, t1, tStart, tStop, duration, complete,
%               artifact, groupIndex, group, then the trial columns the
%               grouping and the plot use: the groupBy parameters, a tuning
%               or behavior plot's param, seriesParam and yParam, a raster's
%               sort parameter) and the groups table; E.Properties.UserData
%               is kept (ref, window, selection, the dropped counts, ...)
%     meta      the units' table (selectUnits: label, unitId, class, channel,
%               channelName, shank, x, y, nSpikes) for a spike source, the
%               channels' (selectChannels) for a signal source read with
%               Signals=true; an empty table otherwise
%     spikes    (spike source with Spikes=true, else [])
%       times   {nEpochs x nUnits}: each unit's spike times in each epoch,
%               seconds relative to the epoch's event (E.t0Continuous, the
%               event on the clock of the spikes, so a spike in the event's
%               own sample is at 0), inside [pre post) and sorted; with a
%               window that ends at a stop event ("between") inside each
%               epoch's own window, no stop masking. Column vectors
%       counts  [nEpochs x nBins x nUnits] spikes per bin (binCounts, double):
%               the half-open bins spikePSTH uses, whole multiples of BinSec
%               from the event, so counts(e, :, u) equals the PSTH's count of
%               epoch e. [nEpochs x 0 x nUnits] with Counts=false or a
%               window that holds no whole bin
%       edges   the bins' edges, s relative to the event (row); t their
%               centers (column); binSec; window = [pre post] the times lie
%               in; binWindow = edges([1 end])
%     signals   (signal source with Signals=true, else [])
%       data    [nTime x nChannel x nKept] single, microvolts (AUX: volts), the
%               kept epochs' samples as evokedPotential(KeepEpochs=true) cuts
%               them, baseline not subtracted
%       dims    "time x channel x epoch": the order evokedPotential keeps
%               them in, so no copy is made
%       t, fs   the sample times relative to the event (column, s) and rate
%       epochs  the rows of E that are kept (epochs that leave the recording
%               or hold a non-finite sample are dropped)
%       channels, labels, units   the columns of the signal used, their labels,
%               the unit of data
%       sampleOffsets, droppedEdge, droppedNonFinite   as in evokedPotential
%     created, provenance   when and by which code (ephysProvenance)
%
%   Options
%     Signals     true: cut the epochs of a signal source (default false)
%     Spikes      false: leave the spike source out (default true)
%     Counts      false: times only, no binned counts (default true)
%     MaxMB       epochData:TooLarge, before anything is cut, when the epoched
%                 samples (nTime*nChannel*nEpochs*4 bytes) or the counts
%                 (nEpochs*nBins*nUnits*8 bytes) would take more (default 1024)
%     Check       a function handle called before each unit and every 16th
%                 epoch of the signal; it may throw to stop (default [])
%     Provenance  ephysProvenance() to store (default: made here)
%
%   A source that is neither (behavior plots read "trials") gets E and G
%   only. Errors: epochData:TooLarge, and epochTable's, selectUnits' and
%   selectChannels'.
%
%   See also epochTable, selectUnits, selectChannels, evokedPotential,
%   binCounts, epochLongTable, sessionData.

arguments
    src (1,1) struct
    spec (1,1) struct
    opts.Signals (1,1) logical = false
    opts.Spikes (1,1) logical = true
    opts.Counts (1,1) logical = true
    opts.MaxMB (1,1) double {mustBePositive} = 1024
    opts.Check = []
    opts.Provenance = []
end

w = spec.window;
b = [];
if spec.baseline.Mode ~= "none"; b = spec.baseline.Window; end
cols = trialColumns(spec);
if spec.kind == "behavior"
    % every event's epoch: the window and the signals' artifact periods do not concern behavior (computePlot)
    [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection, Columns=cols, Incomplete="keep", Artifacts="keep");
else
    [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection, Baseline=b, Columns=cols);
end
nE = height(E);

D = struct();
D.identity = struct('key', string(src.key), 'name', string(src.name), 'label', string(src.name), ...
    'folder', string(src.folder), 'subject', string(src.subject), 'date', src.startTime, ...
    'fs', src.fs, 'durationSec', src.durationSec);
D.spec = spec;
D.E = E;
D.G = G;
D.meta = table();
D.spikes = [];
D.signals = [];

limit = opts.MaxMB * 2^20;
if ismember(spec.source, EphysAnalysisConfig.SpikeSources) && opts.Spikes
    [st, meta] = selectUnits(src, spec.units, Ref=spec.ref, Selection=spec.selection);
    D.meta = meta;
    D.spikes = spikeData(st, E, w, spec.bins.BinSec, opts.Counts, limit, opts.Check);
elseif ismember(spec.source, EphysAnalysisConfig.SignalSources) && opts.Signals
    [Y, fs, meta] = selectChannels(src, spec.source, Channels=spec.channels);
    D.meta = meta;
    s0 = round(w.pre * fs);
    s1 = round(w.post * fs);
    nT = s1 - s0 + 1;
    bytes = nT * height(meta) * nE * 4;
    if bytes > limit
        error('epochData:TooLarge', ['%s: the epoched %s (%d samples x %d channels x %d epochs, single) would take about %.0f MB; ' ...
            'the limit is %.0f MB (MaxMB).'], src.name, spec.source, nT, height(meta), nE, bytes / 2^20, opts.MaxMB);
    end
    Rv = evokedPotential(Y, fs, E, Window=[w.pre w.post], Groups=G, Meta=meta, Units=meta.units(1), ...
        Check=opts.Check, KeepEpochs=true);
    D.signals = struct('data', Rv.data, 'dims', "time x channel x epoch", 't', Rv.t, 'fs', fs, ...
        'epochs', E(ismember(E.epoch, Rv.keptEpochs), :), 'channels', Rv.channels, 'labels', Rv.channelLabels, ...
        'units', meta.units(1), 'sampleOffsets', Rv.sampleOffsets, 'droppedEdge', Rv.droppedEdge, ...
        'droppedNonFinite', Rv.droppedNonFinite);
end
D.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
if isempty(opts.Provenance)
    D.provenance = ephysProvenance();
else
    D.provenance = opts.Provenance;
end
end


function cols = trialColumns(spec)
%trialColumns  The trial parameters beyond the grouping that the plot reads (computePlot's Columns).
cols = string.empty(1, 0);
switch spec.kind
    case {"psth" "raster"}
        if ~ismember(spec.rasterSort, ["" "stop" "event"]); cols = spec.rasterSort; end
    case "tuning"
        cols = [spec.param spec.seriesParam];
    case "behavior"
        cols = [spec.param spec.seriesParam];
        if spec.yParam ~= "stop"; cols(end+1) = spec.yParam; end
end
cols = unique(cols(cols ~= ""), 'stable');
end


function S = spikeData(st, E, w, bin, withCounts, limit, check)
%spikeData  Each unit's spike times and binned counts around each epoch's event.
nE = height(E);
nU = numel(st);
edges = (ceil(w.pre / bin - 1e-9) : floor(w.post / bin + 1e-9)) * bin;   % spikePSTH's bins: whole multiples, an edge at the event
nB = numel(edges) - 1;
if nB < 1 || ~withCounts
    nB = 0;
end
bytes = nE * nB * nU * 8;
if bytes > limit
    error('epochData:TooLarge', ['The spike counts (%d epochs x %d bins x %d units, double) would take about %.0f MB; ' ...
        'the limit is %.0f MB (MaxMB).'], nE, nB, nU, bytes / 2^20, limit / 2^20);
end
ta = E.t0Continuous;                  % the events on the spikes' clock
winEnd = E.tStop - E.t0;              % each epoch's window end, relative to its event
hi = w.post;
if w.mode == "between"
    hi = max(winEnd(isfinite(winEnd)));
    if isempty(hi); hi = w.post; end
end
times = cell(nE, nU);
counts = zeros(nE, nB, nU);
for u = 1:nU
    if ~isempty(check); check(); end
    [~, rel, ep] = binCounts(st{u}, ta, [w.pre hi]);
    if w.mode == "between"
        keep = rel < winEnd(ep) - 1e-9;
        rel = rel(keep);
        ep = ep(keep);
    end
    times(:, u) = mat2cell(rel, accumarray(ep, 1, [nE 1]), 1);
    if nB > 0
        counts(:, :, u) = binCounts(st{u}, ta, edges).';
    end
end
if nB > 0
    t = (edges(1:end-1) + edges(2:end)).' / 2;
    binWindow = edges([1 end]);
else
    edges = zeros(1, 0);
    t = zeros(0, 1);
    binWindow = zeros(1, 0);
end
S = struct('times', {times}, 'counts', counts, 'edges', edges, 't', t, 'binSec', bin, ...
    'window', [w.pre hi], 'binWindow', binWindow);
end
