function M = sessionDataMTRF(D, opts)
%sessionDataMTRF  mTRF-Toolbox stimulus / response pairs of whole sessions.
%   M = sessionDataMTRF(D, Stimulus=...) turns sessionData structs
%   (DatasetBrowser's B.Sessions after Load whole sessions) into the
%   inputs the mTRF-Toolbox fits (mTRFtrain, mTRFcrossval, mTRFpredict), a
%   cell column, one mTRFExport.package per element of D:
%     resp   the dataset's signal (Data LFP, MUA, SPIKE or AUX: the
%            channels the browser kept) resampled to Fs (128 Hz by
%            default; the rate reached is M{k}.fs), or its spike trains
%            (Data units or detected) binned at Fs as rates, spikes/s
%            (SpikeUnits="count" for counts per bin)
%     stim   the stimulus features at the same rate, from Stimulus:
%       a string array of line names and trial columns, one feature each:
%         a digital line ("Stim", a derived event): its pulses as
%           mTRFExport.pulses makes them, Kind= "onset" (an impulse on each
%           onset's sample, the default), "offset" or "boxcar"
%         a numeric column of D.trials ("Depth", "Level"): an impulse of
%           that value on each trial's Align sample (every trial, kept or
%           not: the stimulus happened; a missing value counts as 0)
%       An impulse is ImpulseHeight tall: fs by default (unit area, the
%         discrete delta), so a forward model's weights, which the toolbox
%         scales by fs, are the response per pulse (per unit of the trial
%         column) in the signal's units; ImpulseHeight=1 for the toolbox's
%         plain 0/1 features. A boxcar is 1.
%       a struct array of sessionData of a signal (B.Sessions loaded with
%         Data AUX in another browser, or sessionData(src, S) with
%         S.data = "AUX"), matched to D by key: its channels
%         (StimulusChannels=, columns of its signal; all by default) as
%         the stimulus, each column's amplitude envelope (Envelope=true,
%         the default; mTRFExport.envelope with EnvelopeMethod= and
%         Compression=) or the signal itself resampled
%       a function handle f(D(k)) returning a struct with x ([n x nFeat]
%         at fs, row j at (j-1)/fs on the dataset's continuous clock),
%         fs and labels (optional): a feature of your own (a sound's
%         spectrogram, a stimulus file's envelope, ...), resampled to Fs
%     the trials (the toolbox's folds), from Mode:
%       "segments" (default): the artifact-free stretches of the session,
%         split into pieces no longer than MaxSeconds (60 s by default)
%         and no shorter than MinSeconds (2 s): continuous data for
%         cross-validation (mTRFExport.segments)
%       "trials": the kept trials cut in Window ([pre post] s) around
%         Align (a column of D.trials on the digital clock, "TrialOnset"
%         by default, or a digital line: every pulse of it), trials off
%         the signal or touching an erased period left out
%         (mTRFExport.trials)
%   Each package carries the channel labels and probe positions
%   (respLabels, pos), the feature names (stimLabels), each trial's start
%   on the continuous clock (start), trialinfo (segments: first and last
%   sample at fs; trials: the trial's row of D.trials and its group, or
%   the pulse's index) and cfg (dataset, name, data, mode, window, align,
%   stimulus, the options).
%
%   A stimulus shorter than the response is padded with zeros (silence
%   after it), a longer one trimmed to the response (resampling two rates
%   can differ by a sample at the end).
%
%   Errors: sessionDataMTRF:NoData, sessionDataMTRF:NoStimulus,
%   sessionDataMTRF:BadStimulus, sessionDataMTRF:NoTrials, plus
%   mTRFExport's.
%
%   See also mTRFExport, epochMatrixMTRF, sessionData, sessionDataFieldTrip.

arguments
    D struct
    opts.Stimulus = []
    opts.Fs (1,1) double {mustBePositive} = 128
    opts.Kind string = "onset"
    opts.ImpulseHeight double = []
    opts.StimulusChannels (1,:) double = []
    opts.Envelope (1,1) logical = true
    opts.EnvelopeMethod (1,1) string {mustBeMember(opts.EnvelopeMethod, ["rms" "hilbert"])} = "rms"
    opts.Compression (1,1) double {mustBeNonnegative} = log10(2)
    opts.Mode (1,1) string {mustBeMember(opts.Mode, ["segments" "trials"])} = "segments"
    opts.Window double = []
    opts.Align (1,1) string = "TrialOnset"
    opts.MinSeconds (1,1) double {mustBeNonnegative} = 2
    opts.MaxSeconds (1,1) double {mustBePositive} = 60
    opts.SpikeUnits (1,1) string {mustBeMember(opts.SpikeUnits, ["rate" "count"])} = "rate"
end

if isempty(opts.Stimulus)
    error('sessionDataMTRF:NoStimulus', ...
        'Stimulus= names the stimulus: lines / trial columns, a struct array of AUX sessions, or a function.');
end
if opts.Mode == "trials" && (numel(opts.Window) ~= 2 || opts.Window(2) <= opts.Window(1))
    error('sessionDataMTRF:NoTrials', 'Mode "trials" needs Window=[pre post] (s).');
end

M = cell(numel(D), 1);
for k = 1:numel(D)
    d = D(k);

    % --- the response at Fs -----------------------------------------------------------------
    if ~isempty(d.signal)
        [resp, fs] = mTRFExport.resample(d.signal, d.signalFs, opts.Fs);
        respLabels = reshape(string(d.channels.label), 1, []);
        pos = [d.channels.x d.channels.y];
        respUnits = string(d.channels.units(1));
    elseif ~isempty(d.spikes)
        fs = opts.Fs;
        tEnd = d.durationSec;
        if ~isfinite(tEnd); tEnd = max(cellfun(@(s) max([s(:); 0]), d.spikes)); end
        N = max(1, ceil(tEnd * fs));
        edges = ((0:N) - 0.5) / fs;             % bin j centered on sample j, (j-1)/fs
        resp = zeros(N, numel(d.spikes));
        for u = 1:numel(d.spikes)
            resp(:, u) = histcounts(d.spikes{u}, edges);
        end
        if opts.SpikeUnits == "rate"; resp = resp * fs; end
        respLabels = reshape(string(d.units.label), 1, []);
        pos = NaN(numel(d.spikes), 2);
        if all(ismember(["x" "y"], string(d.units.Properties.VariableNames)))
            pos = [d.units.x d.units.y];
        end
        respUnits = "spikes/s";
        if opts.SpikeUnits == "count"; respUnits = "spikes"; end
    else
        error('sessionDataMTRF:NoData', '%s holds no signal or spikes (data "%s").', d.name, d.data);
    end
    N = size(resp, 1);

    % --- the stimulus at fs -----------------------------------------------------------------
    [stim, stimLabels, stimUnits, stimText] = stimulusOf(d, opts, fs, N);
    n = min(N, size(stim, 1));
    resp = resp(1:n, :);
    stim = stim(1:n, :);
    N = n;

    % --- the trials -------------------------------------------------------------------------
    switch opts.Mode
        case "segments"
            [R, rows] = mTRFExport.segments(resp, fs, Artifacts=d.artifacts, ...
                MinSeconds=opts.MinSeconds, MaxSeconds=opts.MaxSeconds);
            S = cutRows(stim, rows);
            info = table(rows(:, 1), rows(:, 2), 'VariableNames', {'first', 'last'});
            t = [];
        case "trials"
            [onsets, info0, alignText] = onsetsOf(d, opts.Align);
            [R, keep, t, rows] = mTRFExport.trials(resp, fs, onsets, opts.Window, Artifacts=d.artifacts);
            S = cutRows(stim, rows);
            info = info0(keep, :);
    end
    start = (rows(:, 1) - 1) / fs;

    cfg = struct('dataset', d.key, 'name', d.name, 'data', d.data, 'mode', opts.Mode, ...
        'window', opts.Window, 'align', opts.Align, 'stimulus', stimText, 'nSamples', N, ...
        'sourceFs', d.signalFs, 'groups', d.groups, 'options', rmfield(opts, 'Stimulus'));
    if opts.Mode == "trials"; cfg.align = alignText; end
    M{k} = mTRFExport.package(S, R, fs, StimLabels=stimLabels, RespLabels=respLabels, ...
        StimUnits=stimUnits, RespUnits=respUnits, Positions=pos, Start=start, Time=t, ...
        TrialInfo=info, Cfg=cfg);
end
end

function C = cutRows(X, rows)
C = cell(size(rows, 1), 1);
for j = 1:size(rows, 1)
    C{j} = X(rows(j, 1):rows(j, 2), :);
end
end

function [onsets, info, text] = onsetsOf(d, align)
% the kept trials' Align column, or every pulse of the line Align, on the continuous clock
if d.hasTrials && ismember(align, string(d.trials.Properties.VariableNames))
    idx = find(d.kept);
    onsets = d.toContinuous(double(d.trials.(align)(idx)));
    info = table(idx, d.group(idx), 'VariableNames', {'trial', 'group'});
    text = align + " of the kept trials";
elseif isfield(d.eventsContinuous, align)
    iv = d.eventsContinuous.(align);
    onsets = iv(:, 1);
    info = table((1:numel(onsets)).', 'VariableNames', {'pulse'});
    text = "every " + align + " pulse";
else
    error('sessionDataMTRF:NoTrials', ...
        '%s has no trials column or line "%s" to align on.', d.name, align);
end
end

function [stim, labels, units, text] = stimulusOf(d, opts, fs, N)
st = opts.Stimulus;
units = "";
if isstring(st) || ischar(st) || iscellstr(st)
    names = reshape(string(st), 1, []);
    kind = reshape(string(opts.Kind), 1, []);
    if isscalar(kind); kind = repmat(kind, 1, numel(names)); end
    if numel(kind) ~= numel(names)
        error('sessionDataMTRF:BadStimulus', 'Kind has %d entries for %d stimulus names.', numel(kind), numel(names));
    end
    stim = zeros(N, numel(names));
    h = opts.ImpulseHeight;
    if isempty(h); h = fs; end
    trialVars = string.empty;
    if d.hasTrials; trialVars = string(d.trials.Properties.VariableNames); end
    parts = strings(1, numel(names));
    for i = 1:numel(names)
        nm = names(i);
        if isfield(d.eventsContinuous, nm)
            hi = h; if kind(i) == "boxcar"; hi = 1; end
            stim(:, i) = mTRFExport.pulses(d.eventsContinuous.(nm), fs, N, Kind=kind(i), Height=hi);
            parts(i) = nm + " " + kind(i);
        elseif ismember(nm, trialVars) && isnumeric(d.trials.(nm))
            if ~ismember(opts.Align, trialVars)
                error('sessionDataMTRF:BadStimulus', ...
                    '%s: the trial column "%s" needs Align= to be a trials column ("%s" is not).', d.name, nm, opts.Align);
            end
            on = d.toContinuous(double(d.trials.(opts.Align)));
            stim(:, i) = mTRFExport.pulses([on on], fs, N, Kind="onset", Value=double(d.trials.(nm)), Height=h);
            parts(i) = nm + " on " + opts.Align;
        else
            error('sessionDataMTRF:BadStimulus', ...
                '%s has no line or numeric trial column "%s" (lines: %s; columns: %s).', d.name, nm, ...
                strjoin(string(fieldnames(d.eventsContinuous)), ', '), strjoin(trialVars, ', '));
        end
    end
    labels = names;
    text = strjoin(parts, ", ");
elseif isstruct(st)
    j = find(string({st.key}) == d.key, 1);
    if isempty(j)
        error('sessionDataMTRF:BadStimulus', 'The stimulus sessions hold no dataset "%s".', d.name);
    end
    a = st(j);
    if isempty(a.signal)
        error('sessionDataMTRF:BadStimulus', '%s: the stimulus session holds no signal (data "%s").', d.name, a.data);
    end
    ch = opts.StimulusChannels;
    if isempty(ch); ch = 1:size(a.signal, 2); end
    x = a.signal(:, ch);
    if opts.Envelope
        stim = mTRFExport.envelope(x, a.signalFs, fs, Method=opts.EnvelopeMethod, Compression=opts.Compression);
        text = a.data + " envelope";
    else
        stim = mTRFExport.resample(x, a.signalFs, fs);
        text = a.data;
        units = string(a.channels.units(1));
    end
    labels = reshape(string(a.channels.label(ch)), 1, []);
    text = text + " of " + strjoin(labels, ", ");
elseif isa(st, 'function_handle')
    s = st(d);
    if ~isstruct(s) || ~isfield(s, 'x') || ~isfield(s, 'fs')
        error('sessionDataMTRF:BadStimulus', 'The stimulus function must return a struct with x and fs.');
    end
    stim = mTRFExport.resample(s.x, s.fs, fs);
    labels = string.empty;
    if isfield(s, 'labels'); labels = reshape(string(s.labels), 1, []); end
    if isempty(labels); labels = "f" + string(1:size(stim, 2)); end
    if isfield(s, 'units'); units = string(s.units); end
    text = func2str(st);
else
    error('sessionDataMTRF:BadStimulus', 'Stimulus must be names, a struct array of sessions, or a function handle.');
end
if size(stim, 1) < N
    stim(end+1:N, :) = 0;   % a stimulus shorter than the response: silence after it
end
end
