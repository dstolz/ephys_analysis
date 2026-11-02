function M = epochMatrixMTRF(R, opts)
%epochMatrixMTRF  mTRF-Toolbox stimulus / response pairs of a result's epochs.
%   M = epochMatrixMTRF(R) turns the epochs of an epochMatrix result
%   computed with keepEpochs=true ("Keep single trials") into the inputs
%   the mTRF-Toolbox fits, a cell column, one mTRFExport.package per
%   dataset of R.keys (DATA{k} is R.epochs(k)'s): each epoch is a trial.
%     resp   a signal's epochs (data LFP, MUA, SPIKE or AUX: what R.data
%            averages, after Detrend, Baseline, Magnitude and Rectify, never
%            normalized) resampled to Fs ([] = the result's own rate, the
%            default); spike epochs (data units or detected) binned at Fs
%            (128 Hz by default) as rates, spikes/s (SpikeUnits="count"
%            for counts per bin). M{k}.t is the epochs' sample times, s
%            from the event (M{k}.fs the rate reached)
%     stim   one of
%       "onset" (default): an impulse on the sample nearest the epoch's
%         event (t = 0), ImpulseHeight tall (fs by default: unit area, the
%         discrete delta, so the forward model's weights, which the
%         toolbox scales by fs, are in the response's units per event;
%         1 for a plain 0/1 feature), scaled by Values= (a function of the
%         epochs table E returning one value per epoch, e.g. @(E)
%         E.groupIndex, or an [nEpochs x 1] vector per dataset in a cell).
%         A forward model fit on this with (almost) no regularization is
%         the mean evoked response, lag by lag: the check that the
%         pipeline and the toolbox agree
%       a function handle f(E(j, :), t) returning [nTime x nFeatures] for
%         epoch j (E its row of the epochs table, t the sample times):
%         the stimulus of each trial from its number, group or your own
%         files
%   trialinfo is [resultGroup trial] (the epoch's group in R.groupLabels
%   and its trial in the session) as a table; start each epoch's first
%   sample on the dataset's continuous clock; cfg holds dataset, name,
%   data, description, event, window, groupLabels, groups and the epochs
%   table.
%
%   Each epoch of a signal is resampled with the others in one call and
%   mirrored past its ends (mTRFExport.resample), so its first and last
%   samples are not pulled toward zero. Epochs whose windows overlap (events
%   closer than the window is long) share samples, which inflates a
%   leave-one-epoch-out cross-validation: a warning (mTRFExport:Overlap)
%   says so, and mTRFExport.folds(M{k}, K) regroups the epochs into blocks
%   with overlapping epochs together (splitTrials).
%
%   Errors: epochMatrixMTRF:NoEpochs, epochMatrixMTRF:BadStimulus, plus
%   mTRFExport's.
%
%   See also mTRFExport, sessionDataMTRF, splitTrials, epochMatrix, epochMatrixFieldTrip.

arguments
    R (1,1) struct
    opts.Fs double = []
    opts.Stimulus = "onset"
    opts.Values = []
    opts.ImpulseHeight double = []
    opts.SpikeUnits (1,1) string {mustBeMember(opts.SpikeUnits, ["rate" "count"])} = "rate"
end
if ~isfield(R, 'epochs') || isempty(R.epochs)
    error('epochMatrixMTRF:NoEpochs', ...
        'The result keeps no epochs: compute with keepEpochs=true ("Keep single trials").');
end
isUnit = R.rowKind == "unit";
t0 = R.t(:);
fsR = 1 / mean(diff(t0));
fs = opts.Fs;
if isempty(fs)
    fs = fsR;
    if isUnit; fs = 128; end
end
st = opts.Stimulus;
stimIsOnset = (isstring(st) || ischar(st)) && string(st) == "onset";
if ~stimIsOnset && ~isa(st, 'function_handle')
    error('epochMatrixMTRF:BadStimulus', 'Stimulus must be "onset" or a function handle f(E, t).');
end
units = string(R.valueUnits);
if isfield(R, 'normalization') && isfield(R.normalization, 'rawUnits')
    units = string(R.normalization.rawUnits);
end
hasPos = all(ismember(["x" "y"], string(R.rows.Properties.VariableNames)));

M = cell(numel(R.epochs), 1);
for k = 1:numel(R.epochs)
    e = R.epochs(k);
    E = e.E;
    nE = height(E);
    rows = R.rows(e.rows, :);

    % --- the epochs at fs -----------------------------------------------------------------
    if isUnit
        % the grid on multiples of 1/fs, so the event (t = 0) is one of its samples
        t = (round(t0(1) * fs):round(t0(end) * fs)).' / fs;
        nT = numel(t);
        edges = [t - 0.5 / fs; t(end) + 0.5 / fs];
        % every unit's spikes binned once, for all the epochs: [bin, epoch] pairs counted by accumarray
        Y = zeros(nT, numel(e.spikes), nE);
        for u = 1:numel(e.spikes)
            if nE == 0; break; end
            s = e.spikes(u);
            b = discretize(s.times(:), edges);      % as histcounts: the last bin takes its right edge
            ep = double(s.epoch(:));
            ok = ~isnan(b) & ep >= 1 & ep <= nE;
            Y(:, u, :) = reshape(accumarray([b(ok), ep(ok)], 1, [nT nE]), nT, 1, nE);
        end
        if opts.SpikeUnits == "rate"; Y = Y * fs; end
        resp = reshape(num2cell(Y, [1 2]), [], 1);  % {nE x 1} of [nT x nUnits]
        respUnits = "spikes/s";
        if opts.SpikeUnits == "count"; respUnits = "spikes"; end
    else
        resp = cell(nE, 1);
        if nE > 0
            % one resample call for all the epochs (a column each); it mirrors each column past its ends
            [nCh, nTin, ~] = size(e.data);
            [Y, fs] = mTRFExport.resample(reshape(permute(e.data, [2 1 3]), nTin, nCh * nE), fsR, fs);
            nT = size(Y, 1);
            resp = reshape(num2cell(reshape(Y, nT, nCh, nE), [1 2]), [], 1);   % {nE x 1} of [nT x nChan]
        else
            nT = numel(t0);                     % no epochs left: the grid as given
        end
        if fs == fsR && nT == numel(t0)
            t = t0;                             % not resampled: the result's own times
        else
            t = t0(1) + (0:nT-1).' / fs;
        end
        respUnits = units;
    end

    % --- the stimulus -----------------------------------------------------------------------
    stim = cell(nE, 1);
    if stimIsOnset
        v = valuesOf(opts.Values, E, k, nE);
        h = opts.ImpulseHeight;
        if isempty(h); h = fs; end
        j0 = round(-t0(1) * fs) + 1;
        for j = 1:nE
            x = zeros(nT, 1);
            if j0 >= 1 && j0 <= nT; x(j0) = v(j) * h; end
            stim{j} = x;
        end
        stimLabels = "onset";
        stimText = "an impulse on the event";
        if ~isempty(opts.Values); stimText = stimText + " scaled by Values"; end
    else
        for j = 1:nE
            x = double(st(E(j, :), t));
            if size(x, 1) ~= nT
                error('epochMatrixMTRF:BadStimulus', ...
                    'The stimulus function returned %d rows for epoch %d of %s; %d expected.', size(x, 1), j, e.name, nT);
            end
            stim{j} = x;
        end
        nF = 0; if nE > 0; nF = size(stim{1}, 2); end
        stimLabels = "f" + string(1:nF);
        stimText = func2str(st);
    end

    pos = [];
    if hasPos; pos = [rows.x rows.y]; end
    start = E.t0Continuous + t(1);
    nOver = nnz(mTRFExport.overlaps(start, start + nT / fs));
    if nOver > 0
        warning('mTRFExport:Overlap', ...
            ['%s: %d of %d epochs overlap the one before them: as cross-validation folds they share samples, ' ...
             'which inflates the prediction. Shorten the window, or group them with mTRFExport.folds, ' ...
             'which keeps overlapping epochs in one fold.'], e.name, nOver, nE);
    end
    cfg = struct('dataset', e.key, 'name', e.name, 'data', R.settings.data, 'description', R.labels.description, ...
        'event', R.labels.event, 'window', R.labels.window, 'groupLabels', R.groupLabels, ...
        'groups', R.labels.groups, 'stimulus', stimText, 'sourceFs', fsR, 'epochs', E);
    M{k} = mTRFExport.package(stim, resp, fs, StimLabels=stimLabels, ...
        RespLabels=reshape(string(rows.label), 1, []), RespUnits=respUnits, Positions=pos, ...
        Start=start, Time=t, TrialInfo=table(E.resultGroup, E.trial, 'VariableNames', {'resultGroup', 'trial'}), ...
        Cfg=cfg);
end
end

function v = valuesOf(values, E, k, nE)
if isempty(values)
    v = ones(nE, 1);
elseif isa(values, 'function_handle')
    v = double(values(E));
elseif iscell(values)
    v = double(values{k});
else
    v = double(values);
end
v = reshape(v, [], 1);
if numel(v) ~= nE
    error('epochMatrixMTRF:BadStimulus', 'Values gives %d values for %d epochs.', numel(v), nE);
end
v(isnan(v)) = 0;
end
