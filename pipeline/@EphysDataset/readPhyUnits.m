function [units, info] = readPhyUnits(resultsDir, opts)
%readPhyUnits  Read sorted units from a Kilosort4 / phy results folder.
%   UNITS = EphysDataset.readPhyUnits(resultsDir) is the one canonical reader
%   of phy-format sorter output (spike_times.npy, spike_clusters.npy, the
%   cluster_*.tsv label tables, templates.npy, ...). It needs no EphysDataset;
%   ds.readSortedUnits wraps it with the dataset's own defaults. The Review
%   tab, ChronuxDataset.spikes, spikesToMat and the toolbox
%   exporters all read through here, so they agree on labels, times and
%   channels.
%
%   RESULTSDIR may be the folder holding params.py, or a dataset / kilosort4
%   run folder above it (see EphysDataset.resolvePhyDir).
%
%   Options
%   -------
%     Groups        keep only clusters with these labels, e.g. ["good" "mua"]
%                   ([] = all). Errors when no label table exists.
%     IncludeNoise  keep clusters labelled "noise" (default false)
%     Templates     read templates.npy for peak channel + waveform (default true)
%     FullTemplates also return every unit's [nS x nChan] template (default false)
%     ChannelMap    [1 x nChanSorted] 1-based RECORDING channel for each sorted
%                   channel (overrides the mapping worked out from the run)
%     ChannelNumbers  recording channel hardware numbers (0-based,
%                   EphysDataset.ChannelNumbers) for the channelNumber column
%     ChannelNames  recording channel native names ("A-000", "CH1", ...) for
%                   the channelName column
%     FsFallback    sample rate to use, with a warning, when params.py has no
%                   sample_rate (default NaN = error instead; never 30 kHz)
%     Identity      struct with subject, recordingStart, labelSuffix and
%                   datasetKey (EphysDataset.unitIdentity) naming the recording;
%                   default struct([]) = a bare folder, labels "<class><id>"
%
%   UNITS is one scalar struct with column-aligned fields (one row per unit):
%     unitId            cluster id (as in spike_clusters.npy)
%     label             "<class><id>_<subject>_<yyMMdd>T<HHmm>", the id at least
%                       3 digits, e.g. "su042_1255_260908T1039"; just
%                       "<class><id>" without an Identity
%     class             "su" (good) | "mua" | "noise" | "uns" (unsorted) |
%                       "other" (any other phy label, with a warning)
%     group             "good" | "mua" | "noise" | "unsorted" | other phy label
%     notes             free text from cluster_notes.tsv ("" when none; see
%                       EphysDataset.writeUnitNotes)
%     subject           Identity.subject ("" without an Identity)
%     recordingStart    Identity.recordingStart (NaT without an Identity)
%     datasetKey        Identity.datasetKey ("" without an Identity)
%     channel           1-based peak channel of the RECORDING (see channelMap)
%     channelName       its native name, e.g. "A-012" ("" without ChannelNames)
%     channelNumber     its hardware number (NaN without ChannelNumbers); not
%                       the probe chanMap value, which is channel - 1 (the
%                       .bin row)
%     ksChannel         1-based peak channel among the SORTED channels
%     shank             from channel_shanks.npy (0 when absent)
%     peakX, peakY      site position of the peak channel, probe units (um),
%                       from channel_positions.npy (NaN when absent)
%     x, y              template centre: site positions weighted by the
%                       template's peak-to-peak amplitude, over the channels on
%                       the peak channel's shank with at least 25% of the peak
%                       amplitude (NaN without templates or positions)
%     nSpikes
%     samples           {nU x 1} 0-based int64 sample indices, sorted
%     times             {nU x 1} seconds: samples / fs (recording-relative,
%                       the same clock as readData's t)
%     amplitude         cluster_Amplitude.tsv, else median amplitudes.npy
%                       (Kilosort4's units, from the whitened data)
%     contamPct         cluster_ContamPct.tsv (NaN when absent)
%     templateWaveform  {nU x 1} [nS x 1] the unit's template on its peak
%                       channel, in templateUnits (what the Review tab plots):
%                       templates.npy, Kilosort4's mean of the unit's spikes
%                       in the data it sorted (high-passed, referenced,
%                       whitened; rebuilt from their PC features), unwhitened
%                       with whitening_mat_inv.npy. Not a raw-spike average
%                       (EphysDataset.readPhyWaveforms cuts the spikes)
%     templateFull     [nS x nChanSorted x nU] the same on every sorted
%                       channel (FullTemplates) else []
%     templateTimeMs    [1 x nS]
%     templateUnits     what the template values are:
%                       "uV"        unwhitened, and divided by the .bin's
%                                   scale, its units per uV (bin_scale in the
%                                   run's settings.json; runKilosort writes it)
%                       "bin"       unwhitened, in the sorted .bin's units (no
%                                   bin_scale)
%                       "whitened"  as Kilosort4 stores them (no usable
%                                   whitening_mat_inv.npy)
%                       ""          no templates read
%                       Unwhitened templates also undo Kilosort4's own scale
%                       setting and invert_sign from settings.json.
%   and per-run scalars: fs, resultsDir, groupSource ("phy" when phy wrote
%   cluster_group.tsv, header "cluster_id<TAB>group"; "kilosort" for
%   Kilosort's own call, which Kilosort4 also copies to cluster_group.tsv
%   with the header "cluster_id<TAB>KSLabel"; "none"), curated (groupSource
%   is "phy"), labelFile, durationSec (last spike), nChannelsSorted,
%   channelMap ([nChanSorted x 1] 1-based recording channels),
%   channelMapSource ("manual" | "channel_map.npy" | "identity"), readAt.
%
%   INFO carries the per-spike arrays for plotting: spikeSamples,
%   spikeClusters, spikeAmplitudes, spikeUnitIdx (row into UNITS, 0 when the
%   cluster was dropped by the filters), chanShanks, chanPos.
%
%   Error identifiers: EphysDataset:readPhyUnits:NoResultsDir, :NoOutput,
%   :NoSampleRate, :Mismatch, :NoClusterLabels, :NoGroupMatch, :BadIdentity.
%   Warning EphysDataset:readPhyUnits:OtherGroup names cluster labels that
%   map to class "other".
%
%   See also EphysDataset.readSortedUnits, EphysDataset.readPhyWaveforms,
%   EphysDataset.resolvePhyDir, ChronuxDataset.spikes, readNPY.

arguments
    resultsDir (1,1) string
    opts.Groups (1,:) string = string.empty(1,0)
    opts.IncludeNoise (1,1) logical = false
    opts.Templates (1,1) logical = true
    opts.FullTemplates (1,1) logical = false
    opts.ChannelMap (1,:) double = []
    opts.ChannelNumbers (1,:) double = double.empty(1,0)
    opts.ChannelNames (1,:) string = string.empty(1,0)
    opts.FsFallback (1,1) double = NaN
    opts.Identity struct = struct([])
end

% Template-centre channels: at least this fraction of the peak amplitude.
centreFraction = 0.25;

dir0 = EphysDataset.resolvePhyDir(resultsDir);
if ~isfolder(dir0)
    error('EphysDataset:readPhyUnits:NoResultsDir', 'Not a folder: %s', resultsDir);
end
fTimes = fullfile(dir0, 'spike_times.npy');
fClu   = fullfile(dir0, 'spike_clusters.npy');
for f = [string(fTimes) string(fClu)]
    if ~isfile(f)
        error('EphysDataset:readPhyUnits:NoOutput', ...
            'No Kilosort4 / phy output in %s (missing %s).', dir0, f);
    end
end

% --- sample rate: params.py, else the caller's fallback, never a guess ----
fs = readPhySampleRate(dir0);
if isnan(fs)
    if isfinite(opts.FsFallback) && opts.FsFallback > 0
        fs = opts.FsFallback;
        warning('EphysDataset:readPhyUnits:FsFallback', ...
            ['No sample_rate in %s; using %g Hz. Spike times are wrong if the ' ...
             'sorter ran at another rate.'], dir0, fs);
    else
        error('EphysDataset:readPhyUnits:NoSampleRate', ...
            ['Cannot read sample_rate from %s (no params.py) and no fallback ' ...
             'rate was given, so sample indices cannot be converted to seconds.'], dir0);
    end
end

% --- per-spike arrays -----------------------------------------------------
spikeSamples = int64(readNPY(fTimes));
spikeSamples = spikeSamples(:);
spikeClu     = double(readNPY(fClu));
spikeClu     = spikeClu(:);
if numel(spikeSamples) ~= numel(spikeClu)
    error('EphysDataset:readPhyUnits:Mismatch', ...
        'spike_times.npy has %d entries but spike_clusters.npy has %d.', ...
        numel(spikeSamples), numel(spikeClu));
end
spikeAmp = readOptionalNPY(fullfile(dir0, 'amplitudes.npy'), nan(numel(spikeClu), 1));
spikeAmp = double(spikeAmp(:));
if numel(spikeAmp) ~= numel(spikeClu); spikeAmp = nan(numel(spikeClu), 1); end

[unitId, ~, spikeUnitIdx] = unique(spikeClu);
nU = numel(unitId);
nSpikes = accumarray(spikeUnitIdx, 1, [nU 1]);
% The spikes grouped by unit once, in file order (sort is stable): unit u
% holds spikes byUnit(first(u):last(u)).
[~, byUnit] = sort(spikeUnitIdx);
last  = cumsum(nSpikes);
first = last - nSpikes + 1;

% --- labels: phy curation first, then Kilosort's own call ------------------
[lblIds, lblTxt, labelFile, groupSource] = readClusterLabels(dir0);
group = repmat("unsorted", nU, 1);
if ~isempty(lblIds)
    [tf, loc] = ismember(unitId, lblIds);
    group(tf) = lblTxt(loc(tf));
end
group = lower(strtrim(group));
group(group == "") = "unsorted";

% --- amplitude / contamination side tables ---------------------------------
ampTsv    = lookupByID(dir0, 'cluster_Amplitude.tsv', unitId);
contamTsv = lookupByID(dir0, 'cluster_ContamPct.tsv', unitId);
ampByUnit = spikeAmp(byUnit);
medAmp = nan(nU, 1);
for u = 1:nU
    medAmp(u) = median(ampByUnit(first(u):last(u)), 'omitnan');
end
amplitude = ampTsv;
amplitude(~isfinite(amplitude)) = medAmp(~isfinite(amplitude));

% --- templates: peak channel + waveform ------------------------------------
ksChannel = nan(nU, 1);
wfPeak    = cell(nU, 1);
wfFull    = [];
p2pAll    = [];
tms       = zeros(1, 0);
nChSorted = NaN;
templateUnits = "";
fTmpl = fullfile(dir0, 'templates.npy');
if opts.Templates && isfile(fTmpl)
    templates = double(readNPY(fTmpl));                    % [nT nS nC]
    nT = size(templates, 1); nS = size(templates, 2); nChSorted = size(templates, 3);
    spikeTmpl = readOptionalNPY(fullfile(dir0, 'spike_templates.npy'), spikeClu);
    spikeTmpl = double(spikeTmpl(:));
    if numel(spikeTmpl) ~= numel(spikeClu); spikeTmpl = spikeClu; end
    tmplByUnit = spikeTmpl(byUnit);
    [toUnits, templateUnits] = templateConversion(dir0, nChSorted);
    tms = (0:nS-1) / fs * 1000;
    if opts.FullTemplates; wfFull = zeros(nS, nChSorted, nU); end
    p2pAll = nan(nU, nChSorted);
    for u = 1:nU
        tIdx = mode(tmplByUnit(first(u):last(u))) + 1;     % robust to KS reindexing
        if ~(tIdx >= 1 && tIdx <= nT)
            tIdx = min(max(unitId(u) + 1, 1), nT);
        end
        wf = reshape(templates(tIdx, :, :), nS, nChSorted);
        if ~isempty(toUnits); wf = wf * toUnits; end
        p2p = max(wf, [], 1) - min(wf, [], 1);
        [~, pk] = max(p2p);
        ksChannel(u) = pk;
        p2pAll(u, :) = p2p;
        wfPeak{u} = wf(:, pk);
        if opts.FullTemplates; wfFull(:, :, u) = wf; end
    end
end

chanShanks = readOptionalNPY(fullfile(dir0, 'channel_shanks.npy'), []);
chanShanks = double(chanShanks(:));
chanPos = readOptionalNPY(fullfile(dir0, 'channel_positions.npy'), []);
cm0 = readOptionalNPY(fullfile(dir0, 'channel_map.npy'), []);
cm0 = double(cm0(:));
if isnan(nChSorted)
    nChSorted = max([numel(cm0), numel(chanShanks), size(chanPos, 1)]);
    if nChSorted == 0; nChSorted = NaN; end
end
if isfinite(nChSorted)
    if numel(chanShanks) < nChSorted; chanShanks(end+1:nChSorted, 1) = 0; end
    chanShanks = chanShanks(1:nChSorted);
end
shank = zeros(nU, 1);
ok = isfinite(ksChannel) & ksChannel >= 1 & ksChannel <= numel(chanShanks);
shank(ok) = chanShanks(ksChannel(ok));

% --- location on the probe: peak site and template centre ------------------
peakX = nan(nU, 1); peakY = nan(nU, 1); cx = nan(nU, 1); cy = nan(nU, 1);
if size(chanPos, 2) >= 2 && isfinite(nChSorted) && size(chanPos, 1) >= nChSorted
    ok = isfinite(ksChannel) & ksChannel >= 1 & ksChannel <= nChSorted;
    peakX(ok) = chanPos(ksChannel(ok), 1);
    peakY(ok) = chanPos(ksChannel(ok), 2);
    for u = find(ok).'
        w = p2pAll(u, :).';
        pk = ksChannel(u);
        use = chanShanks == chanShanks(pk) & w >= centreFraction * w(pk);
        if any(use) && sum(w(use)) > 0
            cx(u) = sum(w(use) .* chanPos(use, 1)) / sum(w(use));
            cy(u) = sum(w(use) .* chanPos(use, 2)) / sum(w(use));
        else
            cx(u) = peakX(u); cy(u) = peakY(u);
        end
    end
end

% --- notes typed in phy or on the Review tab -------------------------------
notes = strings(nU, 1);
[noteIds, noteTxt] = EphysDataset.readUnitNotes(string(dir0));
[tf, loc] = ismember(unitId, noteIds);
notes(tf) = noteTxt(loc(tf));

% --- sorted channel -> recording channel -----------------------------------
[channelMap, channelMapSource] = resolveChannelMap(dir0, nChSorted, cm0, opts);
channel = nan(nU, 1);
ok = isfinite(ksChannel) & ksChannel >= 1 & ksChannel <= numel(channelMap);
channel(ok) = channelMap(ksChannel(ok));
channelName = strings(nU, 1);
ok = isfinite(channel) & channel >= 1 & channel <= numel(opts.ChannelNames);
channelName(ok) = opts.ChannelNames(channel(ok));
channelNumber = nan(nU, 1);
ok = isfinite(channel) & channel >= 1 & channel <= numel(opts.ChannelNumbers);
channelNumber(ok) = opts.ChannelNumbers(channel(ok));

% --- filters ---------------------------------------------------------------
keep = true(nU, 1);
if ~opts.IncludeNoise
    keep = keep & group ~= "noise";
end
if ~isempty(opts.Groups)
    if isempty(lblIds)
        error('EphysDataset:readPhyUnits:NoClusterLabels', ...
            ['Groups filtering needs cluster_group.tsv or cluster_KSLabel.tsv ' ...
             'in %s; neither is there.'], dir0);
    end
    keep = keep & ismember(group, lower(strtrim(opts.Groups)));
    if ~any(keep)
        error('EphysDataset:readPhyUnits:NoGroupMatch', ...
            'No cluster in %s is labelled %s (labels present: %s).', labelFile, ...
            strjoin(opts.Groups, ', '), strjoin(unique(group).', ', '));
    end
end
keptIdx = find(keep);
keptRow = zeros(nU, 1);
keptRow(keptIdx) = 1:numel(keptIdx);
spikeUnitIdxKept = keptRow(spikeUnitIdx);                  % 0 for dropped units

samples = cell(numel(keptIdx), 1);
times   = cell(numel(keptIdx), 1);
for k = 1:numel(keptIdx)
    u = keptIdx(k);
    s = sort(spikeSamples(byUnit(first(u):last(u))));
    samples{k} = s;
    times{k}   = double(s) / fs;
end

durationSec = NaN;
if ~isempty(spikeSamples)
    durationSec = double(max(spikeSamples)) / fs;
end

nK = numel(keptIdx);
[subject, recStart, suffix, key] = identityParts(opts.Identity);
units = struct();
units.unitId           = unitId(keptIdx);
units.label            = strings(nK, 1);
units.class            = groupClass(group(keptIdx), dir0);
units.label            = unitLabels(units.class, units.unitId, suffix);
units.group            = group(keptIdx);
units.notes            = notes(keptIdx);
units.subject          = repmat(subject, nK, 1);
units.recordingStart   = repmat(recStart, nK, 1);
units.datasetKey       = repmat(key, nK, 1);
units.channel          = channel(keptIdx);
units.channelName      = channelName(keptIdx);
units.channelNumber    = channelNumber(keptIdx);
units.ksChannel        = ksChannel(keptIdx);
units.shank            = shank(keptIdx);
units.peakX            = peakX(keptIdx);
units.peakY            = peakY(keptIdx);
units.x                = cx(keptIdx);
units.y                = cy(keptIdx);
units.nSpikes          = nSpikes(keptIdx);
units.samples          = samples;
units.times            = times;
units.amplitude        = amplitude(keptIdx);
units.contamPct        = contamTsv(keptIdx);
units.templateWaveform = wfPeak(keptIdx);
if isempty(wfFull); units.templateFull = []; else; units.templateFull = wfFull(:, :, keptIdx); end
units.templateTimeMs   = tms;
units.templateUnits    = templateUnits;
units.fs               = fs;
units.resultsDir       = string(dir0);
units.groupSource      = groupSource;
units.curated          = groupSource == "phy";
units.labelFile        = labelFile;
units.durationSec      = durationSec;
units.nChannelsSorted  = nChSorted;
units.channelMap       = channelMap(:);
units.channelMapSource = channelMapSource;
units.readAt           = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

info = struct();
info.spikeSamples    = spikeSamples;
info.spikeClusters   = spikeClu;
info.spikeAmplitudes = spikeAmp;
info.spikeUnitIdx    = spikeUnitIdxKept;
info.chanShanks      = chanShanks;
info.chanPos         = chanPos;
info.nUnitsInFile    = nU;
end


%% ---------------------------------------------------------------------------
function c = groupClass(group, folder)
%groupClass  Unit class used in labels: good -> su, mua, noise, unsorted -> uns.
c = repmat("other", size(group));
c(group == "good")     = "su";
c(group == "mua")      = "mua";
c(group == "noise")    = "noise";
c(group == "unsorted") = "uns";
odd = unique(group(c == "other"));
if ~isempty(odd)
    warning('EphysDataset:readPhyUnits:OtherGroup', ...
        'Cluster label(s) %s in %s have no unit class; those units are labelled "other".', ...
        strjoin(odd.', ", "), folder);
end
end


function labels = unitLabels(cls, ids, suffix)
%unitLabels  "<class><id, at least 3 digits>", plus "_<suffix>" when the recording is known.
labels = strings(numel(ids), 1);
if isempty(ids); return; end
labels = cls(:) + compose("%03d", ids(:));
if suffix ~= ""
    labels = labels + "_" + suffix;
end
end


function [subject, recStart, suffix, key] = identityParts(identity)
%identityParts  Recording identity for the unit columns ("" / NaT when unknown).
subject = ""; suffix = ""; key = "";
recStart = NaT('Format', 'yyyy-MM-dd HH:mm:ss');
if isempty(identity); return; end
need = ["subject" "recordingStart" "labelSuffix" "datasetKey"];
if ~all(isfield(identity, need))
    error('EphysDataset:readPhyUnits:BadIdentity', ...
        'Identity needs the fields %s (see EphysDataset.unitIdentity).', strjoin(need, ", "));
end
subject  = string(identity.subject);
recStart = identity.recordingStart;
suffix   = string(identity.labelSuffix);
key      = string(identity.datasetKey);
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


function [ids, labels, file, source] = readClusterLabels(folder)
%readClusterLabels  cluster ids + labels; cluster_group.tsv wins over
%   cluster_KSLabel.tsv (Kilosort's own call), as phy shows them. SOURCE is
%   "phy" only when phy wrote cluster_group.tsv (header "cluster_id<TAB>group"):
%   Kilosort4 copies cluster_KSLabel.tsv there on every run, header and all.
ids = []; labels = strings(0, 1); file = ""; source = "none";
for name = ["cluster_group.tsv", "cluster_KSLabel.tsv"]
    fp = fullfile(folder, name);
    [tid, txt, header] = readTsv(fp);
    if numel(header) < 2 || isempty(tid); continue; end
    ids    = tid;
    labels = txt;                                  % blank cell "" -> "unsorted" below
    file   = string(fp);
    source = "kilosort";
    if name == "cluster_group.tsv" && EphysDataset.phyCurated(folder)
        source = "phy";
    end
    return
end
end


function v = lookupByID(folder, fname, ids)
%lookupByID  Numeric column 2 of a phy .tsv aligned to IDS (NaN when absent).
v = nan(numel(ids), 1);
[tid, txt, header] = readTsv(fullfile(folder, fname));
if numel(header) < 2 || isempty(tid); return; end
[tf, loc] = ismember(ids, tid);
vals = str2double(txt);
v(tf) = vals(loc(tf));
end


function [ids, vals, header] = readTsv(file)
%readTsv  The first two columns of a phy .tsv (tab-separated, a header row).
%   IDS [n x 1] double: column 1 (NaN where it is no number). VALS [n x 1]
%   string: column 2, trimmed ("" for a blank or missing cell). HEADER: the
%   header row's cells. Blank lines are skipped, and a cell in double quotes
%   (Python's csv writer, which phy uses) loses them. Empty outputs for a
%   missing or unreadable file. fileread + split, not readtable: this runs
%   on every read of a sort, and readtable takes 30x longer or more.
ids = zeros(0, 1); vals = strings(0, 1); header = strings(1, 0);
if ~isfile(file); return; end
try
    lines = splitlines(string(fileread(file)));
catch
    return
end
lines = lines(strtrim(lines) ~= "");
if isempty(lines); return; end
tab = sprintf('\t');
header = unquote(strtrim(split(lines(1), tab))).';
rows = lines(2:end);
c1 = rows;
c2 = strings(size(rows));
hasTab = contains(rows, tab);
c1(hasTab) = extractBefore(rows(hasTab), tab);
rest = extractAfter(rows(hasTab), tab);
more = contains(rest, tab);
rest(more) = extractBefore(rest(more), tab);
c2(hasTab) = rest;
ids  = str2double(unquote(strtrim(c1)));
vals = unquote(strtrim(c2));
end


function s = unquote(s)
%unquote  A csv-quoted cell ("a ""b""") to its text (a "b").
q = strlength(s) >= 2 & startsWith(s, '"') & endsWith(s, '"');
if any(q)
    s(q) = replace(extractBetween(s(q), 2, strlength(s(q)) - 1), '""', '"');
end
end


function out = readOptionalNPY(fn, fallback)
if isfile(fn)
    out = double(readNPY(fn));
else
    out = fallback;
end
end


function [channelMap, source] = resolveChannelMap(dir0, nChSorted, cm0, opts)
%resolveChannelMap  1-based recording channel for each sorted channel.
%   runKilosort sorts the .bin directly, whose rows ARE recording channels,
%   so channel_map.npy + 1 is the answer. Without a usable channel_map.npy
%   the identity mapping is returned, with a warning unless the folder is a
%   runKilosort run (its settings.json sits beside the output).
if isnan(nChSorted) || nChSorted < 1
    channelMap = zeros(0, 1); source = "identity";
    return
end

if ~isempty(opts.ChannelMap)
    channelMap = double(opts.ChannelMap(:));
    source = "manual";
    if numel(channelMap) ~= nChSorted
        warning('EphysDataset:readPhyUnits:ChannelMapSize', ...
            'ChannelMap has %d entries but the run has %d sorted channels.', ...
            numel(channelMap), nChSorted);
    end
    return
end

if ~isempty(cm0) && numel(cm0) == nChSorted
    channelMap = cm0 + 1;
    source = "channel_map.npy";
else
    if ~isfile(fullfile(dir0, 'settings.json'))
        warning('EphysDataset:readPhyUnits:ChannelMapFallback', ...
            'No usable channel_map.npy in %s; using the identity channel mapping.', dir0);
    end
    channelMap = (1:nChSorted).';
    source = "identity";
end
end
