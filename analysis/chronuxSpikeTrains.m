function SP = chronuxSpikeTrains(X, source, which)
%chronuxSpikeTrains  Spike trains of a Chronux file's index, for the spike analyses.
%   SP = chronuxSpikeTrains(X, SOURCE, WHICH): X from loadChronuxExport,
%   SOURCE "units" (the sorted units, X.sp, labeled by X.units.label) or
%   "detected" (the threshold detections, X.spDetected, labeled by their
%   channel names), WHICH the trains to keep (indices; [] = all). SP:
%   times (1 x n struct array with field times, s on the recording's
%   continuous clock: Chronux's point-process form), labels (1 x n),
%   index (WHICH), class (the units' su / mua / ..., "" for detections),
%   source. Errors chronuxSpikeTrains:None (the file has no such spikes),
%   chronuxSpikeTrains:BadIndex.
%
%   See also chronuxSpikeSpectrum, chronuxSpikeField, chronuxUnitCoherence.
arguments
    X (1,1) struct
    source (1,1) string {mustBeMember(source, ["units" "detected"])}
    which double = []
end
if source == "units"
    tr = X.sp;
    n = numel(tr);
    labels = "unit " + string(1:n);
    cls = strings(1, n);
    if isstruct(X.units) && isfield(X.units, 'label') && numel(X.units.label) == n
        labels = reshape(string(X.units.label), 1, []);
    end
    if isstruct(X.units) && isfield(X.units, 'class') && numel(X.units.class) == n
        cls = reshape(string(X.units.class), 1, []);
    end
    what = "sorted units";
else
    tr = X.spDetected;
    n = numel(tr);
    labels = "ch" + string(1:n);
    cls = strings(1, n);
    if isstruct(X.detected) && isfield(X.detected, 'channelNames') && numel(X.detected.channelNames) == n
        labels = reshape(string(X.detected.channelNames), 1, []);
    end
    what = "threshold detections";
end
if n == 0
    error('chronuxSpikeTrains:None', 'The Chronux file holds no %s.', what);
end
if isempty(which); which = 1:n; end
which = reshape(double(which), 1, []);
if any(which < 1 | which > n | which ~= round(which))
    error('chronuxSpikeTrains:BadIndex', 'Spike trains are numbered 1 to %d.', n);
end
SP = struct();
SP.times = reshape(tr(which), 1, []);
SP.labels = labels(which);
SP.index = which;
SP.class = cls(which);
SP.source = source;
end
