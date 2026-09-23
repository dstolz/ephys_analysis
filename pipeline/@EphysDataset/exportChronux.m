function out = exportChronux(obj, opts)
%exportChronux  Write this dataset's data in the shapes Chronux functions take.
%   OUT = ds.exportChronux(Name=Value) packages the derived continuous
%   signals, the sorted units and/or threshold-detected spikes and the
%   digital-input events into one .mat that can be loaded and handed
%   straight to Chronux (mtspectrumc, mtspectrumpt, ...) outside this app.
%   Behavior data has its own file (behaviorToMat). Packaging goes through
%   ChronuxDataset (the Chronux connector); no Chronux function is called
%   and nothing is analysed.
%
%   Variables in the file
%   ---------------------
%     LFP / MUA / SPIKE / AUX   one struct per exported signal:
%                           data    [nSamples x nChan] double, microvolts
%                                   (AUX: accelerometer inputs, volts)
%                           params  Chronux params (Fs = the signal rate)
%                           t       [1 x nSamples] seconds, t = (k-1)/Fs
%                           labels  1 x nChan channel labels
%                           info    what ChronuxDataset.continuous reported
%     sp          1 x nUnits struct array with field times (sorted units),
%                 or [] when there are none - the mtspectrumpt input form
%     spDetected  the same for threshold-detected spikes, one element per
%                 channel, or []
%     units       the readSortedUnits struct (ids, labels, channels, ...) or []
%     detected    the spikesToMat detected struct or []
%     events      dig-in lines -> [k x 2] [t_on t_off] seconds, t = row/eventFs
%                 on the recording's clock: on a signal at Fs that is row
%                 round((t - 1/eventFs)*Fs) + 1 (ChronuxDataset.trials' "event"
%                 rule)
%     artifacts   the artifact periods erased before the signals were
%                 derived (the extract's info.artifacts): intervals [k x 2]
%                 [tStart tEnd) seconds on the continuous clock -- the rows of
%                 a signal they touch are those with t in or next to them,
%                 EphysDataset.intervalRows -- fill and nSamples. No intervals:
%                 nothing was erased
%     export      provenance: tool, created, dataset, sources, signals,
%                 eventFs (the recording rate), timeConventions
%
%   Options
%   -------
%     File       target (default <outputFolder>/<Name>_chronux.mat)
%     Extract    "" (default: <outputFolder>/<Name>_extract.mat, else the
%                <Name>_extract_<TYPE>.mat files present), other extract
%                file(s) -- several are merged, e.g. the per-type files of
%                toMat(SeparateFiles=true), of which only those of Signals
%                are read -- or a toMat-shaped struct (Y, events, info)
%     Signals    subset of ["LFP" "MUA" "SPIKE" "AUX"] ([] = all present)
%     Units      [] (default: the associated sorted units when present) |
%                a units struct | false (none)
%     Groups     phy groups to keep when reading units (default ["good" "mua"])
%     Detected   true (default: <Name>_spikes.mat when present) | a spikes
%                file | a detected struct | false
%     Sources    provenance to record for inputs passed as structs: a struct
%                with any of extractFile, spikesFile, sortingDir (what is
%                read from files here replaces it). EphysPipeline.runExport
%                reads a dataset's inputs once and passes them to every format
%                this way
%     Events     true (default) | false
%     Overwrite  false (default): error if File exists
%     MatVersion "-v7.3" (default) | "-v7"
%
%   See also ChronuxDataset, EphysDataset.exportFieldTrip, EphysDataset.toMat,
%   EphysDataset.spikesToMat, EphysDataset.readSortedUnits.

arguments
    obj (1,1) EphysDataset
    opts.File (1,1) string = ""
    opts.Extract = ""
    opts.Signals (1,:) string = string.empty(1,0)
    opts.Units = []
    opts.Groups (1,:) string = ["good" "mua"]
    opts.Detected = true
    opts.Sources struct = struct()
    opts.Events (1,1) logical = true
    opts.Overwrite (1,1) logical = false
    opts.MatVersion (1,1) string {mustBeMember(opts.MatVersion, ["-v7.3", "-v7"])} = "-v7.3"
end

t0 = tic;
file = opts.File;
if file == ""
    file = string(fullfile(obj.outputFolder(), obj.Name + "_chronux.mat"));
end
if isfile(file) && ~opts.Overwrite
    error('EphysDataset:exportChronux:Exists', ...
        '%s already exists (pass Overwrite=true to replace it).', file);
end

in = resolveExportInputs(obj, opts, 'exportChronux');

S = struct();
for sig = in.signals
    cx = ChronuxDataset(in.S, Signal=sig);
    [data, params, info] = cx.continuous(Class="double");
    t = ((info.sampleRange(1):info.sampleRange(2)) - 1) / info.fs;
    S.(sig) = struct('data', data, 'params', params, 't', t, ...
        'labels', string(info.labels(:)).', 'info', info);
end

S.sp = [];
S.units = [];
if ~isempty(in.units)
    S.sp    = ChronuxDataset.toPointProcess(in.units.times);
    S.units = in.units;
end
S.spDetected = [];
S.detected   = [];
if ~isempty(in.detected)
    S.spDetected = ChronuxDataset.toPointProcess(in.detected.ts);
    S.detected   = in.detected;
end
S.events   = in.events;
S.artifacts = in.artifacts;
S.export = struct( ...
    'tool',       "EphysDataset.exportChronux", ...
    'created',    string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'dataset',    obj.Name, ...
    'sourceFolder', obj.Folder, ...
    'signals',    in.signals, ...
    'eventFs',    in.eventFs, ...
    'nUnits',     numel(S.sp), ...
    'nDetectedChannels', numel(S.spDetected), ...
    'sources',    in.sources, ...
    'timeConventions', struct('continuous', "t = (sample-1)/Fs", ...
        'events', "t = row/eventFs (1-based row of the recording); row round((t - 1/eventFs)*Fs) + 1 of a signal at Fs", ...
        'spikes', "seconds on the recording clock", ...
        'artifacts', "[tStart tEnd) s on the continuous clock; rows EphysDataset.intervalRows(intervals, Fs, nRows) of a signal at Fs"));

EphysDataset.saveAtomically(file, S, opts.MatVersion);

d = dir(file);
out = struct('file', file, 'bytes', d.bytes, 'seconds', toc(t0), ...
    'signals', in.signals, 'nUnits', numel(S.sp), ...
    'nDetectedChannels', numel(S.spDetected), 'sources', in.sources);
end
