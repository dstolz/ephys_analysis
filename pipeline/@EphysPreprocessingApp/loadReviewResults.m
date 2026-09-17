function loadReviewResults(obj)
%loadReviewResults  Parse a Kilosort4 results folder and populate the Review tab.
%   Reads the phy/Kilosort4 .npy + .tsv outputs once, derives per-unit summary
%   statistics (spike counts, firing rates, peak channel, shank, amplitude,
%   contamination, mean waveform), caches them in obj.ReviewData, fills the
%   summary label and units table, and draws the plots. Selecting a unit later
%   only re-renders from the cache (see renderReviewPlots).
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
    [U0, ui] = EphysDataset.readPhyUnits(folder, IncludeNoise=true, FullTemplates=true);
    fs = U0.fs;
    U  = numel(U0.unitId);
    durSec = U0.durationSec;
    if ~(durSec > 0); durSec = NaN; end

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
    R.durSec   = durSec;
    R.nChan    = nCh;
    R.chanShanks = chanShanks;
    R.chanPos  = ui.chanPos;
    R.shankIDs = unique(chanShanks);
    R.nShank   = numel(R.shankIDs);
    R.clusterID = U0.unitId;
    R.label    = U0.group;
    R.labelSource = U0.groupSource;
    R.nSpikes  = U0.nSpikes;
    R.firingRate = U0.nSpikes / durSec;
    R.peakChan = U0.ksChannel;
    R.recChan  = U0.channel;
    R.shank    = U0.shank;
    R.ampUnit  = U0.amplitude;
    R.contam   = U0.contamPct;
    R.tms      = U0.templateTimeMs;
    R.wfPeak   = wfPeak;
    R.wfFull   = U0.templateFull;
    R.spikeSec = double(ui.spikeSamples) / fs;
    R.spikeAmp = ui.spikeAmplitudes;
    R.spikeUnitIdx = ui.spikeUnitIdx;
    R.nGood    = sum(R.label == "good");
    R.nMua     = sum(R.label == "mua");
    R.units    = U0;

    obj.ReviewData = R;
    obj.ReviewSelectedUnit = 0;

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
[~, fname] = fileparts(fileparts(R.folder));
lines(end+1) = "Dataset : " + string(fname);
lines(end+1) = sprintf("Fs      : %g kHz", R.fs / 1000);
if isfinite(R.durSec)
    lines(end+1) = sprintf("Duration: %s (%.1f s)", durStr(R.durSec), R.durSec);
end
lines(end+1) = sprintf("Channels: %d   Shanks: %d", R.nChan, R.nShank);
lines(end+1) = "";
lines(end+1) = sprintf("Total units : %d", U);
lines(end+1) = sprintf("  good=%d  mua=%d  other=%d", R.nGood, R.nMua, U - R.nGood - R.nMua);
lines(end+1) = sprintf("Total spikes: %s", commaSep(sum(R.nSpikes)));
if isfinite(R.durSec)
    lines(end+1) = sprintf("Mean rate   : %.1f Hz/unit", mean(R.firingRate, 'omitnan'));
end
lines(end+1) = "";
lines(end+1) = "Units per shank:";
for s = 1:R.nShank
    sid = R.shankIDs(s);
    m = R.shank == sid;
    lines(end+1) = sprintf("  shank %g : %d  (good %d)", sid, sum(m), ...
        sum(m & R.label == "good"));   %#ok<AGROW>
end
obj.ReviewSummaryLabel.Text = lines;
end


function fillUnitsTable(obj, R)
%fillUnitsTable  Fill the per-unit table (one row per cluster).
U = numel(R.clusterID);
C = cell(U, 8);
for u = 1:U
    C{u, 1} = R.clusterID(u);
    C{u, 2} = char(R.label(u));
    C{u, 3} = R.shank(u);
    C{u, 4} = R.peakChan(u);
    C{u, 5} = R.nSpikes(u);
    C{u, 6} = round(R.firingRate(u), 2);
    C{u, 7} = round(R.ampUnit(u), 1);
    C{u, 8} = round(R.contam(u), 1);
end
obj.ReviewUnitsTable.Data = C;
obj.ReviewUnitsTable.Selection = [];
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

