function out = exportEpochs(obj, opts)
%exportEpochs  Write this dataset's data organized by event, epoch by epoch.
%   OUT = ds.exportEpochs(Name=Value) cuts the derived continuous signals,
%   the sorted units and the detected spikes into one epoch per event
%   (EphysDataset.eventEpochs) and saves them as one .mat, so a trial-by-trial
%   analysis can start from data that is already aligned. The events are a
%   digital-input line, the trials of the paired Epsych2 session, or times
%   passed in.
%
%   Nothing is analysed or averaged: the epochs hold the recorded samples and
%   spike times, selected and re-packaged.
%
%   Variables in the file
%   ---------------------
%     epochs   the EphysDataset.eventEpochs struct:
%                event     the events the epochs were cut around (source,
%                          name, window, onsets, offsets, recordingRange, ...)
%                trials    table, one row per epoch (EpochIndex, EpochOnset,
%                          EpochOffset, EpochDuration, EpochComplete, plus
%                          EventIndex or BehaviorRow and the behavior columns)
%                signals   LFP / MUA / SPIKE / AUX: data [nTime x nEpochs x
%                          nChan], t (seconds relative to the onset), fs,
%                          labels, units, info
%                units     1 x nUnits: id, label, class, group, channel,
%                          times {1 x nEpochs}, counts
%                detected  the same per detected channel, or []
%                spikes    how the spike times are stamped
%                behavior  the session and pairing the events came from, or []
%                meta      provenance
%     export   provenance: tool, created, dataset, sources, signals, window,
%              nEpochs (the same struct as epochs.meta)
%
%   Options
%   -------
%     File       target (default <outputFolder>/<Name>_epochs.mat)
%     Overwrite  false (default): error if File exists
%     MatVersion "-v7.3" (default) | "-v7"
%     Extract, Signals, Units, Groups, Detected, Events, EventSource,
%     EventLine, Times, Behavior, Window, OnsetRule, Incomplete, NonFinite,
%     SpikeTimeBase, Class, MinDurationSec, MaxDurationSec
%                as in EphysDataset.eventEpochs
%
%   OUT fields: file, bytes, seconds, signals, nEpochs, nUnits,
%   nDetectedChannels, eventSource, eventName, window, sources.
%
%   See also EphysDataset.eventEpochs, EphysDataset.exportChronux,
%   EphysDataset.exportFieldTrip, ChronuxDataset.trials.

arguments
    obj (1,1) EphysDataset
    opts.File (1,1) string = ""
    opts.Overwrite (1,1) logical = false
    opts.MatVersion (1,1) string {mustBeMember(opts.MatVersion, ["-v7.3", "-v7"])} = "-v7.3"
    opts.Extract = ""
    opts.Signals (1,:) string = string.empty(1,0)
    opts.Units = []
    opts.Groups (1,:) string = ["good" "mua"]
    opts.Detected = true
    opts.Events (1,1) logical = true
    opts.EventSource (1,1) string = "line"
    opts.EventLine (1,1) string = ""
    opts.Times double = double.empty(0,1)
    opts.Behavior = []
    opts.Window (1,2) double = [-0.2 0.5]
    opts.OnsetRule (1,1) string = "event"
    opts.Incomplete (1,1) string = "nan"
    opts.NonFinite (1,1) string = "keep"
    opts.SpikeTimeBase (1,1) string = "onset"
    opts.Class (1,1) string = "double"
    opts.MinDurationSec (1,1) double = 0
    opts.MaxDurationSec (1,1) double = Inf
end

t0 = tic;
file = opts.File;
if file == ""
    file = string(fullfile(obj.outputFolder(), obj.Name + "_epochs.mat"));
end
if isfile(file) && ~opts.Overwrite
    error('EphysDataset:exportEpochs:Exists', ...
        '%s already exists (pass Overwrite=true to replace it).', file);
end

build = rmfield(opts, {'File', 'Overwrite', 'MatVersion'});
args = namedargs2cell(build);
epochs = obj.eventEpochs(args{:});

S = struct();
S.epochs = epochs;
S.export = epochs.meta;
S.export.tool = "EphysDataset.exportEpochs";

EphysDataset.saveAtomically(file, S, opts.MatVersion);

d = dir(file);
out = struct('file', file, 'bytes', d.bytes, 'seconds', toc(t0), ...
    'signals', epochs.meta.signals, 'nEpochs', epochs.meta.nEpochs, ...
    'nUnits', epochs.meta.nUnits, 'nDetectedChannels', epochs.meta.nDetectedChannels, ...
    'eventSource', epochs.meta.eventSource, 'eventName', epochs.meta.eventName, ...
    'window', epochs.meta.window, 'sources', epochs.meta.sources);
end
