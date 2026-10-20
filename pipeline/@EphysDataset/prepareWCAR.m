function st = prepareWCAR(obj, opts)
%prepareWCAR  The streamed weighted CAR's state checkpoints, worked out once per recording.
%   ST = ds.prepareWCAR() readies the adaptive weighted CAR (weightedCAR,
%   Khorasani et al. 2019) for the streamed reads when
%   ArtifactConfig.Reference is "wcar", and returns its state; ST is [] for
%   any other reference. readChunkUV and readWindowUV call it, so every
%   streaming consumer - artifact detection, the noise levels of the fill,
%   the sorting .bin, spike detection and the app's views - reads the
%   weighted-CAR referenced signal. The streaming entry points (toBin,
%   artifactIntervals, analyzeArtifacts, noiseLevels, detectSpikes) call
%   it before any chunk is read, so a process-pool worker gets the state
%   with the dataset and never works it out again.
%
%   The weighted CAR is a Kalman filter that runs through the recording,
%   so a chunk read on its own needs the filter's state where the chunk
%   starts. prepareWCAR runs it once over the whole recording, in order,
%   and keeps that state every ST.grid samples (about 1 s): the covariance
%   P, every channel's predicted weights W and the high-passed common
%   average of the Order-1 samples before (NLag). A read then runs the
%   filter from the checkpoint at or before its first sample (wcarRows),
%   so it gives what one run over the whole recording gives, whatever the
%   chunks, the order they are read in or the workers that read them:
%     - the recursion is the same, sample for sample;
%     - the high-pass of the estimation inputs (HighpassHz, zero-phase) is
%       taken over the read padded by ST.pad samples on both sides, the
%       samples after which the filter's memory has fallen to 1e-12
%       (ln(1e-12) / ln of its largest pole radius: 23 s at 0.5 Hz,
%       whatever Fs), so it agrees with the whole-recording filter to
%       about 1e-12 of the signal's size, far below one ADC step. With
%       HighpassHz 0 there is no padding and the agreement is exact.
%   Every read costs its padding (a chunk is read with 2*pad more samples),
%   and the filter run from its checkpoint (up to one grid step).
%
%   The cost, once per recording: with ReferenceWCAR.Q NaN (automatic) a
%   first pass works out Q as deriveSignals does - the median over the
%   reference channels of (1.4826 * MAD)^2 of the plain-CAR residual,
%   high-passed at HighpassHz, over at most 2^22 evenly spaced samples
%   (those deriveSignals takes) - then a second pass runs the filter over
%   every channel (about 8 s per channel-hour at 30 kHz). The state is kept
%   in ds.WCARState and saved as <outputFolder>/<Name>_wcar.mat, reused
%   while its fingerprint matches: the reader, the recording files (names,
%   modified times), sample count, rate and channel count, the channels the
%   plain CAR is taken over (referenceChannels, settled first with
%   prepareReference), and the ReferenceWCAR options that decide the
%   state (all but Estimate, which only picks the weights subtracted).
%
%   Options
%     Refresh       false (default); true works the state out again
%     Cache         true (default): read and write <Name>_wcar.mat
%     ProgressFcn   ProgressFcn(done, total, message) before each window of
%                   each pass; it may throw to abort
%     WindowSamples samples of a pass's window (default NaN: about 250 MB
%                   of double); rounded down to the checkpoint grid and at
%                   least twice the padding. A pass reads every sample once
%                   whatever it is (the padding before a window is the end
%                   of the last), and the state does not depend on it.
%
%   ST fields: schema, key, fingerprint, Fs, nSamples, nChannels, channels
%   (the reference channels), grid, pad, window (the samples of a pass's
%   window), options (Order, Alpha1k, DriftPerSec, HighpassHz, Estimate),
%   Q, QAuto, P [Order x Order x k], W [Order x nChannels x k], NLag
%   [Order-1 x k] (checkpoint j holds the state of 0-based sample
%   (j-1)*grid), seconds and created.
%
%   Needs a reader with random access (supportsRandomAccess), the Signal
%   Processing Toolbox (BUTTER, FILTFILT) and the Statistics and Machine
%   Learning Toolbox (MAD, PRCTILE).
%
%   See also weightedCAR, EphysDataset.readChunkUV, EphysDataset.deriveSignals,
%   EphysDataset.prepareReference.

arguments
    obj (1,1) EphysDataset
    opts.Refresh (1,1) logical = false
    opts.Cache (1,1) logical = true
    opts.ProgressFcn = []
    opts.WindowSamples (1,1) double = NaN
end

st = [];
acfg = EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig);
if string(acfg.Reference) ~= "wcar"
    return
end
obj.requireReader('prepareWCAR');
if isnan(obj.Fs) || isempty(obj.PerFile)
    obj.refreshMetadata();
end
if ~obj.supportsRandomAccess()
    error('EphysDataset:prepareWCAR:NoRandomAccess', ...
        ['The weighted CAR of %s cannot be streamed: its reader cannot read a window of the ' ...
         'recording, which every read from a checkpoint needs. Use Reference "car" or "cmr".'], obj.Name);
end
Fs = obj.Fs;
N = obj.NumSamples;
nCh = obj.NumChannels;
if ~(isfinite(Fs) && Fs > 0 && isfinite(N) && N > 0 && isfinite(nCh) && nCh > 0)
    error('EphysDataset:prepareWCAR:NoMetadata', ...
        'The rate, sample count or channel count of %s is unknown.', obj.Name);
end
p = acfg.ReferenceWCAR;
p.Estimate = string(p.Estimate);
args = {'Order', p.Order, 'Alpha1k', p.Alpha1k, 'DriftPerSec', p.DriftPerSec, ...
    'HighpassHz', p.HighpassHz, 'Estimate', p.Estimate};
QGiven = double(p.Q);
if ~(isscalar(QGiven) && (isnan(QGiven) || QGiven > 0))
    error('EphysDataset:prepareWCAR:Q', 'ReferenceWCAR.Q must be NaN (automatic) or a positive number (uV^2).');
end
[~, def] = weightedCAR(zeros(0, 1), zeros(0, 1), args{:}, 'Fs', Fs, 'Q', 1);   % checks the options
M = def.Order;

% The state at hand (every read asks): its channels were settled before it
% was worked out, so they are not settled again.
held = @() ~opts.Refresh && isstruct(obj.WCARState) && isfield(obj.WCARState, 'key') ...
    && obj.WCARState.key == stateKey(obj, Fs, N, nCh, def, QGiven);
if obj.ReferenceExcludeSource ~= "" && held()
    st = withEstimate(obj.WCARState, p.Estimate);
    return
end
obj.prepareReference(Mode="car");   % the channels the plain CAR is taken over
if held()
    st = withEstimate(obj.WCARState, p.Estimate);
    return
end
ch = obj.referenceChannels();
key = stateKey(obj, Fs, N, nCh, def, QGiven);
modified = zeros(1, numel(obj.Files));   % a file written again (a replaced recording) is worked out again
for k = 1:numel(obj.Files)
    f = dir(fullfile(obj.Folder, obj.Files(k)));
    if isscalar(f); modified(k) = round(f.datenum * 86400); end
end
fp = string(jsonencode(struct('key', key, 'modified', modified)));
cacheFile = fullfile(obj.outputFolder(), obj.Name + "_wcar.mat");
if opts.Cache && ~opts.Refresh && isfile(cacheFile)
    try
        C = load(cacheFile, 'wcarState');
        if isfield(C, 'wcarState') && isfield(C.wcarState, 'fingerprint') && string(C.wcarState.fingerprint) == fp
            obj.WCARState = C.wcarState;
            st = withEstimate(obj.WCARState, p.Estimate);
            fprintf('Weighted CAR of %s: state from %s.\n', obj.Name, cacheFile);
            return
        end
    catch
    end
end

% Checkpoints every grid samples (about 1 s; more apart when the state of
% many channels at a high Order would pass 8 MB), windows of about 250 MB of
% double and at least the padding on both sides, on the grid.
pad = padRows(def.HighpassHz, Fs);
perCheck = 8 * (M * M + M * nCh + max(M - 1, 0));
grid = round(Fs) * max(1, ceil(perCheck * ceil(N / round(Fs)) / 2^23));
budget = opts.WindowSamples;
if ~(isfinite(budget) && budget > 0)
    budget = floor(2.5e8 / (8 * nCh));
end
win = grid * max([1, floor(budget / grid), ceil(2 * pad / grid)]);
starts = 0:win:max(N - 1, 0);
nWin = numel(starts);
QAuto = isnan(QGiven);
total = nWin * (1 + QAuto);
t0 = tic;
fprintf(['Weighted CAR of %s: working out its state (%d channel(s), %.4g s, %d window(s)%s; ' ...
    'high-pass padding %.4g s).\n'], obj.Name, nCh, N / Fs, nWin, ...
    ternary(QAuto, ", automatic Q first", ""), pad / Fs);

% --- pass 1: the automatic Q, from the rows deriveSignals takes ---
Q = QGiven;
done = 0;
if QAuto
    step = max(1, ceil(N / 2^22));
    picks = 1:step:N;                           % 1-based rows
    vals = zeros(numel(picks), numel(ch));
    buf = rawBuffer();
    for i = 1:nWin
        a = starts(i);
        b = min(N, a + win);
        report(sprintf('Weighted CAR: automatic Q, window %d/%d', i, nWin));
        [R, r0, buf] = bufferRows(buf, obj, max(0, a - pad), min(N, b + pad), nCh);
        x = R(:, ch) - mean(R(:, ch), 2);       % the plain-CAR residual
        if def.HighpassHz > 0
            x = obj.filterContinuous(x, Type="highpass", Cutoff=def.HighpassHz, Fs=Fs);
        end
        in = find(picks > a & picks <= b);
        vals(in, :) = x(picks(in) - r0, :);
    end
    buf = []; %#ok<NASGU> frees the window
    v = zeros(1, numel(ch));
    for j = 1:numel(ch)
        v(j) = (1.4826 * mad(vals(:, j), 1))^2;
    end
    vals = []; %#ok<NASGU> frees the samples
    Q = median(v);
    if ~(Q > 0)
        error('EphysDataset:prepareWCAR:Q', ...
            ['The automatic weighted-CAR Q of %s is 0 (the reference channels match their ' ...
             'average); set ReferenceWCAR.Q.'], obj.Name);
    end
end

% --- pass 2: the filter over every channel, keeping its state on the grid ---
nCk = ceil(N / grid);
P = zeros(M, M, nCk);
W = zeros(M, nCh, nCk);
L = zeros(max(M - 1, 0), nCk);
init = struct();                                 % W0 / P0 at the recording's start
buf = rawBuffer();
for i = 1:nWin
    a = starts(i);
    b = min(N, a + win);
    report(sprintf('Weighted CAR: state, window %d/%d', i, nWin));
    [R, r0, buf] = bufferRows(buf, obj, max(0, a - pad), min(N, b + pad), nCh);
    ck = a:grid:b-1;                             % 0-based rows on the grid (win is a multiple of it)
    [~, out] = weightedCAR(R, mean(R(:, ch), 2), args{:}, 'Fs', Fs, 'Q', Q, ...
        'Rows', [a - r0 + 1, b - r0], 'Initial', init, 'StateRows', ck - r0 + 1, 'Output', false);
    j = ck / grid + 1;
    P(:, :, j) = out.states.P;
    W(:, :, j) = out.states.W;
    L(:, j) = out.states.NLag;
    init = out.final;
end
buf = []; %#ok<NASGU> frees the window

st = struct('schema', "wcar-state/1", 'key', key, 'fingerprint', fp, 'Fs', Fs, ...
    'nSamples', N, 'nChannels', nCh, 'channels', ch, 'grid', grid, 'pad', pad, 'window', win, ...
    'options', rmfield(p, 'Q'), 'Q', Q, 'QAuto', QAuto, 'P', P, 'W', W, 'NLag', L, ...
    'seconds', toc(t0), 'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
obj.WCARState = st;
fprintf('Weighted CAR of %s: state worked out in %.1f s (Q %.4g uV^2%s).\n', obj.Name, st.seconds, ...
    Q, ternary(QAuto, ", automatic", ""));
if opts.Cache
    wcarState = st; %#ok<NASGU> saved by name
    try
        outDir = fileparts(cacheFile);
        if ~isfolder(outDir); mkdir(outDir); end
        save(cacheFile, 'wcarState');
    catch ME
        warning('EphysDataset:prepareWCAR:Cache', ...
            'Could not save the weighted CAR state of %s: %s', obj.Name, ME.message);
    end
end
st = withEstimate(st, p.Estimate);

    function report(msg)
        if ~isempty(opts.ProgressFcn)
            opts.ProgressFcn(done, total, string(msg));
        end
        done = done + 1;
    end
end


function key = stateKey(obj, Fs, N, nCh, def, QGiven)
%stateKey  What the state depends on, as JSON text: the reader, the files,
%   the sample count, rate and channel count, the reference channels and
%   the options (DEF: weightedCAR's resolved ones) but Estimate, which only
%   picks what is subtracted.
key = string(jsonencode(struct('schema', "wcar-state/1", 'reader', string(obj.Reader.Kind), ...
    'files', {cellstr(obj.Files(:).')}, 'nSamples', N, 'fs', Fs, 'nChannels', nCh, ...
    'channels', obj.referenceChannels(), 'Order', def.Order, 'Alpha1k', def.Alpha1k, ...
    'DriftPerSec', def.DriftPerSec, 'HighpassHz', def.HighpassHz, 'Q', QGiven, ...
    'W0', def.W0, 'P0', def.P0)));
end


function st = withEstimate(st, est)
%withEstimate  The state with the Estimate the dataset asks for now (it
%   does not change the state, only what a read subtracts).
st.options.Estimate = string(est);
end


function n = padRows(hpHz, Fs)
%padRows  Samples after which the zero-phase high-pass has forgotten an edge:
%   its slowest mode falls by its largest pole radius per sample, to 1e-12
%   after N. 0 without a high-pass.
n = 0;
if hpHz > 0
    [~, p, ~] = butter(4, hpHz / (Fs / 2), 'high');   % three outputs: zeros, poles, gain
    n = max(0, ceil(log(1e-12) / log(max(abs(p)))));
end
end


function b = rawBuffer()
%rawBuffer  The rows of the last window (bufferRows), so a pass reads each
%   row once: the next window's padding before it is the end of this one.
b = struct('start', 0, 'X', []);
end


function [X, r0, b] = bufferRows(b, obj, r0, r1, nCh)
%bufferRows  Rows [r0, r1) (0-based) as recorded, all channels, reusing
%   those of buffer B the last call read; B is returned holding these.
keep = [];
if ~isempty(b.X)
    k0 = r0 - b.start;                           % first reused row of b.X (0-based)
    k1 = min(size(b.X, 1), r1 - b.start);
    if k0 >= 0 && k1 > k0
        keep = b.X(k0 + 1 : k1, :);
    end
end
from = r0 + size(keep, 1);
X = zeros(0, nCh);
if r1 > from
    X = obj.Reader.readWindowUV(from, r1 - from);
end
if size(X, 1) ~= r1 - from || size(X, 2) ~= nCh
    error('EphysDataset:prepareWCAR:ShortRead', ...
        '%s returned %d x %d for rows %d-%d (expected %d x %d).', obj.Name, ...
        size(X, 1), size(X, 2), from + 1, r1, r1 - from, nCh);
end
if ~isempty(keep)
    X = [keep; X];
end
b.start = r0;
b.X = X;
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end
