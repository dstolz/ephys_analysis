function [data, params, t, info] = spikes(obj, opts)
%spikes  Spike times as a Chronux point-process struct array.
%   [DATA, PARAMS, T, INFO] = cx.spikes() returns DATA, a 1 x nUnits struct
%   array whose only field is times (a sorted column of seconds), the Chronux
%   params for it, and T, the time grid the analysis should run on. That is the
%   input form of mtspectrumpt, mtspecgrampt, coherencypt, coherencycpt, psth
%   and the rest of the point-process family:
%
%     [sp, params, t] = cx.spikes();
%     [S, f, R] = mtspectrumpt(sp, params, 0, t);      % Chronux
%
%   Pass T through. Left to itself, mtspectrumpt builds its grid from the first
%   and last spike in the data, so the rate it reports (R) and the taper grid
%   are set by when the neuron happened to fire; T here spans the analysis
%   window (the recording by default), which is what the rate should be
%   normalized by. T is sampled at SpikeFs, which is also params.Fs: for point
%   processes that rate is a property of the analysis grid, not of the data.
%
%   Where the spike times come from
%   -------------------------------
%     Source="kilosort"  spike_times.npy + spike_clusters.npy from a Kilosort4
%                        / phy results folder (ResultsDir, or the attached
%                        EphysDataset's kilosortResultsDir). Sample indices are
%                        divided by the sample rate in params.py, giving
%                        recording-relative seconds on the same clock as the
%                        continuous data. One struct element per cluster.
%     Source="detect"    EphysDataset.detectSpikes on the loaded continuous
%                        signal (one struct element per channel). Threshold
%                        crossing, not spike sorting.
%     Source="times"     spike times you already have: a numeric vector, a cell
%                        array of vectors, or a struct array with a times field.
%     Source="auto"      (default) "times" if Times is given, else "kilosort"
%                        when the dataset has results. Never runs detection on
%                        its own - ask for it with Source="detect".
%
%   Options
%   -------
%     Source, Times, ResultsDir  as above
%     Units       which units to keep, in that order: cluster ids for
%                 "kilosort", channel indices for "detect"/"times" ([] = all)
%     Groups      keep only clusters with these phy labels, e.g. ["good"] or
%                 ["good" "mua"]; read from cluster_group.tsv (curated) or
%                 cluster_KSLabel.tsv (Kilosort's own). "kilosort" only
%     DetectOptions  struct of EphysDataset.detectSpikes options ("detect")
%     TimeRange   [t0 t1] seconds to analyse (default: the whole recording).
%                 Spikes outside it are dropped and T spans it
%     TimeBase    "recording" (default) keeps recording-relative times, with T
%                 spanning [t0 t1]; "window" subtracts t0, so times and T start
%                 at 0. Use "window" for the hybrid routines (coherencycpt,
%                 coherencycpb): they build their grid as 0:1/Fs:(N-1)/Fs from
%                 the continuous data, so the spikes must be on that same
%                 zero-based clock, with params.Fs the continuous rate
%     SpikeFs     grid rate for T and params.Fs (default: the SpikeFs property)
%     Tapers, Pad, Fpass, Err, TrialAve   per-call params overrides
%
%   INFO: source, timeBase, gridRange (what T spans), unitIds, labels
%   ("unit<id>" / channel labels), groupLabels
%   (the phy "good"/"mua"/... label of each cluster, Kilosort source only),
%   counts, rates (count/(t1-t0)), nUnits, timeRange, timeRangeSource, spikeFs,
%   resultsDir, sampleRate (the rate the Kilosort sample indices were divided
%   by), groups, nDroppedOutsideRange.
%
%   See also ChronuxDataset.spikeTrials, ChronuxDataset.binnedSpikes,
%   EphysDataset.detectSpikes, ChronuxDataset.toPointProcess.

arguments
    obj (1,1) ChronuxDataset
    opts.Source (1,1) string {mustBeMember(opts.Source, ...
        ["auto","kilosort","detect","times"])} = "auto"
    opts.Times = []
    opts.ResultsDir (1,1) string = ""
    opts.Units = []
    opts.Groups (1,:) string = string.empty(1,0)
    opts.DetectOptions struct = struct()
    opts.TimeRange (1,2) double = [-Inf Inf]
    opts.TimeBase (1,1) string {mustBeMember(opts.TimeBase, ...
        ["recording","window"])} = "recording"
    opts.SpikeFs (1,1) double = NaN
    opts.Tapers (1,:) double = double.empty(1,0)
    opts.Pad double = []
    opts.Fpass (1,:) double = double.empty(1,0)
    opts.Err (1,:) double = double.empty(1,0)
    opts.TrialAve double = []
end

src = resolveSource(obj, opts);

info = struct();
info.source     = src;
info.resultsDir = "";
info.sampleRate = NaN;
info.groups     = opts.Groups;
groupLabels     = string.empty(1,0);   % phy labels, Kilosort source only

switch src
    case "times"
        data   = ChronuxDataset.toPointProcess(opts.Times);
        unitIds = 1:numel(data);
        labels  = "unit" + string(unitIds);

    case "kilosort"
        [data, unitIds, labels, ksInfo] = fromKilosort(obj, opts);
        info.resultsDir  = ksInfo.resultsDir;
        info.sampleRate  = ksInfo.sampleRate;
        groupLabels      = ksInfo.groupLabels;

    case "detect"
        [data, unitIds, labels] = fromDetect(obj, opts);
        info.sampleRate = obj.Fs;
end

% --- unit selection ----------------------------------------------------
if ~isempty(opts.Units)
    want = double(opts.Units(:)).';
    sel = zeros(1, numel(want));
    for k = 1:numel(want)
        hit = find(unitIds == want(k), 1);
        if isempty(hit)
            error('ChronuxDataset:UnknownUnit', ...
                'No unit %g in this spike source (have: %s).', want(k), ...
                strjoin(string(unitIds), ', '));
        end
        sel(k) = hit;
    end
    data    = data(sel);
    unitIds = unitIds(sel);
    labels  = labels(sel);
    if ~isempty(groupLabels); groupLabels = groupLabels(sel); end
end
if isempty(data)
    error('ChronuxDataset:NoUnits', 'No spike trains left after selection.');
end

% --- analysis window ---------------------------------------------------
[tr, trSource] = resolveSpikeTimeRange(obj, opts.TimeRange, data);
nDropped = 0;
for k = 1:numel(data)
    v = data(k).times;
    in = v >= tr(1) & v <= tr(2);
    nDropped = nDropped + nnz(~in);
    data(k).times = v(in);
end

if opts.TimeBase == "window"
    for k = 1:numel(data)
        data(k).times = data(k).times - tr(1);
    end
    gridRange = [0 tr(2) - tr(1)];
else
    gridRange = tr;
end

spikeFs = opts.SpikeFs;
if isnan(spikeFs); spikeFs = obj.SpikeFs; end
t = gridRange(1):(1/spikeFs):gridRange(2);   % grid for the prolates (see above)
if numel(t) > 1e7
    warning('ChronuxDataset:LargeGrid', ...
        ['The analysis grid has %d points (%g s at SpikeFs = %g Hz). Chronux ' ...
         'computes tapers over the whole grid with DPSS, so lower SpikeFs or ' ...
         'shorten TimeRange if that is more than memory allows.'], ...
        numel(t), gridRange(2) - gridRange(1), spikeFs);
end

params = obj.params(Fs=spikeFs, Tapers=opts.Tapers, Pad=opts.Pad, ...
    Fpass=opts.Fpass, Err=opts.Err, TrialAve=opts.TrialAve);

counts = arrayfun(@(s) numel(s.times), data);
info.unitIds         = unitIds;
info.labels          = labels;
info.groupLabels     = groupLabels;
info.counts          = counts;
info.rates           = counts / (tr(2) - tr(1));
info.nUnits          = numel(data);
info.timeRange       = tr;            % recording-relative, whatever TimeBase is
info.timeRangeSource = trSource;
info.timeBase        = opts.TimeBase;
info.gridRange       = gridRange;    % what T spans (and the spike times with it)
info.spikeFs         = spikeFs;
info.nGridPoints     = numel(t);
info.nDroppedOutsideRange = nDropped;
end


function src = resolveSource(obj, opts)
%resolveSource  Pick the spike source, without ever starting work implicitly.
if opts.Source ~= "auto"
    src = opts.Source;
    return
end
if ~isempty(opts.Times)
    src = "times";
    return
end
if opts.ResultsDir ~= "" || (~isempty(obj.Dataset) && obj.Dataset.hasKilosortResults())
    src = "kilosort";
    return
end
error('ChronuxDataset:NoSpikeSource', ...
    ['No spike times available: this connector has no Kilosort4 results. Pass ' ...
     'Times=..., ResultsDir=..., or Source="detect" to threshold the loaded ' ...
     'signal with EphysDataset.detectSpikes.']);
end


function [S, unitIds, labels, out] = fromKilosort(obj, opts)
%fromKilosort  Read spike_times/spike_clusters from a Kilosort4/phy folder.
dir0 = opts.ResultsDir;
if dir0 == ""
    if isempty(obj.Dataset)
        error('ChronuxDataset:NoResultsDir', ...
            'Source="kilosort" needs ResultsDir (no EphysDataset is attached).');
    end
    dir0 = string(obj.Dataset.kilosortResultsDir());
end
if ~isfolder(dir0)
    error('ChronuxDataset:NoResultsDir', 'Not a folder: %s', dir0);
end
fTimes = fullfile(dir0, 'spike_times.npy');
fClu   = fullfile(dir0, 'spike_clusters.npy');
for f = [fTimes fClu]
    if ~isfile(f)
        error('ChronuxDataset:NoKilosortOutput', ...
            'No Kilosort4 output in %s (missing %s).', dir0, f);
    end
end

fs = readPhySampleRate(dir0);
if isnan(fs)
    if ~isempty(obj.Dataset) && ~isnan(obj.Dataset.Fs)
        fs = obj.Dataset.Fs;
        warning('ChronuxDataset:NoParamsPy', ...
            ['No sample_rate in %s; using the recording rate %g Hz. Spike times ' ...
             'are wrong if the sorter ran at another rate.'], dir0, fs);
    else
        error('ChronuxDataset:NoSampleRate', ...
            ['Cannot read sample_rate from %s (no params.py) and no recording is ' ...
             'attached, so spike sample indices cannot be converted to seconds.'], dir0);
    end
end

samples = double(readNPY(fTimes));    % 0-based sample indices
clu     = double(readNPY(fClu));
samples = samples(:);
clu     = clu(:);
if numel(samples) ~= numel(clu)
    error('ChronuxDataset:KilosortMismatch', ...
        'spike_times.npy has %d entries but spike_clusters.npy has %d.', ...
        numel(samples), numel(clu));
end
times = samples / fs;                 % t = sample/fs, the readData time base

unitIds = unique(clu).';
labels  = "unit" + string(unitIds);

% phy / Kilosort cluster labels (curation first, then Kilosort's own). They are
% kept apart from the unit names: "good"/"mua"/"noise" identify a group, not a
% unit.
groupLabels = strings(1, numel(unitIds));
[lblIds, lblTxt, lblFile] = readClusterLabels(dir0);
if ~isempty(lblIds)
    [tf, loc] = ismember(unitIds, lblIds);
    groupLabels(tf) = lblTxt(loc(tf));
end
if ~isempty(opts.Groups)
    if isempty(lblIds)
        error('ChronuxDataset:NoClusterLabels', ...
            ['Groups filtering needs cluster_group.tsv or cluster_KSLabel.tsv ' ...
             'in %s; neither is there.'], dir0);
    end
    keep = ismember(groupLabels, opts.Groups);
    if ~any(keep)
        error('ChronuxDataset:NoGroupMatch', ...
            'No cluster in %s is labelled %s (labels present: %s).', lblFile, ...
            strjoin(opts.Groups, ', '), strjoin(unique(groupLabels), ', '));
    end
    unitIds     = unitIds(keep);
    labels      = labels(keep);
    groupLabels = groupLabels(keep);
end

S = struct('times', cell(1, numel(unitIds)));
for k = 1:numel(unitIds)
    S(k).times = sort(times(clu == unitIds(k)));
end

out = struct('resultsDir', string(dir0), 'sampleRate', fs, 'labelFile', lblFile, ...
    'groupLabels', groupLabels);
end


function [S, unitIds, labels] = fromDetect(obj, opts)
%fromDetect  Threshold-detect spikes on the loaded continuous signal.
obj.loadSignal();
if isfield(opts.DetectOptions, 'Fs')
    error('ChronuxDataset:DetectFs', ...
        ['Do not set Fs in DetectOptions; the loaded signal''s rate (%g Hz) is ' ...
         'used.'], obj.Fs);
end
if obj.Signal == "SPIKE" && ~isfield(opts.DetectOptions, 'Filter')
    warning('ChronuxDataset:DoubleFilter', ...
        ['The "SPIKE" signal is already band-pass filtered and detectSpikes ' ...
         'filters again by default; pass DetectOptions=struct(''Filter'',false) ' ...
         'to detect on it as it is.']);
end
ds = obj.Dataset;
if isempty(ds); ds = EphysDataset(); end     % detectSpikes works on any matrix
args = namedargs2cell(opts.DetectOptions);
ts = ds.detectSpikes(double(obj.Data), args{:}, 'Fs', obj.Fs);

S = ChronuxDataset.toPointProcess(ts);
unitIds = 1:numel(S);
if numel(obj.ChannelLabels) == numel(S)
    labels = obj.ChannelLabels;
else
    labels = "ch" + string(unitIds);
end
end


function [tr, srcTxt] = resolveSpikeTimeRange(obj, want, S)
%resolveSpikeTimeRange  Analysis window: explicit > recording > data > spikes.
tr = want;
srcTxt = "TimeRange";
if isinf(tr(1)); tr(1) = 0; end
if isinf(tr(2))
    tr(2) = NaN;
    if ~isempty(obj.Dataset) && ~isnan(obj.Dataset.Duration)
        tr(2) = obj.Dataset.Duration;
        srcTxt = "recording duration";
    elseif obj.Loaded && ~isnan(obj.Fs) && ~isempty(obj.Data)
        tr(2) = size(obj.Data, 1) / obj.Fs;
        srcTxt = "loaded signal duration";
    else
        last = 0;
        for k = 1:numel(S)
            if ~isempty(S(k).times); last = max(last, S(k).times(end)); end
        end
        tr(2) = last;
        srcTxt = "last spike";
        warning('ChronuxDataset:SpikeSpanWindow', ...
            ['No recording duration is known, so the analysis window ends at the ' ...
             'last spike (%g s). Rates and the taper grid are then set by the ' ...
             'spikes themselves; pass TimeRange to fix the window.'], tr(2));
    end
end
if ~(tr(2) > tr(1))
    error('ChronuxDataset:BadTimeRange', ...
        'The analysis window [%g %g] s is empty.', tr(1), tr(2));
end
end


function fs = readPhySampleRate(folder)
%readPhySampleRate  sample_rate from params.py, else NaN (never a guess).
fs = NaN;
pp = fullfile(folder, 'params.py');
if ~isfile(pp); return; end
tok = regexp(fileread(pp), 'sample_rate\s*=\s*([\d.eE+-]+)', 'tokens', 'once');
if ~isempty(tok); fs = str2double(tok{1}); end
if ~isfinite(fs) || fs <= 0; fs = NaN; end
end


function [ids, labels, file] = readClusterLabels(folder)
%readClusterLabels  cluster ids + labels from the phy .tsv files.
%   cluster_group.tsv (manual curation) wins over cluster_KSLabel.tsv
%   (Kilosort's own call), matching what phy shows.
ids = []; labels = string.empty(0,1); file = "";
for f = ["cluster_group.tsv", "cluster_KSLabel.tsv"]
    fp = fullfile(folder, f);
    if ~isfile(fp); continue; end
    try
        T = readtable(fp, 'FileType', 'text', 'Delimiter', '\t');
    catch
        continue
    end
    if width(T) < 2 || height(T) == 0; continue; end
    ids    = double(T{:, 1}).';
    labels = string(T{:, 2}).';
    file   = string(fp);
    return
end
end
