function data = epochMatrixFieldTrip(R, opts)
%epochMatrixFieldTrip  FieldTrip structures of a result's epochs: raw for a signal, spike for spikes.
%   DATA = epochMatrixFieldTrip(R) turns the epochs of an epochMatrix result
%   (computed with keepEpochs=true) into FieldTrip structures, a cell
%   column, one per dataset of R.keys: DATA{k} is R.epochs(k)'s.
%
%   A signal (data "LFP", "MUA", "SPIKE" or "AUX") gives raw structures
%   (ft_datatype_raw), built by FieldTripExport.epochs:
%     trial{j}    [nChan x nTime], epoch j after Detrend, Baseline, Magnitude
%                 and Rectify (what R.data averages; never normalized)
%     time{j}     R.t, s from the event
%     sampleinfo  each epoch's samples on the dataset's continuous signal
%     elec        the channels' probe positions, um (when every one is known)
%
%   Spikes (data "units" or "detected") give spike structures
%   (ft_datatype_spike), built by FieldTripExport.spikeTrials, as
%   ft_spike_maketrials leaves them:
%     time{u}     unit u's spike times, s from the event, inside the
%                 window's whole bins (the span the PSTH counts)
%     trial{u}    each spike's epoch (a row of trialinfo)
%     trialtime   that span, [pre post] s, for every epoch
%     timestamp{u} the spikes' 0-based samples at the recording rate,
%                 with Fs= (one rate, or one per dataset); without it,
%                 microseconds from each epoch's event
%
%   Both carry
%     trialinfo   [resultGroup trial]: the epoch's group in R.groupLabels
%                 (the same across datasets) and its trial in the session
%     cfg         dataset, name, description, event, window, groupLabels,
%                 groups (R.labels.groups), trialinfoColumns and epochs (the
%                 epochs' table, R.epochs(k).E)
%   Class="single" keeps a signal's data single.
%
%   Errors: epochMatrixFieldTrip:NoEpochs, epochMatrixFieldTrip:BadFs.
%
%   See also FieldTripExport, sessionDataFieldTrip, epochMatrix.

arguments
    R (1,1) struct
    opts.Class (1,1) string {mustBeMember(opts.Class, ["double","single"])} = "double"
    opts.Fs double = []
end
if ~isfield(R, 'epochs') || isempty(R.epochs)
    error('epochMatrixFieldTrip:NoEpochs', ...
        'The result keeps no epochs: compute with keepEpochs=true ("Keep single trials").');
end
nK = numel(R.epochs);
fs = opts.Fs;
if isempty(fs); fs = NaN; end
if isscalar(fs); fs = repmat(fs, nK, 1); end
if numel(fs) ~= nK
    error('epochMatrixFieldTrip:BadFs', '%d rates for %d datasets.', numel(fs), nK);
end
if R.rowKind == "unit"
    data = spikeEpochs(R, fs);
    return
end

units = string(R.valueUnits);
if isfield(R, 'normalization') && isfield(R.normalization, 'rawUnits')
    units = string(R.normalization.rawUnits);   % the epochs are never normalized
end
hasPos = all(ismember(["x" "y"], string(R.rows.Properties.VariableNames)));

data = cell(nK, 1);
for k = 1:nK
    e = R.epochs(k);
    ch = R.rows(e.rows, :);
    pos = [];
    if hasPos; pos = [ch.x ch.y]; end
    data{k} = FieldTripExport.epochs(e.data, R.t, Onsets=e.E.t0Continuous, ...
        TrialInfo=[e.E.resultGroup e.E.trial], Label=ch.label, ChanType=lower(R.settings.data), ...
        ChanUnit=units, Positions=pos, Class=opts.Class, Cfg=epochCfg(R, e));
end
end


function data = spikeEpochs(R, fs)
%spikeEpochs  A spike structure per dataset from R.epochs(k).spikes.
% the spikes were kept inside the window's whole bins: that span is the trial
bin = R.settings.binSec;
w = R.settings.window;
span = [ceil(w.pre / bin - 1e-9), floor(w.post / bin + 1e-9)] * bin;
data = cell(numel(R.epochs), 1);
for k = 1:numel(R.epochs)
    e = R.epochs(k);
    onsets = [];
    if isfinite(fs(k)); onsets = e.E.t0Continuous; end
    data{k} = FieldTripExport.spikeTrials({e.spikes.times}, {e.spikes.epoch}, span, ...
        NTrials=height(e.E), Onsets=onsets, Fs=fs(k), TrialInfo=[e.E.resultGroup e.E.trial], ...
        Label=string(R.rows.label(e.rows)), Cfg=epochCfg(R, e));
end
end


function cfg = epochCfg(R, e)
%epochCfg  What every structure of R.epochs(k) records about the result.
cfg = struct('dataset', e.key, 'name', e.name, 'description', R.labels.description, ...
    'event', R.labels.event, 'window', R.labels.window, 'groupLabels', R.groupLabels, ...
    'groups', R.labels.groups, 'trialinfoColumns', ["resultGroup" "trial"], 'epochs', e.E);
end
