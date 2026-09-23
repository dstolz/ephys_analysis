function [onsets, info] = eventOnsets(obj, name, opts)
%eventOnsets  Digital-input onsets to use as trial triggers.
%   ONSETS = cx.eventOnsets() returns the onset times (seconds) of the single
%   digital-input line of this recording; with several lines, name the one you
%   want: cx.eventOnsets("din0"), or by position, cx.eventOnsets(2).
%
%   [ONSETS, INFO] = cx.eventOnsets(...) also returns the offsets, the
%   durations, the line name and what was filtered out.
%
%   The events are the ones EphysDataset.readData / deriveSignals extracted
%   (the contiguous on segments of each line, times on the recording's own
%   sample grid with t = row/origFs). Feed them straight to trials /
%   spikeTrials: trials' default OnsetRule "event" puts such a time on the
%   signal sample nearest the one that produced it (that very sample at the
%   recording rate).
%
%   Options
%   -------
%     MinDurationSec  drop pulses shorter than this (default 0, keep all)
%     MaxDurationSec  drop pulses longer than this (default Inf)
%     TimeRange       [t0 t1] seconds; keep onsets inside it (default all)
%
%   INFO: name, onsets, offsets, durations, n, nTotal, keptEvents (indices into
%   the line's event list), droppedDuration, droppedTimeRange, lines (every
%   line name in this recording).
%
%   Example
%   -------
%     onsets = cx.eventOnsets("din0", MinDurationSec=0.01);
%     [D, params, T] = cx.trials(onsets, [-0.2 0.5], Channels=1, TrialAve=1);
%
%   See also ChronuxDataset.trials, ChronuxDataset.spikeTrials,
%   EphysDataset.readData.

arguments
    obj (1,1) ChronuxDataset
    name = []
    opts.MinDurationSec (1,1) double {mustBeNonnegative} = 0
    opts.MaxDurationSec (1,1) double {mustBePositive} = Inf
    opts.TimeRange (1,2) double = [-Inf Inf]
end

obj.loadSignal();
lines = string(fieldnames(obj.Events)).';
if isempty(lines)
    error('ChronuxDataset:NoEvents', ...
        ['This source carries no digital-input events (a matrix source has ' ...
         'none, and a recording with no dig-in lines has none either). Pass ' ...
         'onset times to trials / spikeTrials directly.']);
end

if isempty(name)
    if numel(lines) ~= 1
        error('ChronuxDataset:EventLine', ...
            'Name the digital-input line; this recording has %s.', ...
            strjoin(lines, ', '));
    end
    fld = lines(1);
elseif isnumeric(name)
    if ~isscalar(name) || name < 1 || name > numel(lines) || name ~= round(name)
        error('ChronuxDataset:EventLine', ...
            'Line index must be an integer in 1..%d (%s).', numel(lines), ...
            strjoin(lines, ', '));
    end
    fld = lines(name);
else
    fld = string(name);
    if ~ismember(fld, lines)
        error('ChronuxDataset:EventLine', ...
            'No digital-input line "%s"; this recording has %s.', fld, ...
            strjoin(lines, ', '));
    end
end

E = obj.Events.(fld);
if isempty(E)
    error('ChronuxDataset:NoEvents', 'Line "%s" has no events.', fld);
end
if size(E, 2) ~= 2
    error('ChronuxDataset:BadEvents', ...
        'Events for "%s" should be [k x 2] [t_on t_off]; got %s.', fld, ...
        mat2str(size(E)));
end

allOn  = E(:, 1);
allOff = E(:, 2);
dur    = allOff - allOn;

keepDur = dur >= opts.MinDurationSec & dur <= opts.MaxDurationSec;
keepRng = true(size(allOn));
if isfinite(opts.TimeRange(1)); keepRng = keepRng & allOn >= opts.TimeRange(1); end
if isfinite(opts.TimeRange(2)); keepRng = keepRng & allOn <= opts.TimeRange(2); end
keep = keepDur & keepRng;

onsets = allOn(keep);
if isempty(onsets)
    error('ChronuxDataset:NoEvents', ...
        'No event on line "%s" survives the duration / time-range filters.', fld);
end

info = struct();
info.name             = fld;
info.lines            = lines;
info.onsets           = onsets;
info.offsets          = allOff(keep);
info.durations        = dur(keep);
info.n                = numel(onsets);
info.nTotal           = numel(allOn);
info.keptEvents       = reshape(find(keep), 1, []);
info.droppedDuration  = reshape(find(~keepDur), 1, []);
info.droppedTimeRange = reshape(find(~keepRng & keepDur), 1, []);
end
