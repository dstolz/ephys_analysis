function [Y, ev, info] = deriveSignals(obj, opts)
%deriveSignals  Read the recording and derive LFP, MUA and/or spike-band signals.
%   [Y, EVENTS, INFO] = ds.deriveSignals(Name=Value) reads the whole recording
%   through EphysDataset.readData -- so every supported layout works
%   (traditional *.rhd, one-file-per-signal, one-file-per-channel) -- then
%   derives the requested continuous signals and the digital-input events.
%   This is the implementation behind INTAN2MATLAB, which is a thin wrapper
%   around it: option names, processing and outputs are the same.
%
%   Outputs
%   -------
%   Y       struct with fields LFP, MUA, SPIKE (nSamples x nChan single) and
%           AUX. Only the fields requested in dataTypeOut are filled; the
%           others are single([]). Row k of a signal is at t = (k-1)/Fs, Fs
%           being INFO.<type>.Fs.
%       Y.LFP   amplifier data resampled to LFP_Fs, then (only if requested)
%               zero-phase Butterworth band-limiting LFP_bpLoHi and notch
%               filters LFP_NotchHz, designed and applied at LFP_Fs. With the
%               defaults no filter beyond RESAMPLE's anti-aliasing is applied.
%       Y.MUA   zero-phase 4th-order Butterworth bandpass MUA_bpLoHi (designed
%               and applied at the original rate), rectified (ABS), resampled
%               to MUA_Fs, then moving-mean integrated on that grid with a
%               window of round(MUA_Fs/MUA_IntegrationHz) samples.
%       Y.SPIKE optionally resampled to SPIKE_Fs (Inf = original rate), then a
%               zero-phase 4th-order Butterworth bandpass SPIKE_bpLoHi
%               designed at SPIKE_Fs.
%       Every filter runs in double precision, a block of channels at a
%       time: the MUA and SPIKE bandpasses through
%       EphysDataset.filterContinuous (FILTFILT), the LFP filters as
%       second-order sections with FILTFILT. The results are stored as
%       single.
%       Y.AUX   the auxiliary inputs (the headstage accelerometer, 3 per Intan
%               headstage) unprocessed, [nSamples x nAux] single VOLTS at their
%               own rate (info.AUX.Fs). Not affected by keepAmpChannels,
%               badChannels or channelRemap. When the recording has no aux
%               inputs Y.AUX stays empty, info.AUX is absent and a
%               EphysDataset:deriveSignals:NoAux warning is issued.
%   EVENTS  struct, one field per digital input line (named by labelField
%           and lineNames, see EphysDataset.relabelEvents), each [k x 2]
%           [t_on t_off] in seconds on the original amplifier time base.
%   INFO    struct: recordingFolder, filenames, recordingFormat, labels
%           (amplifier labels from labelField, in the column order of Y), origFs,
%           invertedLines (the lines whose events are low runs), badChannels
%           (the interpolation, see below), LFP/MUA/SPIKE sub-structs (Fs,
%           nSamples; LFP also bpLoHi, NotchHz, NotchBW and a text
%           description of the filter applied; MUA also IntegrationHz and
%           bpLoHi) for the requested types, AUX (Fs, nSamples, labels,
%           units) when present, and importOptions (the options used, with
%           LFP_Fs / MUA_Fs / SPIKE_Fs the rates produced, SPIKE_Fs = origFs
%           when Inf, badChannels the columns actually interpolated, and
%           labelField / lineNames / invertedLines as resolved).
%           INFO.badChannels: columns (the interpolated columns, before
%           channelRemap), channels (their recording channels), method per
%           column ("geometry" | "columns") and weights [nKept x nBad] (each
%           geometry column's weights over the kept columns, summing to 1;
%           zero for a "columns" fill).
%
%   Options
%   -------
%     dataTypeOut        string array  "LFP"   any of "LFP", "MUA", "SPIKE",
%                        "AUX"
%     keepAmpChannels    integer vector []     1-based amplifier channels to
%                        read, in this order, before all processing
%     channelRemap       integer vector []     final column order (1-based into
%                        the kept channels), applied after processing;
%                        INFO.labels is reordered to match
%     badChannels        integer vector or negative scalar []  COLUMNS of the
%                        kept data (after keepAmpChannels, before
%                        channelRemap: column c is recording channel
%                        keepAmpChannels(c)) replaced in every signal by
%                        interpolation from the probe geometry
%                        (channelLayout of probeFile, else of the dataset's
%                        ProbeFile): the inverse-distance
%                        weighted mean of the 4 nearest good sites on the same
%                        shank (and any as near as the 4th). Without a probe
%                        layout, and for a channel off the probe or with no
%                        good site on its shank, a
%                        EphysDataset:deriveSignals:BadChannelGeometry warning
%                        is issued and the channel is interpolated across the
%                        neighbouring columns instead, FILLMISSING(...,
%                        'makima',2). A negative scalar flags channels with
%                        abs(zscore(rms(LFP))) > abs(value), computed on
%                        Y.LFP after any LFP filtering; requires "LFP".
%     LFP_Fs             Hz  1000
%     LFP_bpLoHi         [low high] Hz  [0 Inf]  LFP band limits. low = 0 means
%                        no high-pass, high = Inf means no low-pass, so [0 Inf]
%                        (default) applies no filter, [1 Inf] is a high-pass,
%                        [0 300] a low-pass and [1 300] a bandpass. The filter
%                        is BUTTER(4, ...) ('high' | 'low' | 'bandpass'),
%                        applied with FILTFILT (zero phase) at LFP_Fs after
%                        resampling, so every finite edge must be < LFP_Fs/2.
%                        As with any FILTFILT IIR filter, the start and end
%                        of the recording carry edge transients: for a 1 Hz
%                        high-pass, up to ~2 s at each end, longer for lower
%                        cut-offs. The interior is unaffected.
%     LFP_NotchHz        Hz vector  []  notch (band-stop) center frequencies,
%                        e.g. 60 or [60 120 180]; [] = no notch. Each notch is
%                        BUTTER(2, [f-BW/2 f+BW/2], 'stop') applied with
%                        FILTFILT at LFP_Fs; needs f-BW/2 > 0 and
%                        f+BW/2 < LFP_Fs/2.
%     LFP_NotchBW        Hz  2  width of each notch: its edges f +/- BW/2 are
%                        the -3 dB points of the designed filter (FILTFILT
%                        applies it twice, so they are -6 dB in the output).
%     MUA_Fs             Hz  2000
%     MUA_IntegrationHz  Hz  1000
%     MUA_bpLoHi         [low high] Hz  [300 5000]  (high < original rate/2)
%     SPIKE_Fs           Hz  Inf (= original rate)
%     SPIKE_bpLoHi       [low high] Hz  [300 5000]  (high < SPIKE_Fs/2)
%     labelField         "custom" | "native": channel, aux and digital-line
%                        names (default "": TrialConfig.LabelField)
%     lineNames          string list  "native=name" digital-line names
%                        (e.g. "TTL4=InTrial"), overriding labelField
%                        (default []: TrialConfig.LineNames)
%     invertedLines      string list  digital lines with inverted TTL
%                        polarity (on while low): their EVENTS rows are the
%                        low runs, onset = falling edge, offset = last low
%                        sample (digitalLinePolarity); INFO.invertedLines
%                        lists the lines actually inverted (default []:
%                        TrialConfig.InvertedLines)
%     probeFile          probe .json whose geometry places the bad channels
%                        (default "": the dataset's ProbeFile); EphysPipeline
%                        passes the probe it sorts with (probeFor), the config's
%                        default for a dataset without a probe of its own
%     ProgressFcn        function handle, called as ProgressFcn(nDone, nTotal,
%                        message) before each step (one per file read, then one
%                        per processing stage) and once more as
%                        ProgressFcn(nTotal, nTotal, "Done"). It may throw to
%                        abort. Not stored in INFO.importOptions.
%
%   Resampling: RESAMPLE needs an integer ratio P/Q. It is taken from RAT,
%   exact for any rate with a short decimal expansion (24414.0625 Hz to
%   1000 Hz is 128/3125), with P and Q up to 2^18; a ratio that needs larger
%   factors is approximated (at worst 1e-4 relative), and the rate actually
%   produced, origFs*P/Q, is the one reported in INFO.<type>.Fs and
%   INFO.importOptions.
%
%   Memory: the amplifier data are read as single (see readData Precision)
%   and each signal is derived one channel at a time (8 at a time from 64
%   channels up, where FILTER runs on several threads) into a preallocated
%   single matrix; the spike band at the original rate overwrites the
%   amplifier data in place. Peak memory is about the single-precision
%   recording plus the derived signals plus the double-precision working
%   copies of one block of channels (at most about the recording again).
%
%   Requires the Signal Processing Toolbox (BUTTER, FILTFILT, RESAMPLE);
%   automatic bad-channel detection also needs ZSCORE (Statistics and
%   Machine Learning Toolbox).
%
%   See also INTAN2MATLAB, EphysDataset.toMat, EphysDataset.readData,
%   EphysDataset.channelLayout, EphysDataset.filterContinuous.

arguments
    obj (1,1) EphysDataset
    opts.channelRemap (1,:) double {mustBeInteger, mustBePositive} = []
    opts.badChannels double = []
    opts.keepAmpChannels double {mustBeInteger, mustBePositive} = []
    opts.dataTypeOut (1,:) string = "LFP"
    opts.LFP_Fs (1,1) double {mustBePositive, mustBeFinite} = 1000
    opts.LFP_bpLoHi (1,2) double {mustBeNonnegative} = [0 Inf]
    opts.LFP_NotchHz (1,:) double {mustBePositive, mustBeFinite} = []
    opts.LFP_NotchBW (1,1) double {mustBePositive, mustBeFinite} = 2
    opts.MUA_Fs (1,1) double {mustBePositive, mustBeFinite} = 2000
    opts.SPIKE_Fs (1,1) double {mustBePositive} = inf
    opts.MUA_IntegrationHz (1,1) double {mustBePositive} = 1000
    opts.MUA_bpLoHi (1,2) double {mustBePositive} = [300 5000]
    opts.SPIKE_bpLoHi (1,2) double {mustBePositive} = [300 5000]
    opts.labelField (1,1) string {mustBeMember(opts.labelField, ["" "custom" "native"])} = ""
    opts.lineNames {mustBeNameList} = []
    opts.invertedLines {mustBeNameList} = []
    opts.probeFile (1,1) string = ""
    opts.ProgressFcn = []
end

if ~isempty(opts.ProgressFcn) && ~isa(opts.ProgressFcn, 'function_handle')
    error('EphysDataset:deriveSignals:ProgressFcn', ...
        'ProgressFcn must be a function handle or [].');
end
progressFcn = opts.ProgressFcn;
opts = rmfield(opts, 'ProgressFcn');   % never stored in info.importOptions

% --- validate options (before reading anything) ---
badType = setdiff(opts.dataTypeOut, ["LFP" "MUA" "SPIKE" "AUX"]);
if ~isempty(badType)
    error('EphysDataset:deriveSignals:dataTypeOut', ...
        'Unknown dataTypeOut value(s): %s. Use "LFP", "MUA", "SPIKE" and/or "AUX".', ...
        strjoin(badType, ', '));
end
if opts.MUA_bpLoHi(1) >= opts.MUA_bpLoHi(2)
    error('EphysDataset:deriveSignals:MUA_bpLoHiOrder', ...
        'MUA_bpLoHi must be [low high] with low < high.');
end
if opts.SPIKE_bpLoHi(1) >= opts.SPIKE_bpLoHi(2)
    error('EphysDataset:deriveSignals:SPIKE_bpLoHiOrder', ...
        'SPIKE_bpLoHi must be [low high] with low < high.');
end
if ~isfinite(opts.LFP_bpLoHi(1)) || opts.LFP_bpLoHi(1) >= opts.LFP_bpLoHi(2)
    error('EphysDataset:deriveSignals:LFP_bpLoHiOrder', ...
        ['LFP_bpLoHi must be [low high] with a finite low < high ' ...
         '(low = 0: no high-pass, high = Inf: no low-pass).']);
end

has.LFP   = any(opts.dataTypeOut == "LFP");
has.MUA   = any(opts.dataTypeOut == "MUA");
has.SPIKE = any(opts.dataTypeOut == "SPIKE");
has.AUX   = any(opts.dataTypeOut == "AUX");

% LFP filters are designed at LFP_Fs, which is known before reading.
lfpFilter = has.LFP && (opts.LFP_bpLoHi(1) > 0 || isfinite(opts.LFP_bpLoHi(2)) ...
    || ~isempty(opts.LFP_NotchHz));
if has.LFP
    validateLFPFilter(opts, opts.LFP_Fs);
end

autoBad = isscalar(opts.badChannels) && opts.badChannels < 0;
if autoBad && ~has.LFP
    error('EphysDataset:deriveSignals:AutoBadChannelsNeedLFP', ...
        ['Automatic bad-channel detection (negative scalar badChannels) is ' ...
         'computed from the LFP; include "LFP" in dataTypeOut.']);
end
if ~autoBad && ~isempty(opts.badChannels)
    opts.badChannels = checkBadChannels(opts.badChannels, NaN);
end

% Digital-line naming and polarity: "" / [] take the dataset's TrialConfig
% (as readData and digitalEvents do); explicit values win.
[opts.labelField, opts.lineNames] = obj.lineNaming(opts.labelField, opts.lineNames);
if isnumeric(opts.invertedLines)
    opts.invertedLines = string.empty(1, 0);
    if isfield(obj.TrialConfig, 'InvertedLines')
        opts.invertedLines = obj.TrialConfig.InvertedLines;
    end
end
opts.invertedLines = reshape(string(opts.invertedLines), 1, []);

if obj.NumFiles == 0
    obj.discoverFiles();
end
if obj.NumFiles == 0
    error('EphysDataset:deriveSignals:NoFiles', 'No recording files in %s', obj.Folder);
end
if isnan(obj.Fs) || isempty(obj.PerFile)
    obj.refreshMetadata();
end
% Header metadata: fail fast, before the long read.
if isfinite(obj.Fs)
    signalRates(opts, has, obj.Fs);
end
nKept = numel(opts.keepAmpChannels);
if nKept == 0; nKept = obj.NumChannels; end
if ~autoBad && ~isempty(opts.badChannels) && isfinite(nKept)
    checkBadChannels(opts.badChannels, nKept);
end

% Progress steps: one per file read, then one per processing stage.
nRead  = obj.NumFiles;
nProc  = has.LFP + lfpFilter + has.MUA + has.SPIKE + ~isempty(opts.badChannels) ...
    + ~isempty(opts.channelRemap) + 1;   % +1 = digital events
nSteps = nRead + nProc;

readCb = [];
if ~isempty(progressFcn)
    readCb = @(i, n, name) progressFcn(i - 1, nSteps, ...
        sprintf('Reading file %d/%d: %s', i, n, name));
end

% --- read (any layout), single precision, lines named by labelField / lineNames ---
data = obj.readData(KeepChannels=opts.keepAmpChannels(:).', Precision="single", ...
    LabelField=opts.labelField, LineNames=opts.lineNames, IncludeAux=has.AUX, ProgressFcn=readCb);
nDone = nRead;

AMPSIG = data.amplifier;
data.amplifier = [];
if isempty(AMPSIG)
    error('EphysDataset:deriveSignals:NoData', 'No amplifier data read from %s', obj.Folder);
end
origFs = data.Fs;
[nSamp, nCol] = size(AMPSIG);
% The rates the signals are produced at (RESAMPLE's P/Q), checked against
% the rate actually read; the options report them from here on.
rates = signalRates(opts, has, origFs);
for s = string(fieldnames(rates)).'
    opts.(s + "_Fs") = rates.(s).Fs;
end
if ~autoBad && ~isempty(opts.badChannels)
    checkBadChannels(opts.badChannels, nCol);
end
keep = opts.keepAmpChannels(:).';
if isempty(keep); keep = 1:nCol; end   % the recording channel of each column

if opts.labelField == "native"
    labels = cellstr(data.nativeNames);
else
    labels = cellstr(data.channelNames);
end
[ev, invertedApplied] = digitalLinePolarity(data.events, opts.invertedLines, nSamp, origFs);
filenames = cellstr(data.files);
AUXSIG = single([]);
if has.AUX
    [AUXSIG, auxFs, auxLabels] = auxInputs(data, opts.labelField);
    if isempty(AUXSIG)
        warning('EphysDataset:deriveSignals:NoAux', ...
            '%s has no auxiliary (accelerometer) inputs; AUX is not written.', obj.Name);
        has.AUX = false;
    end
end
clear data

LFP   = single([]);
MUA   = single([]);
SPIKE = single([]);

% --- filter / resample a block of channels at a time (blockColumns) into
% single outputs, filtering in double; AMPSIG is freed after its last use
% (the spike band at the original rate takes over its memory) ---
k = blockColumns(nCol);
if has.LFP
    nDone = reportProgress(progressFcn, nDone, nSteps, ...
        sprintf('LFP: resampling to %g Hz', opts.LFP_Fs));
    LFP = resampleColumns(AMPSIG, rates.LFP, k);
    if lfpFilter
        nDone = reportProgress(progressFcn, nDone, nSteps, ...
            "LFP: " + describeLFPFilter(opts));
        LFP = filterLFP(LFP, opts);
    end
end
if has.MUA
    % Bandpass at origFs -> rectify -> resample to MUA_Fs -> moving-mean
    % integration on the MUA_Fs grid.
    nDone = reportProgress(progressFcn, nDone, nSteps, ...
        sprintf('MUA: bandpass [%g %g] Hz, rectify, resample to %g Hz, integrate', ...
        opts.MUA_bpLoHi, opts.MUA_Fs));
    MUA = muaColumns(obj, AMPSIG, opts, origFs, rates.MUA, k);
end
if has.SPIKE
    nDone = reportProgress(progressFcn, nDone, nSteps, ...
        sprintf('SPIKE: bandpass [%g %g] Hz', opts.SPIKE_bpLoHi));
    AMPSIG = spikeBand(obj, AMPSIG, opts, rates.SPIKE, k);
    SPIKE = AMPSIG;
end
clear AMPSIG

% --- interpolate bad channels, after processing, before remap ---
bad = struct('columns', zeros(1, 0), 'channels', zeros(1, 0), ...
    'method', strings(1, 0), 'weights', zeros(nCol, 0));
if ~isempty(opts.badChannels)
    layout = obj.channelLayout(ProbeFile=opts.probeFile);
    if layout.hasProbe
        how = 'probe geometry';
    else
        how = 'neighbouring columns: no probe layout';
    end
    nDone = reportProgress(progressFcn, nDone, nSteps, ...
        sprintf('Interpolating bad channels (%s)', how));
    if autoBad
        r = rms(LFP, 1);
        zr = abs(zscore(r));
        opts.badChannels = find(zr > abs(opts.badChannels));
        if ~isempty(opts.badChannels)
            checkBadChannels(opts.badChannels, nCol);
        end
    end
    if ~isempty(opts.badChannels) && (has.LFP || has.MUA || has.SPIKE)   % not for AUX alone
        [W, method] = badChannelWeights(layout, keep, opts.badChannels);
        if any(method == "columns")
            if layout.hasProbe
                why = 'they are off the probe or have no good site on their shank';
            else
                why = 'there is no probe layout (ProbeFile, or the probeFile option)';
            end
            warning('EphysDataset:deriveSignals:BadChannelGeometry', ...
                ['%s: bad column(s) %s are interpolated across the neighbouring ' ...
                 'columns (fillmissing makima), not from the probe geometry: %s.'], ...
                obj.Name, mat2str(opts.badChannels(method == "columns")), why);
        end
        LFP   = fillBadChannels(LFP, opts.badChannels, W, method);
        MUA   = fillBadChannels(MUA, opts.badChannels, W, method);
        SPIKE = fillBadChannels(SPIKE, opts.badChannels, W, method);
        bad = struct('columns', opts.badChannels, 'channels', keep(opts.badChannels), ...
            'method', method, 'weights', W);
    end
end

% --- final channel order ---
if ~isempty(opts.channelRemap)
    nDone = reportProgress(progressFcn, nDone, nSteps, 'Applying channel remap');
    LFP   = remapColumns(LFP, opts.channelRemap);
    MUA   = remapColumns(MUA, opts.channelRemap);
    SPIKE = remapColumns(SPIKE, opts.channelRemap);
    labels = labels(opts.channelRemap);   % keep labels matched to Y columns
end

% Digital events were extracted by readData (each HIGH run's first and last
% row / origFs, seconds on the original amplifier grid); this step only
% reports it.
nDone = reportProgress(progressFcn, nDone, nSteps, 'Extracting digital events');

Y = struct('LFP', LFP, 'MUA', MUA, 'SPIKE', SPIKE, 'AUX', AUXSIG);
clear LFP MUA SPIKE AUXSIG

% --- package info ---
info = struct();
info.recordingFolder = char(obj.Folder);
info.filenames       = filenames;
info.recordingFormat = obj.RecordingFormat;
info.labels          = labels(:);
info.origFs          = origFs;
info.invertedLines   = invertedApplied;   % digital lines whose events are low runs
info.badChannels     = bad;               % what was interpolated, and how
if has.LFP
    info.LFP.Fs       = opts.LFP_Fs;
    info.LFP.bpLoHi   = opts.LFP_bpLoHi;
    info.LFP.NotchHz  = opts.LFP_NotchHz;
    info.LFP.NotchBW  = opts.LFP_NotchBW;
    info.LFP.filter   = describeLFPFilter(opts);
    info.LFP.nSamples = size(Y.LFP, 1);
end
if has.SPIKE
    info.SPIKE.Fs       = opts.SPIKE_Fs;
    info.SPIKE.nSamples = size(Y.SPIKE, 1);
end
if has.MUA
    info.MUA.Fs            = opts.MUA_Fs;
    info.MUA.IntegrationHz = opts.MUA_IntegrationHz;
    info.MUA.bpLoHi        = opts.MUA_bpLoHi;
    info.MUA.nSamples      = size(Y.MUA, 1);
end
if has.AUX
    info.AUX.Fs       = auxFs;
    info.AUX.labels   = auxLabels(:);
    info.AUX.units    = "volts";
    info.AUX.nSamples = size(Y.AUX, 1);
end
info.importOptions = opts;

reportProgress(progressFcn, nDone, nSteps, 'Done');   % nDone == nSteps here
end


function mustBeNameList(v)
%mustBeNameList  [] (take the dataset's TrialConfig) or a list of names.
if ~((isnumeric(v) && isempty(v)) || isstring(v) || ischar(v) || iscellstr(v))
    error('EphysDataset:deriveSignals:NameList', ...
        'Must be [] (the dataset''s TrialConfig) or a string list.');
end
end


function bad = checkBadChannels(bad, nCol)
%checkBadChannels  Bad-channel columns as sorted unique positive integers.
%   With a known column count nCol (NaN: not known yet) they must also lie
%   in 1..nCol and leave at least one good column to interpolate from.
bad = unique(bad(:).');
if ~all(isfinite(bad) & bad >= 1 & bad == round(bad))
    error('EphysDataset:deriveSignals:BadChannels', ...
        ['badChannels must be positive integer column indices (after ' ...
         'keepAmpChannels, before channelRemap) or a negative scalar threshold.']);
end
if isfinite(nCol) && any(bad > nCol)
    error('EphysDataset:deriveSignals:BadChannels', ...
        ['badChannels %s: the data has %d columns (after keepAmpChannels); ' ...
         'badChannels are column indices, not recording channels.'], ...
        mat2str(bad(bad > nCol)), nCol);
end
if isfinite(nCol) && numel(bad) >= nCol
    error('EphysDataset:deriveSignals:BadChannels', ...
        'badChannels cover all %d columns: no good channel is left to interpolate from.', nCol);
end
end


function [X, Fs, labels] = auxInputs(data, labelField)
%auxInputs  The reader's aux inputs as [n x nAux] single volts, rate and labels.
X = single([]);
Fs = NaN;
labels = {};
if ~isfield(data, 'aux') || isempty(data.aux) || ~isnumeric(data.aux)
    return
end
X  = single(data.aux);
Fs = double(data.auxFs);
nAux = size(X, 2);
names = string.empty(1, 0);
if labelField == "native" && isfield(data, 'auxNativeNames')
    names = string(data.auxNativeNames);
elseif isfield(data, 'auxNames')
    names = string(data.auxNames);
end
if numel(names) ~= nAux
    names = "AUX" + string(1:nAux);
end
labels = cellstr(names);
end


function nDone = reportProgress(fcn, nDone, nTotal, msg)
%reportProgress  Invoke the optional ProgressFcn and advance the step count.
if ~isempty(fcn)
    fcn(nDone, nTotal, msg);
end
nDone = nDone + 1;
end


function validateLFPFilter(opts, lfpFs)
%validateLFPFilter  Check the LFP filter edges against lfpFs/2, the Nyquist
%   rate of the resampled LFP they are designed and applied at.
nyq = lfpFs / 2;
lo = opts.LFP_bpLoHi(1);
hi = opts.LFP_bpLoHi(2);
if lo >= nyq
    error('EphysDataset:deriveSignals:LFP_bpNyquist', ...
        'LFP_bpLoHi low edge (%g Hz) must be below LFP_Fs/2 (%g Hz).', lo, nyq);
end
if isfinite(hi) && hi >= nyq
    error('EphysDataset:deriveSignals:LFP_bpNyquist', ...
        ['LFP_bpLoHi high edge (%g Hz) must be below LFP_Fs/2 (%g Hz); ' ...
         'use Inf for no low-pass.'], hi, nyq);
end
bw = opts.LFP_NotchBW;
for f = opts.LFP_NotchHz
    if f - bw/2 <= 0 || f + bw/2 >= nyq
        error('EphysDataset:deriveSignals:LFP_Notch', ...
            ['LFP notch %g Hz with width %g Hz spans [%g %g] Hz, which must lie ' ...
             'inside (0, LFP_Fs/2 = %g Hz).'], f, bw, f - bw/2, f + bw/2, nyq);
    end
end
end


function s = describeLFPFilter(opts)
%describeLFPFilter  One-line text description of the LFP filters requested.
lo = opts.LFP_bpLoHi(1);
hi = opts.LFP_bpLoHi(2);
parts = strings(1, 0);
if lo > 0 && isfinite(hi)
    parts(end+1) = sprintf("bandpass [%g %g] Hz (butter order 4)", lo, hi);
elseif lo > 0
    parts(end+1) = sprintf("high-pass %g Hz (butter order 4)", lo);
elseif isfinite(hi)
    parts(end+1) = sprintf("low-pass %g Hz (butter order 4)", hi);
end
if ~isempty(opts.LFP_NotchHz)
    parts(end+1) = sprintf("notch %s Hz, width %g Hz (butter order 2 band-stop)", ...
        strjoin(compose("%g", opts.LFP_NotchHz), "/"), opts.LFP_NotchBW);
end
if isempty(parts)
    s = "none (resample anti-aliasing only)";
else
    s = "zero-phase (filtfilt) at " + sprintf("%g", opts.LFP_Fs) + " Hz: " ...
        + strjoin(parts, "; ");
end
end


function X = filterLFP(X, opts)
%filterLFP  Apply the requested LFP band-limit and notch filters at LFP_Fs.
%   Each filter is a Butterworth design converted to second-order sections
%   (numerically stable for cut-offs that are small relative to LFP_Fs) and
%   applied with FILTFILT. Channels are filtered one at a time in double
%   precision and stored back in X's class, bounding the extra memory to one
%   double-precision channel.
nyq = opts.LFP_Fs / 2;
lo = opts.LFP_bpLoHi(1);
hi = opts.LFP_bpLoHi(2);
filt = struct('sos', {}, 'g', {});
if lo > 0 && isfinite(hi)
    filt(end+1) = butterSOS(4, [lo hi] / nyq, 'bandpass');
elseif lo > 0
    filt(end+1) = butterSOS(4, lo / nyq, 'high');
elseif isfinite(hi)
    filt(end+1) = butterSOS(4, hi / nyq, 'low');
end
bw = opts.LFP_NotchBW;
for f = opts.LFP_NotchHz
    filt(end+1) = butterSOS(2, [f - bw/2, f + bw/2] / nyq, 'stop'); %#ok<AGROW>
end
for c = 1:size(X, 2)
    x = double(X(:, c));
    for s = 1:numel(filt)
        x = filtfilt(filt(s).sos, filt(s).g, x);
    end
    X(:, c) = x;
end
end


function f = butterSOS(n, Wn, type)
%butterSOS  BUTTER design as second-order sections + gain (for FILTFILT).
[z, p, k] = butter(n, Wn, type);
[f.sos, f.g] = zp2sos(z, p, k);
end


function k = blockColumns(nCol)
%blockColumns  How many columns are resampled / filtered together. FILTER
%   runs on several threads from about 8 columns, which makes the MUA and
%   spike-band filtering several times faster; from 64 channels up the
%   double-precision working copies of 8 columns stay within about the size
%   of the single-precision recording, so smaller recordings go one column
%   at a time.
k = 1;
if nCol >= 64
    k = 8;
end
end


function Y = resampleColumns(X, rate, k)
%resampleColumns  RESAMPLE X to rate.Fs, K columns at a time, in X's class,
%   into a preallocated matrix (the same result as RESAMPLE on the whole
%   matrix).
nCol = size(X, 2);
cc = 1:min(k, nCol);
[y, h] = resampleBlock(X(:, cc), rate, []);
Y = zeros(size(y, 1), nCol, 'like', y);
Y(:, cc) = y;
for c0 = k+1:k:nCol
    cc = c0:min(nCol, c0 + k - 1);
    Y(:, cc) = resampleBlock(X(:, cc), rate, h);
end
end


function M = muaColumns(obj, X, opts, origFs, rate, k)
%muaColumns  MUA envelope of X (bandpass MUA_bpLoHi at origFs, ABS, resample
%   to MUA_Fs, moving mean), in double, K columns at a time, into single.
win = max(1, round(opts.MUA_Fs / opts.MUA_IntegrationHz));
nCol = size(X, 2);
M = single([]);
h = [];
for c0 = 1:k:nCol
    cc = c0:min(nCol, c0 + k - 1);
    m = abs(obj.filterContinuous(double(X(:, cc)), 'Type', "bandpass", ...
        'Cutoff', opts.MUA_bpLoHi, 'Order', 4, 'Fs', origFs));
    [m, h] = resampleBlock(m, rate, h);
    if c0 == 1
        M = zeros(size(m, 1), nCol, 'single');
    end
    M(:, cc) = single(movmean(m, win));   % integrate along time
end
end


function X = spikeBand(obj, X, opts, rate, k)
%spikeBand  Spike band of X: resample to SPIKE_Fs, then bandpass
%   SPIKE_bpLoHi, in double, K columns at a time. At the original rate each
%   result overwrites its columns of X, so no second full-size matrix is
%   made (call as X = spikeBand(obj, X, ...) to keep that in place).
nCol = size(X, 2);
band = @(x) obj.filterContinuous(x, 'Type', "bandpass", 'Cutoff', opts.SPIKE_bpLoHi, ...
    'Order', 4, 'Fs', rate.Fs);   % in double; returns the class of x
if rate.p == rate.q
    for c0 = 1:k:nCol
        cc = c0:min(nCol, c0 + k - 1);
        X(:, cc) = band(X(:, cc));
    end
    return
end
S = single([]);
h = [];
for c0 = 1:k:nCol
    cc = c0:min(nCol, c0 + k - 1);
    [x, h] = resampleBlock(double(X(:, cc)), rate, h);
    if c0 == 1
        S = zeros(size(x, 1), nCol, 'single');
    end
    S(:, cc) = single(band(x));
end
X = S;
end


function [y, h] = resampleBlock(x, rate, h)
%resampleBlock  RESAMPLE the columns of X by rate.p/rate.q. The
%   anti-aliasing filter H is designed on the first call and passed back in
%   afterwards, which gives the same result as a fresh design.
if rate.p == rate.q
    y = x;
elseif isempty(h)
    [y, h] = resample(x, rate.p, rate.q);
else
    y = resample(x, rate.p, rate.q, h);
end
end


function rates = signalRates(opts, has, origFs)
%signalRates  The rate (Fs) and RESAMPLE factors (p, q) of each requested
%   amplifier signal, checking every band edge against the Nyquist rate of
%   the data it is applied to.
rates = struct();
if has.LFP
    rates.LFP = outputRate(opts.LFP_Fs, origFs);
    validateLFPFilter(opts, rates.LFP.Fs);
end
if has.MUA
    if opts.MUA_bpLoHi(2) >= origFs/2
        error('EphysDataset:deriveSignals:MUA_bpNyquist', ...
            'MUA_bpLoHi high edge (%g Hz) must be below origFs/2 (%g Hz).', ...
            opts.MUA_bpLoHi(2), origFs/2);
    end
    rates.MUA = outputRate(opts.MUA_Fs, origFs);
end
if has.SPIKE
    rates.SPIKE = outputRate(opts.SPIKE_Fs, origFs);
    if opts.SPIKE_bpLoHi(2) >= rates.SPIKE.Fs/2
        error('EphysDataset:deriveSignals:SPIKE_bpNyquist', ...
            'SPIKE_bpLoHi high edge (%g Hz) must be below SPIKE_Fs/2 (%g Hz).', ...
            opts.SPIKE_bpLoHi(2), rates.SPIKE.Fs/2);
    end
end
end


function r = outputRate(target, origFs)
%outputRate  The rate RESAMPLE produces for TARGET Hz from origFs, with its
%   factors: Inf (and origFs itself) keep the original rate.
if isinf(target) || target == origFs
    r = struct('Fs', origFs, 'p', 1, 'q', 1);
    return
end
[p, q] = resampleRatio(target, origFs);
r = struct('Fs', origFs * p / q, 'p', p, 'q', q);
end


function [p, q] = resampleRatio(fsOut, fsIn)
%resampleRatio  Integers P/Q ~ fsOut/fsIn for RESAMPLE, exact when possible.
%   RAT within 1e-12 (relative) is exact for any rate with a short decimal
%   expansion (24414.0625 -> 1000 Hz is 128/3125, 30000.5 -> 1000 Hz is
%   2000/60001). P and Q are capped at 2^18, which bounds RESAMPLE's
%   anti-aliasing filter (20*max(P,Q)+1 taps), and P*Q at UPFIRDN's int32
%   limit; a ratio that needs larger factors is approximated, the tolerance
%   loosened tenfold at a time up to 1e-4 (30000.132 -> 2000 Hz becomes
%   1/15, i.e. 2000.0088 Hz).
r = fsOut / fsIn;
for tol = 10 .^ (-12:-4)
    [p, q] = rat(r, tol * r);
    if p >= 1 && max(p, q) <= 2^18 && p * q <= double(intmax('int32'))
        return
    end
end
error('EphysDataset:deriveSignals:ResampleRatio', ...
    'Cannot resample from %.10g Hz to %g Hz: the ratio needs factors above 2^18.', fsIn, fsOut);
end


function [W, method] = badChannelWeights(layout, keep, bad)
%badChannelWeights  Interpolation weights of the bad columns from the probe.
%   Column c is recording channel keep(c), placed by the probe layout
%   (EphysDataset.channelLayout). Column j of W holds bad column bad(j)'s
%   weights over the kept columns: the NearestSites good columns on its
%   shank nearest to it (and any as near as the last of those), each
%   1/distance, normalized to sum to 1. METHOD(j) is "geometry" for those,
%   and "columns" (weights all zero) for a bad column off the probe or with
%   no good site on its shank.
NearestSites = 4;
nCol = numel(keep);
x = NaN(1, nCol);
y = NaN(1, nCol);
shank = NaN(1, nCol);
on = keep <= numel(layout.x);
x(on) = layout.x(keep(on));
y(on) = layout.y(keep(on));
shank(on) = layout.shank(keep(on));
good = isfinite(x) & isfinite(y) & isfinite(shank);
good(bad) = false;
W = zeros(nCol, numel(bad));
method = repmat("columns", 1, numel(bad));
for j = 1:numel(bad)
    b = bad(j);
    cand = find(good & shank == shank(b));
    if isempty(cand) || ~isfinite(x(b)) || ~isfinite(y(b))
        continue
    end
    [d, o] = sort(hypot(x(cand) - x(b), y(cand) - y(b)));
    n = nnz(d <= d(min(NearestSites, numel(d))) * (1 + 1e-9));   % ties with the last count too
    d = d(1:n);
    cand = cand(o(1:n));
    if d(1) == 0
        w = double(d == 0);   % the same site recorded in another column
    else
        w = 1 ./ d;
    end
    W(cand, j) = w / sum(w);
    method(j) = "geometry";
end
end


function X = fillBadChannels(X, bad, W, method)
%fillBadChannels  Replace the bad columns of X: from the probe geometry
%   (X(:, good) * weights) or, for the "columns" method, by FILLMISSING
%   makima across the columns with every bad column missing. FILLMISSING
%   works row by row, so it runs on blocks of rows (the same result as on the
%   whole matrix, with a bounded copy).
if isempty(X)
    return
end
col = method == "columns";
if any(col)
    nRow = max(1, floor(2^22 / size(X, 2)));
    for r0 = 1:nRow:size(X, 1)
        r = r0:min(size(X, 1), r0 + nRow - 1);
        B = X(r, :);
        B(:, bad) = NaN;
        B = fillmissing(B, 'makima', 2);
        X(r, bad(col)) = B(:, bad(col));
    end
end
for j = find(~col)
    src = find(W(:, j)).';
    X(:, bad(j)) = X(:, src) * W(src, j);
end
end


function X = remapColumns(X, remap)
%remapColumns  X(:, remap). A permutation of all the columns is applied in
%   place, one cycle at a time through a one-column buffer, so the spike
%   band is not copied; anything else is plain indexing.
if isempty(X)
    return
end
n = size(X, 2);
if numel(remap) ~= n || ~isequal(sort(remap), 1:n)
    X = X(:, remap);
    return
end
done = remap == 1:n;
for s = find(~done)
    if done(s); continue; end
    buf = X(:, s);            % X(:, k) takes X(:, remap(k)) around the cycle
    k = s;
    while remap(k) ~= s
        X(:, k) = X(:, remap(k));
        done(k) = true;
        k = remap(k);
    end
    X(:, k) = buf;
    done(k) = true;
end
end
