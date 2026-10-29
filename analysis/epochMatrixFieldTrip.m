function data = epochMatrixFieldTrip(R, opts)
%epochMatrixFieldTrip  FieldTrip raw structures of a signal result's epochs.
%   DATA = epochMatrixFieldTrip(R) turns the epochs of an epochMatrix result
%   of a signal (data "LFP", "MUA", "SPIKE" or "AUX", computed with
%   keepEpochs=true) into FieldTrip raw structures (ft_datatype_raw), a cell
%   column, one per dataset of R.keys: DATA{k} is R.epochs(k)'s, built by
%   FieldTripExport.epochs.
%     trial{j}    [nChan x nTime], epoch j after Detrend, Baseline, Magnitude
%                 and Rectify (what R.data averages; never normalized)
%     time{j}     R.t, s from the event
%     sampleinfo  each epoch's samples on the dataset's continuous signal
%     trialinfo   [resultGroup trial]: the epoch's group in R.groupLabels
%                 (the same across datasets) and its trial in the session
%     elec        the channels' probe positions, um (when every one is known)
%     cfg         dataset, name, description, event, window, groupLabels,
%                 groups (R.labels.groups), trialinfoColumns and epochs (the
%                 epochs' table, R.epochs(k).E)
%   Class="single" keeps the data single.
%
%   Errors: epochMatrixFieldTrip:NotSignal, epochMatrixFieldTrip:NoEpochs.
%
%   See also FieldTripExport, sessionDataFieldTrip, epochMatrix.

arguments
    R (1,1) struct
    opts.Class (1,1) string {mustBeMember(opts.Class, ["double","single"])} = "double"
end
if R.rowKind ~= "channel"
    error('epochMatrixFieldTrip:NotSignal', ...
        'The result is of %s, not a signal: FieldTripExport.spike packages spikes.', R.settings.data);
end
if ~isfield(R, 'epochs') || isempty(R.epochs)
    error('epochMatrixFieldTrip:NoEpochs', ...
        'The result keeps no epochs: compute with keepEpochs=true ("Keep single trials").');
end
units = string(R.valueUnits);
if isfield(R, 'normalization') && isfield(R.normalization, 'rawUnits')
    units = string(R.normalization.rawUnits);   % the epochs are never normalized
end
hasPos = all(ismember(["x" "y"], string(R.rows.Properties.VariableNames)));

data = cell(numel(R.epochs), 1);
for k = 1:numel(R.epochs)
    e = R.epochs(k);
    ch = R.rows(e.rows, :);
    pos = [];
    if hasPos; pos = [ch.x ch.y]; end
    cfg = struct('dataset', e.key, 'name', e.name, 'description', R.labels.description, ...
        'event', R.labels.event, 'window', R.labels.window, 'groupLabels', R.groupLabels, ...
        'groups', R.labels.groups, 'trialinfoColumns', ["resultGroup" "trial"], 'epochs', e.E);
    data{k} = FieldTripExport.epochs(e.data, R.t, Onsets=e.E.t0Continuous, ...
        TrialInfo=[e.E.resultGroup e.E.trial], Label=ch.label, ChanType=lower(R.settings.data), ...
        ChanUnit=units, Positions=pos, Class=opts.Class, Cfg=cfg);
end
end
