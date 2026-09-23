function [R, T, trl] = extract_trials(signal, onsets, Fs, twin, opts)
%EXTRACT_TRIALS  Epoch a multichannel signal around event onsets.
%   [R,T,TRL] = EXTRACT_TRIALS(SIGNAL,ONSETS,FS,TWIN) extracts trial-aligned
%   epochs from a continuous multichannel signal using event onset times.
%
%   Inputs:
%     SIGNAL   [nSamples x nChan] numeric array of continuous data, sample k
%              at t = (k-1)/FS.
%     ONSETS   vector of event times (in seconds), one trial each, in order.
%              They are digital-event times, t = row/EventFs, as this
%              pipeline reports digital-input events (see EventFs).
%     FS       scalar sampling rate in Hz (default = 1).
%     TWIN     1x2 vector [t0 t1] defining the window in seconds relative to
%              each onset (default = [-0.2 0.5]).
%     EventFs  (name-value) rate of the clock ONSETS count rows of (default
%              FS). Pass the recording rate when SIGNAL was derived at
%              another rate (e.g. an LFP at 1 kHz with events at 30 kHz), or
%              Inf for times already on SIGNAL's own clock, t = (k-1)/FS.
%
%   Onset row: an onset t = r/EventFs was sampled on row r, which lies at
%   continuous time t - 1/EventFs, so it falls on row
%   base = round((t - 1/EventFs)*FS) + 1 of SIGNAL, the sample nearest the one
%   that produced it (that very row when EventFs = FS). Trial i is rows
%   base(i)+round(t0*FS) ... base(i)+round(t1*FS), the "event" onset rule of
%   ChronuxDataset.trials.
%
%   Outputs:
%     R     [nTime x nChan x nTrials] array of extracted signal epochs, the
%           orientation of SIGNAL for each trial; samples outside SIGNAL are
%           NaN. Floating-point SIGNAL keeps its class; integer SIGNAL comes
%           back as double, which can hold the NaN.
%     T     1 x nTime vector of time (seconds) relative to event onset,
%           (round(t0*FS):round(t1*FS))/FS.
%     TRL   nTrials x 3 matrix following FieldTrip convention:
%              col 1 = begsample (first sample of the trial)
%              col 2 = endsample (last sample of the trial)
%              col 3 = offset (samples from the onset to begsample,
%                      round(t0*FS): negative when the trial starts before it)
%
%   Example:
%     [R,T,trl] = extract_trials(signal, eventTimes, 1000, [-0.1 0.4]);
%     [R,T,trl] = extract_trials(lfp, dinOnsets, 1000, [-0.1 0.4], EventFs=30000);
%
%   See also ChronuxDataset.trials.

arguments
    signal {mustBeReal, mustBeFinite}
    onsets double {mustBeFinite}
    Fs (1,1) double {mustBePositive,mustBeFinite} = 1
    twin (1,2) double {mustBeFinite} = [-0.2 0.5]
    opts.EventFs (1,1) double {mustBePositive} = Fs
end

% Build TRL in samples: [begsample endsample offset]
onsets = onsets(:);
on = round((onsets - 1 / opts.EventFs) * Fs) + 1;     % each onset's row
sw = round(twin * Fs);
if sw(2) < sw(1)
    error('extract_trials:BadWindow', ...
        'TWIN must be [t0 t1] with t0 <= t1; got [%g %g].', twin(1), twin(2));
end
trl = [on + sw(1), on + sw(2), repmat(sw(1), numel(on), 1)];

% Prepare time base
T = (sw(1):sw(2)) / Fs;

% Extract
[nSamps, nCh] = size(signal);
nTrials = size(trl, 1);
proto = signal([]);                 % integer signals come back as double (NaN padding)
if ~isfloat(proto); proto = double(proto); end
R = nan(numel(T), nCh, nTrials, like = proto);
for i = 1:nTrials
    sidx = trl(i, 1):trl(i, 2);
    keep = sidx >= 1 & sidx <= nSamps;
    R(keep, :, i) = signal(sidx(keep), :);
end
