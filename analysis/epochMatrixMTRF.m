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
%   Errors: epochMatrixMTRF:NoEpochs, epochMatrixMTRF:BadStimulus, plus
%   mTRFExport's.
%
%   See also mTRFExport, sessionDataMTRF, epochMatrix, epochMatrixFieldTrip.

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
        nT = round((t0(end) - t0(1)) * fs) + 1;
        t = t0(1) + (0:nT-1).' / fs;
        edges = [t - 0.5 / fs; t(end) + 0.5 / fs];
        resp = cell(nE, 1);
        for j = 1:nE
            Y = zeros(nT, numel(e.spikes));
            for u = 1:numel(e.spikes)
                s = e.spikes(u);
                Y(:, u) = histcounts(s.times(s.epoch == j), edges);
            end
            if opts.SpikeUnits == "rate"; Y = Y * fs; end
            resp{j} = Y;
        end
        respUnits = "spikes/s";
        if opts.SpikeUnits == "count"; respUnits = "spikes"; end
    else
        resp = cell(nE, 1);
        for j = 1:nE
            [resp{j}, fsOut] = mTRFExport.resample(e.data(:, :, j).', fsR, fs);
        end
        if nE > 0; fs = fsOut; end
        nT = size(resp{1}, 1);
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
