function [data, params, t, info] = spikeTrials(obj, onsets, twin, opts)
%spikeTrials  Event-aligned spike times, one Chronux trial per onset.
%   [DATA, PARAMS, T] = cx.spikeTrials(ONSETS, TWIN) cuts one unit's spike
%   train into one trial per onset and returns DATA as a 1 x nTrials struct
%   array with field times. Chronux's point-process routines treat that
%   dimension as trials, so with params.trialave = 1 (TrialAve=1) mtspectrumpt
%   averages over trials:
%
%     [sp, params, t] = cx.spikeTrials(onsets, [-0.2 0.5], TrialAve=1);
%     [S, f, R] = mtspectrumpt(sp, params, 0, t);      % Chronux
%
%     ONSETS  event times in seconds, recording-relative (see eventOnsets)
%     TWIN    [tPre tPost] seconds relative to the onset, tPre usually
%             negative (default [-0.2 0.5]). Chronux's createdatamatpt takes
%             the same window as [-tPre tPost], both positive.
%
%   Which spikes land in a trial, and with what time stamp
%   ------------------------------------------------------
%   Trial i keeps the spikes with t > E(i)+tPre and t <= E(i)+tPost - the
%   half-open interval createdatamatpt uses, so a spike exactly on the window
%   edge is counted once across abutting windows. TimeBase sets the stamps:
%     "window"   (default) t - E - tPre, i.e. 0 at the start of the window,
%                spanning [0, tPost-tPre]. This is what createdatamatpt
%                returns, and what T is built for
%     "onset"    t - E, spanning [tPre, tPost] (0 at the event)
%     "absolute" untouched recording-relative times. There is no common time
%                grid for that, so T is returned empty; it is for bookkeeping
%                and plotting, not for handing to Chronux
%
%   One unit per call, because the struct dimension is trials. Use Unit= to
%   pick it when the source holds several.
%
%   Options
%   -------
%     Unit        which unit to epoch (cluster id for Kilosort, channel index
%                 for detected/supplied trains); required when the source has
%                 more than one
%     TimeBase    "window" (default) | "onset" | "absolute", above
%     Incomplete  "drop" (default, with a warning) or "keep" for trials whose
%                 window is not entirely inside the recording. A truncated
%                 window holds fewer spikes than it should, which biases both
%                 the rate and the spectrum
%     Spikes      a struct array from cx.spikes to epoch instead of reading the
%                 source again (unit selection is then by index)
%     Source, Times, ResultsDir, Units, Groups, DetectOptions   forwarded to
%                 ChronuxDataset.spikes when Spikes is not given
%     SpikeFs     grid rate for T and params.Fs (default: the SpikeFs property)
%     Tapers, Pad, Fpass, Err, TrialAve   per-call params overrides
%
%   INFO: unitId, label, twin, timeBase, nTrials, keptTrials (indices into
%   ONSETS), onsets of the kept trials, droppedIncomplete, counts per trial,
%   rate (mean count / window length), recordingRange, spikeFs, source.
%
%   See also ChronuxDataset.spikes, ChronuxDataset.trials,
%   ChronuxDataset.binnedSpikes.

arguments
    obj (1,1) ChronuxDataset
    onsets double {mustBeFinite}
    twin (1,2) double {mustBeFinite} = [-0.2 0.5]
    opts.Unit double = []
    opts.TimeBase (1,1) string {mustBeMember(opts.TimeBase, ...
        ["window","onset","absolute"])} = "window"
    opts.Incomplete (1,1) string {mustBeMember(opts.Incomplete, ...
        ["drop","keep"])} = "drop"
    opts.Spikes = []
    opts.Source (1,1) string = "auto"
    opts.Times = []
    opts.ResultsDir (1,1) string = ""
    opts.Units = []
    opts.Groups (1,:) string = string.empty(1,0)
    opts.DetectOptions struct = struct()
    opts.SpikeFs (1,1) double = NaN
    opts.Tapers (1,:) double = double.empty(1,0)
    opts.Pad double = []
    opts.Fpass (1,:) double = double.empty(1,0)
    opts.Err (1,:) double = double.empty(1,0)
    opts.TrialAve double = []
end

onsets = onsets(:);
if isempty(onsets)
    error('ChronuxDataset:NoOnsets', 'ONSETS is empty; nothing to epoch.');
end
if twin(2) <= twin(1)
    error('ChronuxDataset:BadWindow', ...
        'TWIN must be [tPre tPost] with tPre < tPost; got [%g %g].', twin(1), twin(2));
end

% --- the unit's spike train, over the whole recording -------------------
if isempty(opts.Spikes)
    [S, ~, ~, sinfo] = obj.spikes(Source=opts.Source, Times=opts.Times, ...
        ResultsDir=opts.ResultsDir, Units=opts.Units, Groups=opts.Groups, ...
        DetectOptions=opts.DetectOptions, SpikeFs=opts.SpikeFs);
    unitIds = sinfo.unitIds;
    labels  = sinfo.labels;
    recRange = sinfo.timeRange;
    srcTxt   = sinfo.source;
else
    S = ChronuxDataset.toPointProcess(opts.Spikes);
    unitIds = 1:numel(S);
    labels  = "unit" + string(unitIds);
    recRange = [-Inf Inf];
    if ~isempty(obj.Dataset) && ~isnan(obj.Dataset.Duration)
        recRange = [0 obj.Dataset.Duration];
    elseif obj.Loaded && ~isempty(obj.Data) && ~isnan(obj.Fs)
        recRange = [0 size(obj.Data, 1) / obj.Fs];
    end
    srcTxt = "Spikes";
end

if isempty(opts.Unit)
    if numel(S) ~= 1
        error('ChronuxDataset:UnitRequired', ...
            ['spikeTrials epochs one unit at a time (the struct dimension is ' ...
             'trials); pass Unit= one of: %s.'], strjoin(string(unitIds), ', '));
    end
    u = 1;
else
    u = find(unitIds == opts.Unit, 1);
    if isempty(u)
        error('ChronuxDataset:UnknownUnit', ...
            'No unit %g in this spike source (have: %s).', opts.Unit, ...
            strjoin(string(unitIds), ', '));
    end
end
times = S(u).times;

% --- trials whose window is not fully inside the recording --------------
inside = true(numel(onsets), 1);
if all(isfinite(recRange))
    inside = (onsets + twin(1)) >= recRange(1) & (onsets + twin(2)) <= recRange(2);
end
droppedIncomplete = reshape(find(~inside), 1, []);
keepTrial = true(numel(onsets), 1);
if opts.Incomplete == "drop"
    keepTrial = inside;
    if any(~inside)
        warning('ChronuxDataset:IncompleteTrials', ...
            ['%d of %d trial windows extend past the recording [%g %g] s and were ' ...
             'dropped (Incomplete="keep" returns them, with the spikes that do ' ...
             'exist).'], nnz(~inside), numel(inside), recRange(1), recRange(2));
    end
end
if ~any(keepTrial)
    error('ChronuxDataset:NoTrials', ...
        'No trial window fits inside the recording [%g %g] s.', recRange(1), recRange(2));
end
kept = reshape(find(keepTrial), 1, []);
E = onsets(keepTrial);
nTrials = numel(E);

% --- epoch (the createdatamatpt selection rule) -------------------------
data = struct('times', cell(1, nTrials));
counts = zeros(1, nTrials);
for k = 1:nTrials
    v = times(times > E(k) + twin(1) & times <= E(k) + twin(2));
    switch opts.TimeBase
        case "window",   v = v - E(k) - twin(1);
        case "onset",    v = v - E(k);
        case "absolute"  % untouched
    end
    data(k).times = v;
    counts(k) = numel(v);
end

spikeFs = opts.SpikeFs;
if isnan(spikeFs); spikeFs = obj.SpikeFs; end
switch opts.TimeBase
    case "window",   t = 0:(1/spikeFs):(twin(2) - twin(1));
    case "onset",    t = twin(1):(1/spikeFs):twin(2);
    case "absolute", t = [];
end

params = obj.params(Fs=spikeFs, Tapers=opts.Tapers, Pad=opts.Pad, ...
    Fpass=opts.Fpass, Err=opts.Err, TrialAve=opts.TrialAve);

info = struct();
info.source            = srcTxt;
info.unitId            = unitIds(u);
info.label             = labels(u);
info.twin              = twin;
info.timeBase          = opts.TimeBase;
info.nTrials           = nTrials;
info.keptTrials        = kept;
info.onsets            = reshape(E, 1, []);
info.droppedIncomplete = droppedIncomplete;
info.counts            = counts;
info.rate              = mean(counts) / (twin(2) - twin(1));
info.recordingRange    = recRange;
info.spikeFs           = spikeFs;
info.nGridPoints       = numel(t);
end
