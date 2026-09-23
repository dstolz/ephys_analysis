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
%     "event"  (default) base = round((t - 1/EventFs)*Fs) + 1. Digital-input
%              event times are t = row/EventFs on the recording's own sample
%              clock (readData, deriveSignals, eventOnsets; EventFs is the
%              recording rate), and that row lies at continuous time
%              t - 1/EventFs, so base is the signal row nearest the sample
%              that produced the event: that very sample at the recording
%              rate (base = round(t*Fs)), the nearest sample of a derived
%              signal at its own rate (within half a sample). It is the same
%              indexing EXTRACT_TRIALS uses.
%     "sample" base = round(t*Fs)+1, the sample whose own time (k-1)/Fs is
%              nearest the onset. Use it for times taken from a continuous
%              time base (readData's t, a derived signal's row times
%              (k-1)/Fs, spike times).
%   Chronux's createdatamatc anchors a trial on row floor(t*Fs)+1 -- the row
%   "sample" picks, or one earlier when t*Fs has a fractional part of 0.5 or
%   more -- and its window is right-exclusive, so it returns one sample fewer
%   (rows anchor+s0 ... anchor+s1-1). Handed digital-input times as they are,
%   it anchors each onset 1/EventFs late: t - 1/EventFs is the event's time
%   on the continuous clock.
%
%   Options
%   -------
%     Channels    [] (all, default), column indices, or channel labels
%     OnsetRule   "event" (default) | "sample", above
%     EventFs     rate of the clock "event" onsets count rows of (default: the
%                 recording rate the signal was read or derived from,
%                 Info.origFs; Fs for a matrix source, which has none)
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
%   onsetRule, eventFs (the EventFs "event" used), nTime, nTrials, nChan,
%   keptTrials (indices into ONSETS), onsets/onsetSamples (base) of the kept
%   trials, droppedIncomplete, droppedNonFinite, detrend, class, fs, signal,
%   units.
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
    opts.EventFs (1,1) double = NaN     % NaN = Info.origFs, else Fs
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

% The clock digital-input onsets count rows of: the recording rate, which a
% matrix source does not know (its events are taken to be on its own clock).
eventFs = opts.EventFs;
if isnan(eventFs)
    eventFs = Fs;
    if isfield(obj.Info, 'origFs') && isscalar(obj.Info.origFs) ...
            && isfinite(obj.Info.origFs) && obj.Info.origFs > 0
        eventFs = double(obj.Info.origFs);
    end
end
if ~(eventFs > 0)
    error('ChronuxDataset:BadEventFs', 'EventFs must be a positive rate; got %g.', eventFs);
end

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
    case "event",  base = round((onsets - 1/eventFs) * Fs) + 1;   % the row's continuous time
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
info.eventFs           = eventFs;
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

