function info = toBin(obj, opts)
%toBin  Stream the recording to a Kilosort4 int16 .bin file, one file in RAM.
%   INFO = ds.toBin() writes raw broadband data, scaled to int16, to ds.BinFile
%   in the layout Kilosort4 expects (no header, little-endian, channel index
%   varying fastest on disk). Only one chunk of the reader's streamPlan (a
%   traditional *.rhd file, or a bounded sample window) is held in memory at
%   a time: each is read, optionally filtered/blanked, scaled, cast to int16,
%   and appended to the open binary file before the next one is read.
%
%   By default the broadband signal is written unfiltered (Kilosort4 filters and
%   whitens internally). The scale 1/0.195 restores the native ADC int16
%   resolution (0.195 uV per count, Intan and Open Ephys headstages) from the
%   microvolt values the reader produces, mirroring
%   MATRIX2KILOSORT so that the streamed file is byte-identical to the in-memory
%   writer for the same data.
%
%   Options
%   -------
%     Files          (1,:) string  subset/order of files (default: all, chronological)
%     ChannelOrder   (1,:) double  1-based reorder/subset of amplifier channels
%     Scale          (1,1) double  multiplier before cast (default ds.Scale)
%     Offset         (1,1) double  added after scaling (default 0)
%     Dtype          string        on-disk class (default ds.Dtype)
%     Filter         (1,1) logical  high/band-pass before writing (default false)
%     FilterType     "highpass"|"lowpass"|"bandpass" (default "highpass")
%     FilterCutoff   scalar or [lo hi] Hz  (default 300)
%     FilterOrder    (1,1) double          (default 4)
%     FilterEdgeMode "independent"|"overlap" (default "independent")
%     OverlapSamples (1,1) double  samples carried across file edges (overlap mode)
%     Blank          (1,1) logical  force automatic artifact detect + blank.
%                    When false, blanking still runs if ds.ArtifactConfig.Enabled.
%                    ExcludeChannels take no part in the detection, and the
%                    "commonmode" method measures the chunk before the common
%                    reference is subtracted (see detectArtifacts).
%     ArtifactMethod / ArtifactThreshold / ArtifactRmsWindowMs / ArtifactMergeGapMs /
%     ArtifactMinChannels / ArtifactPadMs   detection params; each falls back to
%                    ds.ArtifactConfig when left at its default. See
%                    detectArtifacts (RmsWindow/MergeGap/Pad are in milliseconds).
%     ArtifactIntervals [k x 2] recording-relative seconds to blank instead of
%                    the manual periods and the detector ([] = blank nothing;
%                    default NaN = ManualArtifacts, plus detection as above)
%     ArtifactFill   "noise" | "zero"  what replaces the artifact samples
%                    (default: ds.ArtifactConfig.Fill, "noise"). Kilosort4
%                    reads a block of zeros across every channel as a signal
%                    discontinuity, so each period is filled with a straight
%                    line between the signal's level on either side plus
%                    per-channel Gaussian noise matched to the recording's own
%                    noise level (blankArtifacts): the fill follows the local
%                    broadband level, so its edges leave no step. A period cut
%                    by a chunk boundary is held at the level before it up to
%                    the boundary and continues from there in the next chunk.
%     NoiseBandHz    (1,1) double  band the noise level is measured in: the
%                    level is taken on a high-pass-filtered view of the
%                    recording at this cut-off, the band a sorter works in
%                    (default ds.ArtifactConfig.NoiseBandHz, 300 Hz; 0 =
%                    broadband). Ignored when Filter is on - the level is then
%                    measured through that same write filter.
%     NoiseSeed      (1,1) double  RNG seed for the fill, so the .bin is
%                    reproducible (default NaN: ds.ArtifactConfig.NoiseSeed,
%                    itself 0; set that to NaN for a new draw each run)
%     NoiseLevels    struct  precomputed levels from ds.noiseLevels() (sigma /
%                    center, microvolts, one per written channel). Default
%                    struct([]): toBin measures them itself before it writes,
%                    on up to 16 chunks spread evenly over the recording.
%     WriteMeta      (1,1) logical  write JSON sidecar (default true)
%     BinFile        (1,1) string   override output path (default ds.BinFile);
%                    a bare file name goes in ds.outputFolder()
%
%   toBin never writes over the recording itself: a BinFile (or its JSON
%   sidecar) that is one of the recording's files - a universal-format
%   recording's data file named <Name>.bin in the output folder, say - is
%   refused before anything is opened (EphysDataset:toBin:WouldOverwriteRecording).
%
%   Output INFO struct: filename, dtype, nChan, nSamples, fs, scale, offset,
%   nClipped, nBytes, metaFile (if written), nManualBlanked, nAutoBlanked,
%   artifactFill, noiseFill (struct: bandHz, seed, sigma, center - empty when
%   filling with zeros) and autoArtifact (struct: enabled, method, threshold,
%   rmsWindowMs, mergeGapMs, minChannels, padMs, nBlanked, fraction,
%   pctDuration, nIntervals, channelCounts) and reference (struct: mode -
%   "none" | "car" | "cmr" - and channels, the 1-based channels the
%   common reference was taken over; see applyReference).
%
%   GUARD: every file must have the same amplifier channel count as the first;
%   a flat int16 .bin cannot represent a mid-dataset channel-count change.
%
%   See also MATRIX2KILOSORT, EphysDataset.matrixToBin, EphysDataset.filterContinuous,
%   EphysDataset.noiseLevels, EphysDataset.blankArtifacts.

arguments
    obj (1,1) EphysDataset
    opts.Files (1,:) string = string.empty(1,0)
    opts.ChannelOrder (1,:) double {mustBeInteger, mustBePositive} = []
    opts.Scale (1,1) double = NaN
    opts.Offset (1,1) double {mustBeFinite} = 0
    opts.Dtype (1,1) string = ""
    opts.Filter (1,1) logical = false
    opts.FilterType (1,1) string {mustBeMember(opts.FilterType, ["highpass","lowpass","bandpass"])} = "highpass"
    opts.FilterCutoff (1,:) double {mustBePositive} = 300
    opts.FilterOrder (1,1) double {mustBeInteger, mustBePositive} = 4
    opts.FilterEdgeMode (1,1) string {mustBeMember(opts.FilterEdgeMode, ["independent","overlap"])} = "independent"
    opts.OverlapSamples (1,1) double {mustBeInteger, mustBeNonnegative} = 0
    opts.Blank (1,1) logical = false
    opts.ArtifactMethod (1,1) string = ""
    opts.ArtifactThreshold (1,1) double = NaN
    opts.ArtifactRmsWindowMs (1,1) double = NaN
    opts.ArtifactMergeGapMs (1,1) double = NaN
    opts.ArtifactMinChannels (1,1) double = NaN
    opts.ArtifactPadMs (1,1) double = NaN
    opts.ArtifactFill (1,1) string {mustBeMember(opts.ArtifactFill, ["","noise","zero"])} = ""
    opts.NoiseBandHz (1,1) double = NaN
    opts.NoiseSeed (1,1) double = NaN
    opts.NoiseLevels struct = struct([])
    opts.WriteMeta (1,1) logical = true
    opts.BinFile (1,1) string = ""
    opts.ArtifactIntervals double = NaN
end

if obj.NumFiles == 0
    obj.discoverFiles();
end
if obj.NumFiles == 0
    error('EphysDataset:toBin:NoFiles', 'No recording files in %s', obj.Folder);
end
% Header metadata (Fs, sample counts) drives the stream plan and is needed up
% front for the .bin sidecar; parse it now if it has not been parsed yet.
if isnan(obj.Fs) || isempty(obj.PerFile)
    obj.refreshMetadata();
end

% Resolve config (per-call -> dataset defaults)
scale = opts.Scale;  if isnan(scale); scale = obj.Scale; end
dtype = opts.Dtype;  if dtype == "";  dtype = obj.Dtype; end
binFile = opts.BinFile; if binFile == ""; binFile = obj.BinFile; end
if fileparts(binFile) == ""            % a bare file name goes in the output folder
    binFile = fullfile(obj.outputFolder(), binFile);
end
[mDir, mName] = fileparts(binFile);
metaFile = fullfile(mDir, mName + ".json");
% Never write over the recording itself: a universal-format recording's data
% file can be <Name>.bin in the very folder the .bin goes to by default, and
% opening it for writing would truncate it.
targets = binFile;
if opts.WriteMeta; targets(end+1) = metaFile; end
refuseRecordingFiles(obj, targets, "toBin");

% Settle the common reference's channels before any chunk is read.
obj.prepareReference();

% Resolve automatic artifact-blanking config (per-call -> ds.ArtifactConfig).
% Blanking runs when the Blank option is set OR the dataset config is enabled.
acfg = EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig);
% An explicit ArtifactIntervals list replaces both the detector and the
% manual periods, so the .bin is blanked exactly where the caller says.
[listIv, givenIv] = explicitIntervals(opts.ArtifactIntervals);
if ~givenIv
    listIv = obj.ManualArtifacts;
    if isempty(listIv); listIv = zeros(0, 2); end
end
doBlank   = ~givenIv && (opts.Blank || acfg.Enabled);
artMethod = opts.ArtifactMethod;        if artMethod == "";       artMethod = acfg.Method;      end
artThr    = opts.ArtifactThreshold;     if isnan(artThr);         artThr    = acfg.Threshold;   end
artWinMs  = opts.ArtifactRmsWindowMs;   if isnan(artWinMs);       artWinMs  = acfg.RmsWindowMs;  end
artGapMs  = opts.ArtifactMergeGapMs;    if isnan(artGapMs);       artGapMs  = acfg.MergeGapMs;   end
artMinCh  = opts.ArtifactMinChannels;   if isnan(artMinCh);       artMinCh  = acfg.MinChannels;  end
artPadMs  = opts.ArtifactPadMs;         if isnan(artPadMs);       artPadMs  = acfg.PadMs;        end

% How the flagged samples are erased (what replaces them), as opposed to which
% samples those are.
artFill   = opts.ArtifactFill;          if artFill == "";         artFill   = string(acfg.Fill);  end
noiseBand = opts.NoiseBandHz;           if isnan(noiseBand);      noiseBand = acfg.NoiseBandHz;   end
noiseSeed = opts.NoiseSeed;             if isnan(noiseSeed);      noiseSeed = acfg.NoiseSeed;     end
if ~(isfinite(noiseBand) && noiseBand >= 0)
    error('EphysDataset:toBin:BadNoiseBand', ...
        'NoiseBandHz must be 0 (broadband) or a positive frequency.');
end

% Resolve the streaming plan (one chunk per *.rhd file for traditional Intan;
% bounded sample windows for every other layout). The downstream loop is
% identical for every format because each chunk yields a [nSamp x nChan]
% microvolt matrix from readChunkUV.
plan = obj.streamPlan(Files=opts.Files);
if isempty(plan)
    error('EphysDataset:toBin:NoFiles', 'No readable recording data in %s', obj.Folder);
end

% Ensure output folder exists
if ~isfolder(mDir)
    mkdir(mDir);
end

% dtype -> class + saturation range (mirrors matrix2kilosort)
[targetClass, isFloat, lo, hi] = resolveDtype(dtype);

% Overlap mode needs filtering on
useOverlap = opts.Filter && opts.FilterEdgeMode == "overlap" && opts.OverlapSamples > 0;

% How the artifact samples are erased. "noise" replaces them with a line
% between the levels on either side plus per-channel Gaussian noise at the
% recording's own level instead of zeros, so nothing in the .bin reads to
% Kilosort4 as a signal discontinuity (a zeroed block breaks its whitening,
% threshold and drift estimates). Measuring that level reads up to 16 chunks
% spread over the recording before the writing pass - enough for a robust
% per-channel level (within ~1% of the whole recording's) - and is skipped when
% there is nothing to blank, or when the caller already has the levels.
willBlank  = doBlank || ~isempty(listIv);
noiseFill  = struct([]);
fillStream = [];
if artFill == "noise" && willBlank
    nl = opts.NoiseLevels;
    if isempty(fieldnames(nl))
        fprintf('Measuring the recording''s noise level (%s) for the artifact fill...\n', ...
            bandNote(opts, noiseBand));
        nlArgs = [{'Files', opts.Files, 'ChannelOrder', opts.ChannelOrder, 'MaxChunks', 16}, ...
            noiseFilterArgs(opts, noiseBand)];
        nl = obj.noiseLevels(nlArgs{:});
    elseif ~all(isfield(nl, {'sigma', 'center'}))
        error('EphysDataset:toBin:BadNoiseLevels', ...
            'NoiseLevels needs sigma and center fields (see EphysDataset.noiseLevels).');
    end
    noiseFill = struct('bandHz', noiseBand, 'seed', noiseSeed, ...
        'sigma', double(nl.sigma(:).'), 'center', double(nl.center(:).'));
    % One stream for the whole file, seeded so a rerun writes the same .bin,
    % and kept off the global stream so a caller's own draws stay theirs.
    if isnan(noiseSeed)
        fillStream = RandStream('threefry', 'Seed', 'shuffle');
    else
        fillStream = RandStream('threefry', 'Seed', noiseSeed);
    end
    fprintf('Artifact fill: Gaussian noise, median sigma %.2f uV across %d channel(s).\n', ...
        median(noiseFill.sigma), numel(noiseFill.sigma));
end
if isempty(noiseFill)
    fillArgs = {'Fill', "zero"};
else
    fillArgs = {'Fill', "noise", 'NoiseSigma', noiseFill.sigma, ...
        'NoiseCenter', noiseFill.center, 'Stream', fillStream};
end

% Automatic detection leaves ExcludeChannels out (a dead or broken site - which
% after a common reference also carries the reference's inverse - must not
% erase a period on every channel). The "commonmode" method looks for the mean
% a common reference subtracts, so it measures each chunk before the reference
% is taken, over the channels that take part.
recCh = opts.ChannelOrder;
if isempty(recCh); recCh = 1:obj.NumChannels; end
detCols  = find(~ismember(recCh, obj.ExcludeChannels));   % columns of the written data
cmDetect = doBlank && artMethod == "commonmode";

fid = fopen(binFile, 'w', 'ieee-le');
if fid < 0
    error('EphysDataset:toBin:OpenFailed', 'Could not open %s for writing.', binFile);
end
cleaner = onCleanup(@() closeIfOpen(fid));

firstNumChan = NaN;
nChanOut  = NaN;
nSamples  = 0;
nClipped  = 0;
nManualBlanked = 0;   % samples zeroed by manual artifact periods
nAutoBlanked   = 0;   % samples zeroed by automatic artifact detection
nAutoIntervals = 0;   % contiguous auto-artifact intervals (summed per file)
autoChanCounts = [];  % [1 x nChanOut] per-channel exceedance counts
artWinMsUsed   = NaN; % resolved running-RMS window (ms), for reporting
Fs        = obj.Fs;
tailRaw   = [];  % carried raw samples for overlap edge mode
tailCm    = [];  % the same for the common mode
fillCtx   = [];  % clean samples a run at the top of the next chunk fills from
edgeRows  = max(1, round(1e-3 * Fs));   % the 1 ms blankArtifacts averages at a run's edge

fprintf('Streaming %d chunk(s) -> %s\n', numel(plan), binFile);
for i = 1:numel(plan)
    % [nSamples x nChan], microvolts (all channels), referenced below when it
    % is read as recorded for the common-mode detector
    X = obj.readChunkUV(plan(i), Reference=~cmDetect);

    if isempty(X)
        warning('EphysDataset:toBin:NoData', 'No amplifier data in %s; skipping.', plan(i).name);
        continue
    end

    thisNumChan = size(X, 2);

    % Channel-count guard (flat bin cannot tolerate a change)
    if isnan(firstNumChan)
        firstNumChan = thisNumChan;
    elseif thisNumChan ~= firstNumChan
        error('EphysDataset:toBin:ChannelMismatch', ...
            ['Amplifier channel count changed mid-dataset (%d -> %d) at %s. ', ...
             'A flat int16 .bin cannot represent this.'], ...
            firstNumChan, thisNumChan, plan(i).name);
    end
    if ~isempty(opts.ChannelOrder) && max(opts.ChannelOrder) > thisNumChan
        error('EphysDataset:toBin:BadChannelOrder', ...
            'ChannelOrder references channel %d but file has %d.', ...
            max(opts.ChannelOrder), thisNumChan);
    end

    if cmDetect
        cm = mean(X(:, recCh(detCols)), 2);   % before the reference removes it
        X = obj.applyReference(X);
    end

    % Channel reorder/subset
    if ~isempty(opts.ChannelOrder)
        X = X(:, opts.ChannelOrder);
    end
    if isnan(nChanOut)
        nChanOut = size(X, 2);
    end

    % Filtering (optionally with overlap across file boundaries)
    if opts.Filter
        [X, tailRaw] = filterChunk(obj, X, tailRaw, opts, useOverlap, Fs);
        if cmDetect
            [cm, tailCm] = filterChunk(obj, cm, tailCm, opts, useOverlap, Fs);
        end
    end

    % The samples to erase: the automatic detector's (per-channel amplitude
    % deviation, or the common mode) and the listed periods - the
    % ArtifactIntervals option, else the manual periods (Visualize tab).
    % Those are recording-relative, so they are mapped into this chunk with
    % the running sample offset (nSamples = samples written from earlier
    % chunks). Both are erased in one pass, so a fill spans each whole run.
    erase = false(size(X, 1), 1);
    if doBlank
        if cmDetect
            [amask, ~, astats] = obj.detectArtifacts(cm, Method="commonmode", ...
                Threshold=artThr, MergeGapMs=artGapMs, PadMs=artPadMs, Fs=Fs);
            counts = zeros(1, size(X, 2));
            counts(detCols) = astats.channelExceedCounts;
        else
            [amask, ~, astats] = obj.detectArtifacts(X, Method=artMethod, ...
                Threshold=artThr, RmsWindowMs=artWinMs, MinChannels=artMinCh, ...
                MergeGapMs=artGapMs, PadMs=artPadMs, Fs=Fs, Channels=detCols);
            counts = astats.channelExceedCounts;
        end
        erase = amask;
        nAutoBlanked   = nAutoBlanked + nnz(amask);
        nAutoIntervals = nAutoIntervals + astats.numIntervals;
        if isempty(autoChanCounts)
            autoChanCounts = counts;
        else
            autoChanCounts = autoChanCounts + counts;
        end
        if isnan(artWinMsUsed); artWinMsUsed = astats.rmsWindowMs; end
    end
    if ~isempty(listIv)
        mmask = obj.manualArtifactMask(size(X, 1), nSamples, Fs, listIv);
        nManualBlanked = nManualBlanked + nnz(mmask);
        erase = erase | mmask;
    end
    if any(erase)
        X = obj.blankArtifacts(X, erase, fillArgs{:}, Context=fillCtx);
    end
    if ~isempty(noiseFill)
        fillCtx = fillContext(fillCtx, X, erase, edgeRows);
    end

    % Scale -> [nChan x nSamples] (channel fastest) -> cast -> write
    blk = X.';                                   % [nChan x nSamplesThisFile]
    blk = scale .* double(blk) + opts.Offset;
    if ~isFloat
        nClipped = nClipped + nnz(blk < lo | blk > hi);
    end
    blk = cast(blk, targetClass);
    fwrite(fid, blk, targetClass);

    nSamples = nSamples + size(X, 1);
end

clear cleaner;  % closes fid

if isnan(nChanOut)
    error('EphysDataset:toBin:NoDataWritten', 'No data was written (all files empty?).');
end

d = dir(binFile);
info = struct();
info.filename  = char(binFile);
info.dtype     = char(dtype);
info.nChan     = nChanOut;
info.nSamples  = nSamples;
info.fs        = Fs;
info.scale     = scale;
info.offset    = opts.Offset;
info.byteOrder = 'little-endian';
info.nClipped  = nClipped;
info.nManualArtifacts = size(listIv, 1);
info.nManualBlanked   = nManualBlanked;
info.nAutoBlanked     = nAutoBlanked;
info.artifactFill     = char(artFill);
info.noiseFill        = noiseFill;
if isempty(autoChanCounts); autoChanCounts = zeros(1, nChanOut); end
info.autoArtifact = struct( ...
    'enabled',       doBlank, ...
    'method',        char(artMethod), ...
    'threshold',     artThr, ...
    'rmsWindowMs',   artWinMsUsed, ...
    'mergeGapMs',    artGapMs, ...
    'minChannels',   artMinCh, ...
    'padMs',         artPadMs, ...
    'nBlanked',      nAutoBlanked, ...
    'fraction',      nAutoBlanked / max(nSamples, 1), ...
    'pctDuration',   100 * nAutoBlanked / max(nSamples, 1), ...
    'nIntervals',    nAutoIntervals, ...
    'channelCounts', autoChanCounts);
info.nBytes    = d.bytes;
info.reference = referenceInfo(obj);

filled = ternary(artFill == "noise", "noise-filled", "zeroed");
if doBlank
    fprintf(['Auto artifacts (%s, thr=%g): %d samples (%.3f s, %.2f%%) %s ' ...
        'in %d interval(s).\n'], artMethod, artThr, nAutoBlanked, ...
        nAutoBlanked / max(Fs, 1), info.autoArtifact.pctDuration, filled, nAutoIntervals);
end

if nManualBlanked > 0
    fprintf('Blanked %d listed artifact period(s): %d samples (%.3f s) %s.\n', ...
        info.nManualArtifacts, nManualBlanked, nManualBlanked / max(Fs, 1), filled);
end

if nClipped > 0
    warning('EphysDataset:toBin:Clipping', ...
        '%d sample(s) (%.4f%%) saturated the %s range and were clipped.', ...
        nClipped, 100*nClipped/(nChanOut*max(nSamples,1)), dtype);
end

% JSON sidecar (bookkeeping; Kilosort4 does not read it)
if opts.WriteMeta
    meta = struct('n_chan_bin', nChanOut, 'fs', Fs, 'dtype', char(dtype), ...
        'n_samples', nSamples, 'byte_order', 'little-endian', 'scale', scale, ...
        'offset', opts.Offset, 'bin_file', char(binFile), ...
        'source_folder', char(obj.Folder), ...
        'manual_artifacts', listIv, ...
        'n_manual_blanked', nManualBlanked, ...
        'artifact_fill', char(artFill), ...
        'auto_artifacts', info.autoArtifact, ...
        'reference', info.reference, ...
        'created', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    % Assigned, not passed to struct(): an empty struct value there would
    % collapse the whole meta struct to 0x0.
    meta.noise_fill = noiseFill;
    writeJson(meta, metaFile);
    info.metaFile = char(metaFile);
end

if ~isempty(obj.Manifest) && isa(obj.Manifest, 'Manifest')
    obj.Manifest.add("toBin", "Wrote Kilosort4 .bin", ...
        struct('binFile', info.filename, 'nChan', info.nChan, ...
        'nSamples', info.nSamples, 'fs', info.fs, ...
        'filtered', opts.Filter, 'blanked', doBlank, ...
        'fill', char(artFill), 'autoBlanked', nAutoBlanked, ...
        'manualArtifacts', info.nManualArtifacts, ...
        'manualBlanked', nManualBlanked));
end

fprintf('Done. %.2f MB written (%s, little-endian); n_chan_bin=%d, fs=%g\n', ...
    info.nBytes/1e6, info.dtype, info.nChan, info.fs);
end


function r = referenceInfo(obj)
%referenceInfo  The common reference the chunks were read with (applyReference).
acfg = EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig);
r = struct('mode', char(acfg.Reference), 'channels', double.empty(1, 0));
if string(acfg.Reference) ~= "none"
    r.channels = obj.referenceChannels();
end
end


function [X, tail] = filterChunk(obj, X, tail, opts, useOverlap, Fs)
%filterChunk  The write filter on one chunk; in the overlap edge mode the raw
%   TAIL of the previous chunk is filtered with it, and this chunk's is
%   returned for the next.
if useOverlap && ~isempty(tail)
    nPad = size(tail, 1);
    Xf = obj.filterContinuous([tail; X], Type=opts.FilterType, ...
        Cutoff=opts.FilterCutoff, Order=opts.FilterOrder, Fs=Fs);
    Xf = Xf(nPad+1:end, :);
else
    Xf = obj.filterContinuous(X, Type=opts.FilterType, ...
        Cutoff=opts.FilterCutoff, Order=opts.FilterOrder, Fs=Fs);
end
if useOverlap
    k = min(opts.OverlapSamples, size(X, 1));
    tail = X(end-k+1:end, :);  % carry RAW (pre-filter) tail
end
X = Xf;
end


function ctx = fillContext(ctx, X, erase, w)
%fillContext  The clean samples a run at the top of the next chunk fills from.
%   Up to W of the chunk's last clean rows, not reaching back into a run:
%   its final rows when it ends clean, else the rows before the run it ends
%   in. A chunk erased from its first row to its last keeps CTX, the rows
%   before the run it continues.
last = find(~erase, 1, 'last');
if isempty(last)
    return
end
prev = find(erase(1:last), 1, 'last');      % the run before that clean stretch
if isempty(prev); prev = 0; end
ctx = X(max(prev + 1, last - w + 1):last, :);
end


function args = noiseFilterArgs(opts, noiseBand)
%noiseFilterArgs  noiseLevels filter options for what this call writes.
%   The fill has to sit in the same band as the signal around it, so the level
%   is measured through the write filter when toBin filters, and otherwise on a
%   high-pass view at NoiseBandHz - the spike band Kilosort4 filters down to,
%   where a broadband level would overstate the noise by the whole LFP.
if opts.Filter
    args = {'Filter', true, 'FilterType', opts.FilterType, ...
        'FilterCutoff', opts.FilterCutoff, 'FilterOrder', opts.FilterOrder};
elseif noiseBand > 0
    args = {'Filter', true, 'FilterType', "highpass", ...
        'FilterCutoff', noiseBand, 'FilterOrder', 4};
else
    args = {'Filter', false};
end
end


function s = bandNote(opts, noiseBand)
%bandNote  How noiseFilterArgs measured the level, for the console.
if opts.Filter
    s = "through the write filter";
elseif noiseBand > 0
    s = sprintf("above %g Hz", noiseBand);
else
    s = "broadband";
end
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end


function [targetClass, isFloat, lo, hi] = resolveDtype(dtype)
switch dtype
    case "int16"
        targetClass = 'int16';  isFloat = false; lo = -32768;      hi = 32767;
    case "uint16"
        targetClass = 'uint16'; isFloat = false; lo = 0;           hi = 65535;
    case "int32"
        targetClass = 'int32';  isFloat = false; lo = -2147483648; hi = 2147483647;
    case {"single","float32"}
        targetClass = 'single'; isFloat = true;  lo = -inf;        hi = inf;
    otherwise
        error('EphysDataset:toBin:BadDtype', 'Unsupported dtype "%s".', dtype);
end
end


function writeJson(s, file)
try
    txt = jsonencode(s, 'PrettyPrint', true);
catch
    txt = jsonencode(s);
end
fid = fopen(file, 'w');
if fid < 0
    warning('EphysDataset:toBin:MetaWriteFailed', 'Could not write %s', file);
    return
end
fwrite(fid, txt, 'char');
fclose(fid);
end


function closeIfOpen(fid)
if ~isempty(fopen(fid))
    fclose(fid);
end
end
