function loadReviewResults(obj)
%loadReviewResults  Parse a Kilosort4 results folder and populate the Review tab.
%   Reads the phy/Kilosort4 .npy + .tsv outputs once, derives per-unit summary
%   statistics (spike counts, firing rates, peak channel, shank, position,
%   amplitude, contamination, notes, mean waveform), caches them in
%   obj.ReviewData, fills the summary label and units table, and draws the
%   plots. Selecting a unit later only re-renders from the cache (see
%   renderReviewPlots). A folder belonging to the active dataset is read with
%   its identity, so units carry their full labels ("su042_1255_260908T1039");
%   any other folder gives "<class><id>" labels. Notes typed in the Notes
%   column are saved by onReviewNoteEdited.
%
%   Firing rates are spike counts over the part of the recording the sort
%   covers (sortedSpan): Kilosort4 sorts from tmin to tmax (its
%   settings.json) and counts spike times from the recording's start.
%
%   .npy files are read with the repository's small reader (READNPY, in
%   pipeline/); no external toolbox is required. Numeric arrays are assumed
%   little-endian, which is what Kilosort4 writes on x86.

folder = strtrim(obj.ReviewFolderField.Value);
if isempty(folder)
    uialert(obj.Fig, "Select a Kilosort4 results folder first.", "Review");
    return
end
% Tolerate pointing at the dataset folder or the kilosort4 run folder instead of
% the exact results dir (see EphysDataset.resolvePhyDir).
resolved = EphysDataset.resolvePhyDir(folder);
if ~strcmp(resolved, folder)
    folder = resolved;
    obj.ReviewFolderField.Value = folder;
end
if ~isfolder(folder)
    uialert(obj.Fig, sprintf("Not a folder:\n%s", folder), "Review");
    return
end
need = fullfile(folder, 'spike_clusters.npy');
if ~isfile(need)
    uialert(obj.Fig, sprintf(['No Kilosort4 output here (missing spike_clusters.npy):' ...
        newline '%s'], folder), "Review");
    return
end

dlg = uiprogressdlg(obj.Fig, "Title", "Review", ...
    "Message", "Reading Kilosort4 output...", "Indeterminate", "on");
drawnow;
cleanup = onCleanup(@() closeIfValid(dlg));

try
    % One canonical reader for every consumer of sorted output. Every cluster
    % is shown here (IncludeNoise), labels prefer the phy curation file.
    [U0, ui, labelNote, nativeNames] = readReviewUnits(obj, folder);
    fs = U0.fs;
    U  = numel(U0.unitId);
    [span, spanText] = sortedSpan(obj, folder, U0.durationSec);

    nCh = U0.nChannelsSorted;
    if ~isfinite(nCh); nCh = numel(ui.chanShanks); end
    chanShanks = ui.chanShanks;
    if numel(chanShanks) < nCh; chanShanks(end+1:nCh, 1) = 0; end

    wfPeak = zeros(numel(U0.templateTimeMs), U);
    for u = 1:U
        if ~isempty(U0.templateWaveform{u}); wfPeak(:, u) = U0.templateWaveform{u}; end
    end

    R = struct();
    R.folder   = folder;
    R.fs       = fs;
    R.span     = span;         % [start end] s of the recording the sort covers (NaN: unknown)
    R.spanText = spanText;
    R.durSec   = diff(span);
    R.nChan    = nCh;
    R.chanShanks = chanShanks;
    R.chanPos  = ui.chanPos;
    R.chanLabels = channelLabels(U0.channelMap, nCh, nativeNames);
    R.shankIDs = unique(chanShanks);
    R.nShank   = numel(R.shankIDs);
    R.clusterID = U0.unitId;
    R.unitLabel = U0.label;
    R.labelNote = labelNote;
    R.group    = U0.group;
    R.groupSource = U0.groupSource;
    R.notes    = U0.notes;
    R.nSpikes  = U0.nSpikes;
    R.firingRate = U0.nSpikes / R.durSec;   % per second of the sorted time
    R.peakChan = U0.ksChannel;
    R.recChan  = U0.channel;
    R.channelName = U0.channelName;
    R.shank    = U0.shank;
    R.x        = U0.x;
    R.y        = U0.y;
    R.ampUnit  = U0.amplitude;
    R.contam   = U0.contamPct;
    R.tms      = U0.templateTimeMs;
    R.wfPeak   = wfPeak;
    R.wfFull   = U0.templateFull;
    R.spikeSec = double(ui.spikeSamples) / fs;
    R.spikeAmp = ui.spikeAmplitudes;
    R.spikeUnitIdx = ui.spikeUnitIdx;
    R.nGood    = sum(R.group == "good");
    R.nMua     = sum(R.group == "mua");
    R.units    = U0;

    obj.ReviewData = R;
    obj.ReviewSelectedUnit = 0;
    obj.ReviewSpikeWaves = struct([]);

    fillSummary(obj, R);
    fillUnitsTable(obj, R);
    obj.renderReviewPlots();

    obj.setStatus(sprintf("Loaded results: %d unit(s) (good %d, mua %d).", ...
        numel(R.clusterID), R.nGood, R.nMua), ...
        "Click a unit row to focus its waveform and stats.");
catch ME
    closeIfValid(dlg);
    uialert(obj.Fig, sprintf("Failed to load results:\n%s", ME.message), "Review");
    rethrow(ME);
end
end


%% ---------------------------------------------------------------------------
function fillSummary(obj, R)
%fillSummary  Compose the aggregate-stats text block.
U = numel(R.clusterID);
lines = strings(0, 1);
if U > 0 && R.units.datasetKey(1) ~= ""
    lines(end+1) = "Dataset : " + R.units.datasetKey(1);
    lines(end+1) = "Labels  : <class><id>_" + extractAfter(R.unitLabel(1), "_");
else
    lines(end+1) = "Folder  : " + string(R.folder);
    lines(end+1) = "Labels  : <class><id> only (" + R.labelNote + ")";
end
lines(end+1) = sprintf("Fs      : %g kHz", R.fs / 1000);
if isfinite(R.durSec)
    lines(end+1) = sprintf("Sorted  : %s (%.1f to %.1f s%s)", durStr(R.durSec), R.span(1), R.span(2), R.spanText);
end
lines(end+1) = sprintf("Channels: %d   Shanks: %d", R.nChan, R.nShank);
lines(end+1) = "";
lines(end+1) = sprintf("Total units : %d", U);
lines(end+1) = sprintf("  good=%d  mua=%d  other=%d", R.nGood, R.nMua, U - R.nGood - R.nMua);
lines(end+1) = sprintf("Total spikes: %s", commaSep(sum(R.nSpikes)));
if isfinite(R.durSec)
    lines(end+1) = sprintf("Mean rate   : %.1f Hz/unit (over the sorted time)", mean(R.firingRate, 'omitnan'));
end
lines(end+1) = "";
lines(end+1) = "Units per shank:";
for s = 1:R.nShank
    sid = R.shankIDs(s);
    m = R.shank == sid;
    lines(end+1) = sprintf("  shank %g : %d  (good %d)", sid, sum(m), ...
        sum(m & R.group == "good"));   %#ok<AGROW>
end
obj.ReviewSummaryLabel.Text = lines;
end


function fillUnitsTable(obj, R)
%fillUnitsTable  Fill the per-unit table (one row per cluster).
%   Columns: Unit, Group, Shank, Ch (name, else recording channel), X, Y
%   (template centre), #Spk, FR, Amp, Cont%, Notes (editable).
U = numel(R.clusterID);
C = cell(U, 11);
for u = 1:U
    ch = R.channelName(u);
    if ch == "" && isfinite(R.recChan(u)); ch = string(R.recChan(u)); end
    C{u, 1}  = R.clusterID(u);
    C{u, 2}  = char(R.group(u));
    C{u, 3}  = R.shank(u);
    C{u, 4}  = char(ch);
    C{u, 5}  = round(R.x(u), 1);
    C{u, 6}  = round(R.y(u), 1);
    C{u, 7}  = R.nSpikes(u);
    C{u, 8}  = round(R.firingRate(u), 2);
    C{u, 9}  = round(R.ampUnit(u), 1);
    C{u, 10} = round(R.contam(u), 1);
    C{u, 11} = char(R.notes(u));
end
obj.ReviewUnitsTable.Data = C;
obj.ReviewUnitsTable.Selection = [];
end


function [U0, ui, note, names] = readReviewUnits(obj, folder)
%readReviewUnits  Units in FOLDER, with the active dataset's identity when it owns FOLDER.
%   NAMES: that dataset's native channel names (none for any other folder).
note = "not the active dataset's sort";
names = strings(1, 0);
d = obj.currentDataset();
if ~isempty(d) && ownsFolder(d, folder)
    try
        [U0, ui] = d.readSortedUnits(ResultsDir=folder, IncludeNoise=true, FullTemplates=true);
        note = "";
        names = string(d.NativeNames);
        return
    catch ME
        if ~startsWith(string(ME.identifier), "EphysDataset:unitIdentity:")
            rethrow(ME);
        end
        note = string(ME.message);
    end
end
[U0, ui] = EphysDataset.readPhyUnits(folder, IncludeNoise=true, FullTemplates=true);
end


function [span, txt] = sortedSpan(obj, folder, lastSpike)
%sortedSpan  The part of the recording the sort in FOLDER covers, [start end] s.
%   Kilosort4 sorts from tmin to tmax (the run's settings.json; 0 and the
%   end by default), and its spike times count from the recording's start
%   (its io.py adds tmin back), so the sort covers tmin to min(tmax,
%   duration). The duration is the active dataset's when FOLDER is its
%   sort, else that of the .bin the settings name; without either, the
%   last spike (LASTSPIKE, s) ends the span and TXT says so. NaN when
%   nothing gives an end past tmin.
S = readJsonFile(fullfile(folder, 'settings.json'), ErrorOnFail=false);
tmin = 0;
tmax = Inf;
dur = NaN;
if isstruct(S)
    if isfield(S, 'tmin') && isnumeric(S.tmin) && isscalar(S.tmin) && S.tmin > 0; tmin = double(S.tmin); end
    if isfield(S, 'tmax') && isnumeric(S.tmax) && isscalar(S.tmax) && S.tmax > 0; tmax = double(S.tmax); end
end
d = obj.currentDataset();
if ~isempty(d) && ownsFolder(d, folder) && d.Duration > 0
    dur = d.Duration;
elseif isstruct(S) && all(isfield(S, {'filename', 'n_chan_bin', 'fs'}))
    dur = binSeconds(S);
end
txt = "";
tEnd = min(tmax, dur);
if ~(tEnd > tmin)
    tEnd = min(tmax, lastSpike);
    txt = "; to the last spike: the recording's length is unknown";
end
span = [tmin tEnd];
if ~(tEnd > tmin); span = [NaN NaN]; end
end


function sec = binSeconds(S)
%binSeconds  Seconds of recording in the .bin that Kilosort4 settings S name (NaN: unknown).
sec = NaN;
f = dir(char(string(S.filename)));
if ~isscalar(f); return; end
dtype = "int16";
if isfield(S, 'data_dtype'); dtype = string(S.data_dtype); end
switch dtype
    case {"int16", "uint16"}; bytes = 2;
    case {"int32", "uint32", "float32"}; bytes = 4;
    case "float64"; bytes = 8;
    otherwise; return
end
sec = f.bytes / (double(S.n_chan_bin) * bytes) / double(S.fs);
end


function tf = ownsFolder(d, folder)
%ownsFolder  FOLDER is the dataset's folder, output folder or pinned SortingDir, or under one.
f = lower(EphysProject.normalizeKey(folder));
roots = [string(d.Folder), string(d.outputFolder()), d.SortingDir];
roots = lower(EphysProject.normalizeKey(roots(roots ~= "")));
tf = any(f == roots) || any(startsWith(f, roots + "/"));
end


function lbl = channelLabels(channelMap, nCh, names)
%channelLabels  Each sorted channel's name ("A-012"), else its recording channel number.
lbl = strings(nCh, 1);
n = min(nCh, numel(channelMap));
rec = channelMap(1:n);
lbl(1:n) = string(rec);
ok = find(isfinite(rec) & rec >= 1 & rec <= numel(names));
ok = ok(names(rec(ok)) ~= "");
lbl(ok) = names(rec(ok));
end


%% --- small helpers ---------------------------------------------------------
function s = durStr(sec)
s = char(string(seconds(sec), 'hh:mm:ss'));
end


function s = commaSep(n)
s = regexprep(sprintf('%d', round(n)), '\d(?=(\d{3})+$)', '$0,');
end


function closeIfValid(dlg)
if ~isempty(dlg) && isvalid(dlg); close(dlg); end
end

