function [data, params, T, info] = trials(obj, onsets, twin, opts)
%trials  Event-aligned epochs as a Chronux [time x trials] matrix.
%   [DATA, PARAMS, T] = cx.trials(ONSETS, TWIN) cuts the loaded continuous
%   signal into one epoch per onset and returns them as a [nTime x nTrials]
%   matrix (one channel) or [nTime x nTrials x nChan] (several channels), the
%   matching Chronux params, and T, the epoch time base in seconds relative to
%   the onset. Chronux's continuous routines treat the second dimension as
%   trials, so with params.trialave = 1 (TrialAve=1) mtspectrumc averages over
%   trials; with several channels pass DATA(:,:,c) one channel at a time.
%
%     ONSETS  event times in seconds, recording-relative (see eventOnsets)
%     TWIN    [tPre tPost] seconds relative to the onset, tPre usually
%             negative (default [-0.2 0.5]), the same convention as
%             EXTRACT_TRIALS. Chronux's own createdatamatc takes the window as
%             [-tPre tPost] instead, both positive.
%
%   Sample alignment (exactly which samples a trial contains)
%   ---------------------------------------------------------
%   With sample offsets s0 = round(tPre*Fs) and s1 = round(tPost*Fs), trial i
%   is rows base(i)+s0 ... base(i)+s1 of the signal, so nTime = s1-s0+1 and
%   T = (s0:s1)/Fs. The onset row base(i) follows OnsetRule:
%     "event"  (default) base = round(t*Fs). Digital-input event times are
%              reported as t = row/Fs (readData, deriveSignals, eventOnsets),
%              so this maps an onset back to exactly the sample that produced
%              it. It is the same indexing EXTRACT_TRIALS uses.
%     "sample" base = round(t*Fs)+1, the sample whose own time (k-1)/Fs is
%              nearest the onset. Use it for times taken from a continuous
%              time base (readData's t, info.LFP.time, spike times).
%   The two differ by one sample; at a derived rate (LFP_Fs) the digital-input
%   convention and the resampled grid cannot agree better than that anyway, so
%   treat the onset as accurate to +/-1 sample of the signal's own rate.
%   Chronux's createdatamatc uses floor(t*Fs)+1 and a right-exclusive window,
%   so it returns one sample fewer, starting one sample later, than "sample".
%
%   Options
%   -------
%     Channels    [] (all, default), column indices, or channel labels
%     OnsetRule   "event" (default) | "sample", above
%     Incomplete  what to do when a window runs past the start or end of the
%                 recording: "drop" (default, with a warning), "nan" (keep the
%                 trial, pad the missing samples with NaN - Chronux will then
%                 return NaN), or "error"
%     NonFinite   what to do with a trial whose in-range samples contain NaN or
%                 Inf (e.g. blanked artifacts): "drop" (default, with a
%                 warning), "keep" or "error". Samples padded by
%                 Incomplete="nan" are not counted here
%     Detrend     "none" (default) | "constant" | "linear", applied per trial
%                 and channel (each column of each channel separately)
%     Class       "double" (default) | "single" | "asis"
%     Tapers, Pad, Fpass, Err, TrialAve   per-call params overrides
%
%   INFO reports the selection: channels, labels, twin, sampleOffsets [s0 s1],
%   onsetRule, nTime, nTrials, nChan, keptTrials (indices into ONSETS),
%   onsets/onsetSamples of the kept trials, droppedIncomplete,
%   droppedNonFinite, detrend, class, fs, signal, units.
%
%   Example
%   -------
%     onsets = cx.eventOnsets("din0");
%     cx.Tapers = ChronuxDataset.tapersFor(4, 0.7);     % +/-4 Hz over 0.7 s
%     [D, params, T, info] = cx.trials(onsets, [-0.2 0.5], Channels=5, TrialAve=1);
%     [S, f] = mtspectrumc(D, params);                  % Chronux, trial-averaged
%
%   See also ChronuxDataset.eventOnsets, ChronuxDataset.spikeTrials,
%   EXTRACT_TRIALS.

arguments
    obj (1,1) ChronuxDataset
    onsets double {mustBeFinite}
    twin (1,2) double {mustBeFinite} = [-0.2 0.5]
    opts.Channels = []
    opts.OnsetRule (1,1) string {mustBeMember(opts.OnsetRule, ...
        ["event","sample"])} = "event"
    opts.Incomplete (1,1) string {mustBeMember(opts.Incomplete, ...
        ["drop","nan","error"])} = "drop"
    opts.NonFinite (1,1) string {mustBeMember(opts.NonFinite, ...
        ["drop","keep","error"])} = "drop"
    opts.Detrend (1,1) string {mustBeMember(opts.Detrend, ...
        ["none","constant","linear"])} = "none"
    opts.Class (1,1) string {mustBeMember(opts.Class, ...
        ["double","single","asis"])} = "double"
    opts.Tapers (1,:) double = double.empty(1,0)
    opts.Pad double = []
    opts.Fpass (1,:) double = double.empty(1,0)
    opts.Err (1,:) double = double.empty(1,0)
    opts.TrialAve double = []
end

obj.loadSignal();
onsets = onsets(:);
if isempty(onsets)
    error('ChronuxDataset:NoOnsets', 'ONSETS is empty; nothing to epoch.');
end
[ch, labels] = obj.resolveChannels(opts.Channels);

Fs = obj.Fs;
nSamp = size(obj.Data, 1);

s0 = round(twin(1) * Fs);
s1 = round(twin(2) * Fs);
if s1 < s0
    error('ChronuxDataset:BadWindow', ...
        'TWIN must be [tPre tPost] with tPre <= tPost; got [%g %g].', twin(1), twin(2));
end
offs = (s0:s1).';                 % [nTime x 1] sample offsets from the onset
T    = (s0:s1) / Fs;              % [1 x nTime] seconds relative to the onset
nTime = numel(offs);

switch opts.OnsetRule
    case "event",  base = round(onsets * Fs);
    case "sample", base = round(onsets * Fs) + 1;
end

I  = base.' + offs;               % [nTime x nTrials] rows into the signal
inR = I >= 1 & I <= nSamp;
complete = all(inR, 1);           % trials fully inside the recording

droppedIncomplete = find(~complete(:)).';
keep = true(1, numel(onsets));
switch opts.Incomplete
    case "drop"
        keep = complete;
        if any(~complete)
            warning('ChronuxDataset:IncompleteTrials', ...
                ['%d of %d trials extend past the recording and were dropped ' ...
                 '(Incomplete="nan" keeps them, padded with NaN).'], ...
                nnz(~complete), numel(complete));
        end
    case "error"
        if any(~complete)
            error('ChronuxDataset:IncompleteTrials', ...
                'Trials %s extend past the recording (%g s).', ...
                mat2str(droppedIncomplete), nSamp / Fs);
        end
    case "nan"
        % keep everything; missing samples are padded below
end
if ~any(keep)
    error('ChronuxDataset:NoTrials', ...
        'No trial window fits inside the %g s recording.', nSamp / Fs);
end

I   = I(:, keep);
inR = inR(:, keep);
kept = find(keep);
nTrials = numel(kept);
nChan = numel(ch);

% --- extract (clamped indexing + explicit NaN padding; values are copied,
%     never interpolated) ------------------------------------------------
Iclamp = min(max(I, 1), nSamp);
data = zeros(nTime, nTrials, nChan, 'like', obj.Data);
nonFiniteTrial = false(1, nTrials);
for c = 1:nChan
    xc = obj.Data(:, ch(c));
    V  = xc(Iclamp);                      % [nTime x nTrials]
    nonFiniteTrial = nonFiniteTrial | any(~isfinite(V) & inR, 1);
    V(~inR) = NaN;                        % samples outside the recording
    data(:, :, c) = V;
end

% --- non-finite policy (in-range samples only) --------------------------
droppedNonFinite = kept(nonFiniteTrial);
switch opts.NonFinite
    case "drop"
        if any(nonFiniteTrial)
            warning('ChronuxDataset:NonFiniteTrials', ...
                ['%d of %d trials contain non-finite samples and were dropped ' ...
                 '(NonFinite="keep" returns them).'], nnz(nonFiniteTrial), nTrials);
            data = data(:, ~nonFiniteTrial, :);
            kept = kept(~nonFiniteTrial);
            nTrials = numel(kept);
            if nTrials == 0
                error('ChronuxDataset:NoTrials', ...
                    'Every trial contains non-finite samples.');
            end
        end
    case "error"
        if any(nonFiniteTrial)
            error('ChronuxDataset:NonFiniteTrials', ...
                'Trials %s contain non-finite samples.', mat2str(droppedNonFinite));
        end
    case "keep"
        % returned as they are
end

data = ChronuxDataset.castTo(data, opts.Class);

if opts.Detrend ~= "none"
    n = double(opts.Detrend == "linear");   % 0 = constant, 1 = linear
    for c = 1:size(data, 3)
        data(:, :, c) = detrend(data(:, :, c), n);   % column-wise = per trial
    end
end

if size(data, 3) == 1
    data = data(:, :, 1);       % [nTime x nTrials] - what Chronux expects
end

params = obj.params(Fs=Fs, Tapers=opts.Tapers, Pad=opts.Pad, ...
    Fpass=opts.Fpass, Err=opts.Err, TrialAve=opts.TrialAve);

info = struct();
info.signal            = obj.Signal;
info.fs                = Fs;
info.units             = obj.dataUnits();
info.channels          = ch;
info.labels            = labels;
info.twin              = twin;
info.sampleOffsets     = [s0 s1];
info.onsetRule         = opts.OnsetRule;
info.nTime             = nTime;
info.nTrials           = nTrials;
info.nChan             = nChan;
info.keptTrials        = reshape(kept, 1, []);
info.onsets            = reshape(onsets(kept), 1, []);
info.onsetSamples      = reshape(base(kept), 1, []);
info.droppedIncomplete = droppedIncomplete;
info.droppedNonFinite  = droppedNonFinite;
info.detrend           = opts.Detrend;
info.class             = class(data);
info.T                 = T;
end

