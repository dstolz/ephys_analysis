function out = exportChronux(obj, opts)
%exportChronux  Write this dataset's data in the shapes Chronux functions take.
%   OUT = ds.exportChronux(Name=Value) packages the derived continuous
%   signals, the sorted units and/or threshold-detected spikes, the
%   digital-input events and the behavior data into one .mat that can be
%   loaded and handed straight to Chronux (mtspectrumc, mtspectrumpt, ...)
%   outside this app. Packaging goes through ChronuxDataset (the Chronux
%   connector); no Chronux function is called and nothing is analysed.
%
%   Variables in the file
%   ---------------------
%     LFP / MUA / SPIKE   one struct per exported signal:
%                           data    [nSamples x nChan] double, microvolts
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
%     events      dig-in lines -> [k x 2] [t_on t_off] seconds (t = row/Fs)
%     behavior    Epsych2 session data (see behaviorStruct) or []
%     export      provenance: tool, created, dataset, sources, signals
%
%   Options
%   -------
%     File       target (default <outputFolder>/<Name>_chronux.mat)
%     Extract    "" (default: <outputFolder>/<Name>_extract.mat), another
%                extract file, or a toMat-shaped struct (Y, events, info)
%     Signals    subset of ["LFP" "MUA" "SPIKE"] ([] = all present)
%     Units      [] (default: the associated sorted units when present) |
%                a units struct | false (none)
%     Groups     phy groups to keep when reading units (default ["good" "mua"])
%     Detected   true (default: <Name>_spikes.mat when present) | a spikes
%                file | a detected struct | false
%     Events     true (default) | false
%     Behavior   [] (default: the extract's behavior, else the associated
%                Epsych2 session) | a struct | false
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
    opts.Events (1,1) logical = true
    opts.Behavior = []
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
S.behavior = in.behavior;
S.export = struct( ...
    'tool',       "EphysDataset.exportChronux", ...
    'created',    string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'dataset',    obj.Name, ...
    'sourceFolder', obj.Folder, ...
    'signals',    in.signals, ...
    'nUnits',     numel(S.sp), ...
    'nDetectedChannels', numel(S.spDetected), ...
    'sources',    in.sources, ...
    'timeConventions', struct('continuous', "t = (sample-1)/Fs", ...
        'events', "t = row/Fs (1-based row)", 'spikes', "seconds on the recording clock"));

EphysDataset.saveAtomically(file, S, opts.MatVersion);

d = dir(file);
out = struct('file', file, 'bytes', d.bytes, 'seconds', toc(t0), ...
    'signals', in.signals, 'nUnits', numel(S.sp), ...
    'nDetectedChannels', numel(S.spDetected), 'sources', in.sources);
end
