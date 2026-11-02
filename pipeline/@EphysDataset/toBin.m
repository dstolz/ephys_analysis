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
%     Scale          (1,1) double  multiplier before cast (default ds.binScale(Dtype):
%                    ds.Scale when set, else the recording's own resolution
%                    when one stored unit maps onto one .bin unit, else 1/0.195;
%                    info.scaleSource and the sidecar's scale_source say which)
%     Offset         (1,1) double  added after scaling (default 0)
%     Dtype          string        on-disk class (default ds.Dtype)
%     Filter         (1,1) logical  high/band-pass before writing (default false)
%     FilterType     "highpass"|"lowpass"|"bandpass" (default "highpass")
%     FilterCutoff   scalar or [lo hi] Hz  (default 300)
%     FilterOrder    (1,1) double          (default 4)
%     FilterEdgeMode "independent"|"overlap" (default "independent")
%     OverlapSamples (1,1) double  samples carried across chunk edges (overlap
%                    mode, K): each chunk is filtered with the last 2K raw
%                    rows of the one before in front of it and its own last K
%                    rows are held back, to be filtered again with the next
%                    chunk after them (a look-ahead), so neither the start nor
%                    the end of a chunk carries the filter's edge transient;
%                    only the recording's own first and last rows do. The held
%                    rows are written with the next chunk (or at the end).
%     Blank          (1,1) logical  force automatic artifact detect + blank.
%                    When false, blanking still runs if ds.ArtifactConfig.Enabled.
%                    The periods are artifactIntervals' over the whole recording
%                    (with the bounds moved by hand, ArtifactAdjustments), found
%                    before anything is written, so they are the ones the
%                    Signals and Spikes steps erase, whatever Files,
%                    ChannelOrder and the write filter are: the detection
%                    reads through ds.ArtifactConfig's own filter and leaves
%                    ExcludeChannels out.
%     ArtifactMethod / ArtifactThreshold / ArtifactRmsWindowMs / ArtifactMergeGapMs /
%     ArtifactMinChannels / ArtifactPadMs   detection params; each falls back to
%                    ds.ArtifactConfig when left at its default. See
%                    artifactIntervals (RmsWindow/MergeGap/Pad are in milliseconds).
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
%                    a bare file name goes in ds.binFolder()
%     Reuse          (1,1) logical  keep the .bin that is there when its
%                    sidecar's fingerprint is this call's (default false):
%                    nothing is written, info.reused is true and INFO is
%                    rebuilt from the sidecar. The fingerprint (sidecar field
%                    "fingerprint") is a hash of the recording's files and
%                    sizes, the chunks, channel order, dtype, scale, offset,
%                    write filter, the periods erased (listed, automatic
%                    settings and bounds moved by hand; fill, noise band and seed) and the common
%                    reference; runKilosort sets it, so a second sort of the
%                    same data does not write the .bin again. A fill with a
%                    new random draw each time (NoiseSeed NaN) is never reused.
%
%   The .bin is written under BinFile + ".partial", after the previous
%   sidecar was deleted, checked for its size and renamed to BinFile, and
%   the sidecar is written last: a crash or a full disk leaves no .bin that
%   looks complete (the partial is removed on an error), and a sidecar
%   always belongs to the .bin beside it. A reader that has BinFile open
%   (a sort running) keeps the rename from replacing it
%   (EphysDataset:toBin:MoveFailed).
%
%   toBin never writes over the recording itself: a BinFile (or its JSON
%   sidecar) that is one of the recording's files - a universal-format
%   recording's data file named <Name>.bin in the output folder, say - is
%   refused before anything is opened (EphysDataset:toBin:WouldOverwriteRecording).
%
%   Output INFO struct: reused (true when Reuse kept the .bin, see above),
%   filename, dtype, nChan, nSamples, fs, scale,
%   scaleSource (where the scale came from, see Scale), offset,
%   nClipped, nBytes, metaFile (if written), nManualBlanked, nAutoBlanked,
%   artifactFill, noiseFill (struct: bandHz, seed, sigma, center - empty when
%   filling with zeros) and autoArtifact (struct: enabled, method, threshold,
%   rmsWindowMs, mergeGapMs, minChannels, padMs, nBlanked and fraction and
%   pctDuration of the samples written; nIntervals, the recording's, and
%   channelCounts, one per written channel) and reference (struct: mode -
%   "none" | "car" | "cmr" | "wcar" - and channels, the 1-based channels the
%   common reference was taken over, see applyReference; for "wcar" also
%   wcar: the weighted CAR's options, its Q and whether it was automatic,
%   see prepareWCAR). runKilosort and runSpikeInterface read the mode from
%   the sidecar, so a sorter adds no common reference of its own to a .bin
%   that carries one. Writing ds.BinFile, ds.Processing.bin records how the
%   .bin was made (every option as resolved, the reference, the artifact
%   periods erased and the fill's noise levels) for the manifest's
%   processing block.
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
    opts.Reuse (1,1) logical = false
    opts.ArtifactIntervals double = NaN
    opts.Provenance = []   % ephysProvenance() of the run writing it ([] = made here)
end
prov = opts.Provenance;
if isempty(prov); prov = ephysProvenance(); end

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
dtype = opts.Dtype;  if dtype == "";  dtype = obj.Dtype; end
scale = opts.Scale;
scaleSource = "set: Scale=";
if isnan(scale); [scale, scaleSource] = obj.binScale(dtype); end
binFile = opts.BinFile; if binFile == ""; binFile = obj.BinFile; end
if fileparts(binFile) == ""            % a bare file name goes in the output folder
    binFile = fullfile(obj.binFolder(), binFile);
end
[mDir, mName] = fileparts(binFile);
metaFile = fullfile(mDir, mName + ".json");
% Never write over the recording itself: a universal-format recording's data
% file can be <Name>.bin in the very folder the .bin goes to by default, and
% opening it for writing would truncate it.
targets = binFile;
if opts.WriteMeta; targets(end+1) = metaFile; end
refuseRecordingFiles(obj, targets, "toBin");

% Settle the common reference's channels (and the weighted CAR's state)
% before any chunk is read.
obj.prepareReference();
obj.prepareWCAR();

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
artMethod = opts.ArtifactMethod;       if artMethod == "";       artMethod = acfg.Method;      end
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

% What decides the .bin's content, as a hash: the sidecar records it, and a
% Reuse call keeps a .bin whose sidecar has the same one.
fingerprint = binFingerprint(obj, plan, opts, struct('dtype', dtype, 'scale', scale, 'offset', opts.Offset, ...
    'blank', doBlank, 'method', artMethod, 'threshold', artThr, 'rmsWindowMs', artWinMs, ...
    'mergeGapMs', artGapMs, 'minChannels', artMinCh, 'padMs', artPadMs, 'listed', listIv, ...
    'detection', EphysDataset.detectionSettings(acfg), 'adjustments', obj.ArtifactAdjustments, ...
    'fill', artFill, 'noiseBandHz', noiseBand, 'noiseSeed', noiseSeed, ...
    'reference', EphysDataset.referenceRecord(obj.referenceInfo())));
if opts.Reuse && ~(artFill == "noise" && (doBlank || ~isempty(listIv)) && isnan(noiseSeed))
    info = reusedBin(binFile, metaFile, fingerprint, dtype);
    if ~isempty(info)
        fprintf('Reused %s: its sidecar matches this recording and these settings (%.2f MB, not written again).\n', ...
            binFile, info.nBytes / 1e6);
        return
    end
end

% The automatic periods, before anything is written: the recording-wide
% detection the Signals and Spikes steps take, with the bounds moved by hand.
autoIv = zeros(0, 2);
detected = struct('channelCounts', [], 'rmsWindowMs', NaN);
if doBlank
    fprintf('Detecting artifacts over the recording (%s)...\n', artMethod);
    [autoIv, detected] = obj.artifactIntervals(IncludeAuto=true, IncludeManual=false, ...
        Method=artMethod, Threshold=artThr, RmsWindowMs=artWinMs, MergeGapMs=artGapMs, ...
        MinChannels=artMinCh, PadMs=artPadMs);
    autoIv = obj.adjustArtifacts(autoIv);
end

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

% The sidecar of the .bin that is there goes first (it describes that one),
% and the new one is written under another name, renamed once it is whole.
partialFile = binFile + ".partial";
if opts.WriteMeta && isfile(metaFile)
    delete(metaFile);
end
fid = fopen(partialFile, 'w', 'ieee-le');
if fid < 0
    error('EphysDataset:toBin:OpenFailed', 'Could not open %s for writing.', partialFile);
end
cleaner = onCleanup(@() abandonPartial(fid, partialFile));   % an error leaves no partial file

firstNumChan = NaN;
nChanOut  = NaN;
nSamples  = 0;
nClipped  = 0;
nNonFinite = 0;       % NaN / Inf samples, written as 0 by the cast
nManualBlanked = 0;   % samples zeroed by manual artifact periods
nAutoBlanked   = 0;   % samples zeroed by automatic artifact detection
nErased        = 0;   % samples erased by either (each counted once)
nAutoIntervals = size(autoIv, 1);   % the recording's automatic periods
autoChanCounts = detected.channelCounts;   % [1 x nChan] per-channel exceedance counts
if ~isempty(autoChanCounts) && ~isempty(opts.ChannelOrder)
    autoChanCounts = autoChanCounts(opts.ChannelOrder);   % those written
end
artWinMsUsed   = detected.rmsWindowMs;   % resolved running-RMS window (ms), for reporting
Fs        = obj.Fs;
fstate    = struct('raw', zeros(0, 0), 'pending', 0);   % overlap mode: the raw rows carried, how many of them are held back
posNext   = 0;  % recording-global index (0-based) of the next row written
fillCtx   = [];  % clean samples a run at the top of the next chunk fills from
edgeRows  = max(1, round(1e-3 * Fs));   % the 1 ms blankArtifacts averages at a run's edge

fprintf('Streaming %d chunk(s) -> %s\n', numel(plan), binFile);
% In the overlap mode one pass more writes the rows held back after the last chunk.
for i = 1:numel(plan) + double(useOverlap)
    flush = i > numel(plan);
    if flush && fstate.pending == 0
        break
    end
    if flush
        X = zeros(0, size(fstate.raw, 2));   % the filter returns the rows held back
    else
        % [nSamples x nChan], microvolts (all channels), common-referenced
        X = obj.readChunkUV(plan(i));

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

        % Channel reorder/subset
        if ~isempty(opts.ChannelOrder)
            X = X(:, opts.ChannelOrder);
        end
        if isnan(nChanOut)
            nChanOut = size(X, 2);
        end
    end

    % Filtering. With the overlap edge mode the block that comes back is the
    % rows held back from the chunk before and this chunk less its last
    % OverlapSamples, each with its context on both sides.
    pendingBefore = fstate.pending;   % rows held back from the chunk before
    if opts.Filter
        if useOverlap
            [X, fstate] = filterOverlap(obj, X, fstate, opts, Fs, flush);
        else
            X = filterChunk(obj, X, opts, Fs);
        end
        if isempty(X)
            continue   % a chunk shorter than the rows held back
        end
    end

    % Where the block starts in the recording (0-based): the chunk's own
    % place there (a Files subset need not start at the first sample), less
    % the rows held back that come before it; the running count when the
    % reader does not give one.
    if ~flush && isfinite(plan(i).sampleOffset)
        posNext = plan(i).sampleOffset - pendingBefore;
    end

    % The samples to erase: the automatic periods (above) and the listed
    % ones - the ArtifactIntervals option, else the manual periods (Visualize
    % tab). Those are recording-relative, so they are mapped into this block
    % with its place in the recording (posNext, from the chunk's sampleOffset,
    % else the samples written so far). Both are erased in one pass, so a
    % fill spans each whole run.
    erase = false(size(X, 1), 1);
    if ~isempty(autoIv)
        erase = obj.manualArtifactMask(size(X, 1), posNext, Fs, autoIv);
        nAutoBlanked = nAutoBlanked + nnz(erase);
    end
    if ~isempty(listIv)
        mmask = obj.manualArtifactMask(size(X, 1), posNext, Fs, listIv);
        nManualBlanked = nManualBlanked + nnz(mmask);
        erase = erase | mmask;
    end
    if any(erase)
        X = obj.blankArtifacts(X, erase, fillArgs{:}, Context=fillCtx);
        nErased = nErased + nnz(erase);
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
    nNonFinite = nNonFinite + nnz(~isfinite(blk));
    blk = cast(blk, targetClass);
    nW = fwrite(fid, blk, targetClass);
    if nW ~= numel(blk)
        error('EphysDataset:toBin:ShortWrite', ...
            'Only %d of %d values could be written to %s (disk full?); the file is incomplete.', nW, numel(blk), binFile);
    end

    nSamples = nSamples + size(X, 1);
    posNext = posNext + size(X, 1);
end

closeIfOpen(fid);

if isnan(nChanOut)
    error('EphysDataset:toBin:NoDataWritten', 'No data was written (all files empty?).');
end

d = dir(partialFile);
bytesPer = numel(typecast(cast(0, targetClass), 'uint8'));
if d.bytes ~= nChanOut * nSamples * bytesPer
    error('EphysDataset:toBin:SizeMismatch', ...
        '%s holds %d bytes, not the %d of %d channels x %d samples written; the file is not usable.', ...
        partialFile, d.bytes, nChanOut * nSamples * bytesPer, nChanOut, nSamples);
end
% Whole: it takes the .bin's name (the partial goes with an error, see cleaner).
[moved, moveMsg] = movefile(partialFile, binFile, 'f');
if ~moved
    error('EphysDataset:toBin:MoveFailed', ...
        'Could not rename the finished %s to %s (%s). Is a sort using the .bin?', partialFile, binFile, moveMsg);
end
if nNonFinite > 0
    warning('EphysDataset:toBin:NonFinite', ...
        '%d sample(s) were not finite (NaN or Inf) and were written as 0 in %s.', nNonFinite, binFile);
end
info = struct();
info.filename  = char(binFile);
info.dtype     = char(dtype);
info.nChan     = nChanOut;
info.nSamples  = nSamples;
info.fs        = Fs;
info.scale     = scale;
info.scaleSource = scaleSource;
info.offset    = opts.Offset;
info.byteOrder = 'little-endian';
info.reused    = false;
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
info.reference = obj.referenceInfo();

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
        'scale_source', char(scaleSource), ...
        'offset', opts.Offset, 'bin_file', char(binFile), ...
        'source_folder', char(obj.Folder), ...
        'manual_artifacts', listIv, ...
        'n_manual_blanked', nManualBlanked, ...
        'artifact_fill', char(artFill), ...
        'auto_artifacts', info.autoArtifact, ...
        'reference', info.reference, ...
        'fingerprint', char(fingerprint), ...
        'created', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    % Assigned, not passed to struct(): an empty struct value there would
    % collapse the whole meta struct to 0x0.
    meta.noise_fill = noiseFill;
    meta.provenance = provenanceForJson(prov);
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

% How the dataset's .bin was made, for the manifest (Processing); a .bin
% written elsewhere (BinFile) is the caller's.
if EphysDataset.pathKey(binFile) == EphysDataset.pathKey(obj.BinFile)
    o = rmfield(opts, {'BinFile', 'WriteMeta', 'NoiseLevels', 'ArtifactIntervals'});   % the file; data
    o.Scale = scale;   % each as resolved
    o.ScaleSource = scaleSource;
    o.Dtype = dtype;
    o.Blank = doBlank;   % the automatic detection ran while writing
    o.ArtifactMethod = artMethod;
    o.ArtifactThreshold = artThr;
    o.ArtifactRmsWindowMs = artWinMs;
    if ~isnan(artWinMsUsed); o.ArtifactRmsWindowMs = artWinMsUsed; end   % "auto" as resolved
    o.ArtifactMergeGapMs = artGapMs;
    o.ArtifactMinChannels = artMinCh;
    o.ArtifactPadMs = artPadMs;
    o.ArtifactFill = artFill;
    o.NoiseBandHz = noiseBand;
    o.NoiseSeed = noiseSeed;
    r = EphysDataset.processingRecord("file", binFile, prov, o);
    r.reference = EphysDataset.referenceRecord(info.reference);
    r.filter = filterNote(opts);
    r.artifacts = struct('listed', size(listIv, 1), 'detected', nAutoIntervals, ...
        'erased_s', nErased / Fs, 'fill', string(artFill));
    r.noise_fill = [];   % the levels the fill was drawn at
    if ~isempty(noiseFill); r.noise_fill = EphysDataset.optionsRecord(noiseFill); end
    r.n_clipped = nClipped;
    obj.Processing.bin = r;
end

fprintf('Done. %.2f MB written (%s, little-endian); n_chan_bin=%d, fs=%g\n', ...
    info.nBytes/1e6, info.dtype, info.nChan, info.fs);
end


function s = filterNote(opts)
%filterNote  The write filter in words ("none" when off), for the manifest.
s = "none";
if opts.Filter
    s = sprintf("%s %s Hz, order %d", opts.FilterType, ...
        strjoin(compose("%g", opts.FilterCutoff), "-"), opts.FilterOrder);
    if opts.FilterEdgeMode == "overlap" && opts.OverlapSamples > 0
        s = s + sprintf(", overlap %d samples (look-ahead at the chunk ends)", opts.OverlapSamples);
    end
end
end


function X = filterChunk(obj, X, opts, Fs)
%filterChunk  The write filter on one chunk, edge to edge (FilterEdgeMode "independent").
X = obj.filterContinuous(X, Type=opts.FilterType, ...
    Cutoff=opts.FilterCutoff, Order=opts.FilterOrder, Fs=Fs);
end


function [Y, st] = filterOverlap(obj, X, st, opts, Fs, last)
%filterOverlap  The write filter on one chunk with its neighbors in view
%   (FilterEdgeMode "overlap", K = OverlapSamples).
%   ST.raw holds the last (up to) 2K raw rows seen so far and ST.pending the
%   last of them that were held back unwritten (K, fewer at the start). The
%   chunk X is filtered behind ST.raw, and Y is every filtered row not
%   written yet but the last K, which the window's end transient has
%   touched: the rows held back before, now with context after them, and X
%   less its last K. The window's start is never kept (ST.raw gives it 2K
%   rows, K of them already written), so only the recording's first and last
%   rows carry an edge transient. LAST (after the last chunk, X empty)
%   returns all that is left.
k = opts.OverlapSamples;
win = [st.raw; X];
Yf = obj.filterContinuous(win, Type=opts.FilterType, ...
    Cutoff=opts.FilterCutoff, Order=opts.FilterOrder, Fs=Fs);
first = size(st.raw, 1) - st.pending + 1;       % the first row not written
stop = size(win, 1);
if ~last; stop = stop - k; end
stop = max(stop, first - 1);
Y = Yf(first:stop, :);
st.pending = size(win, 1) - stop;
st.raw = win(max(1, size(win, 1) - 2 * k + 1):end, :);
if last; st.pending = 0; end
end


function ok = abandonPartial(fid, partialFile)
%abandonPartial  Close the .bin being written and remove it unless it was renamed.
%   Runs when toBin ends: after the rename the partial file is gone, so only
%   an error (or an interrupt) removes anything.
closeIfOpen(fid);
if isfile(partialFile)
    delete(partialFile);
end
ok = true;
end


function fp = binFingerprint(obj, plan, opts, settings)
%binFingerprint  A hash of everything that decides the content of the .bin.
%   The recording (its files and their sizes, rate, channels and length),
%   the chunks of the plan, the channel order and the SETTINGS the call
%   resolved (dtype, scale, offset, the periods erased and how, the common
%   reference) with the write filter. Equal fingerprints mean the same .bin.
files = cellstr(obj.Files(:).');
bytes = zeros(1, numel(files));
for j = 1:numel(files)
    L = dir(fullfile(char(obj.Folder), files{j}));
    if ~isempty(L); bytes(j) = L(1).bytes; end
end
recording = struct('files', {files}, 'bytes', bytes, 'fs', obj.Fs, 'numChannels', obj.NumChannels, ...
    'numSamples', obj.NumSamples);
chunks = struct('name', {cellstr(string({plan.name}))}, 'offset', [plan.sampleOffset], 'n', [plan.nSamples]);
filt = struct('on', opts.Filter, 'type', opts.FilterType, 'cutoff', opts.FilterCutoff, ...
    'order', opts.FilterOrder, 'edge', opts.FilterEdgeMode, 'overlap', opts.OverlapSamples);
fp = EphysDataset.optionsHash(struct('schema', "toBin/3",'recording', recording, 'chunks', chunks, ...
    'channelOrder', opts.ChannelOrder, 'filter', filt, 'excluded', obj.excludedChannels(), 'settings', settings));
end


function info = reusedBin(binFile, metaFile, fingerprint, dtype)
%reusedBin  INFO rebuilt from the sidecar of a .bin that is whole and has FINGERPRINT, else [].
info = [];
if ~(isfile(binFile) && isfile(metaFile)); return; end
meta = readJsonFile(metaFile, ErrorOnFail=false);
need = {'fingerprint', 'n_chan_bin', 'n_samples', 'fs', 'dtype', 'scale', 'offset'};
if ~(isstruct(meta) && all(isfield(meta, need)) && string(meta.fingerprint) == fingerprint ...
        && string(meta.dtype) == dtype)
    return
end
cls = resolveDtype(dtype);
bytesPer = numel(typecast(cast(0, cls), 'uint8'));
d = dir(binFile);
if d.bytes ~= double(meta.n_chan_bin) * double(meta.n_samples) * bytesPer; return; end
info = struct('filename', char(binFile), 'dtype', char(dtype), 'nChan', double(meta.n_chan_bin), ...
    'nSamples', double(meta.n_samples), 'fs', double(meta.fs), 'scale', double(meta.scale), ...
    'scaleSource', '', 'offset', double(meta.offset), 'byteOrder', 'little-endian', 'reused', true, ...
    'nBytes', d.bytes, 'metaFile', char(metaFile));
if isfield(meta, 'scale_source'); info.scaleSource = char(string(meta.scale_source)); end
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
