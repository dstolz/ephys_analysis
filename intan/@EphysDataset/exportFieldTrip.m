function out = exportFieldTrip(obj, opts)
%exportFieldTrip  Write this dataset's data as FieldTrip structures.
%   OUT = ds.exportFieldTrip(Name=Value) packages the derived continuous
%   signals, the sorted units and/or threshold-detected spikes, the
%   digital-input events and the behavior data into one .mat whose variables
%   load straight into FieldTrip outside this app (ft_preprocessing /
%   ft_definetrial / ft_spike_maketrials ...). Packaging is done by
%   FieldTripExport; FieldTrip itself is never required.
%
%   Variables in the file
%   ---------------------
%     data_LFP / data_MUA / data_SPIKE   FieldTrip raw structures, one trial
%                 spanning the signal (label, time, trial [nChan x N], fsample,
%                 sampleinfo, hdr, cfg). Each carries its own events at its own
%                 rate in cfg.event, ready for ft_definetrial.
%     spike       FieldTrip spike structure of the sorted units (label,
%                 timestamp in recording samples, hdr, cfg) or []
%     spikeDetected  the same for threshold-detected spikes (one "unit" per
%                 channel) or []
%     event       FieldTrip event struct array at the recording rate
%     behavior    Epsych2 session data (see behaviorStruct) or []
%     export      provenance: tool, created, dataset, sources, signals,
%                 validation (per structure: ok / message)
%
%   Options
%   -------
%     File, Extract, Signals, Units, Groups, Detected, Events, Behavior,
%     Overwrite, MatVersion   as in exportChronux
%     Validate   true (default): when FieldTrip is on the path run
%                ft_datatype_raw / ft_datatype_spike on the structures and
%                record the outcome (warn on failure); no-op otherwise
%
%   See also FieldTripExport, EphysDataset.exportChronux, EphysDataset.toMat,
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
    opts.Validate (1,1) logical = true
end

t0 = tic;
file = opts.File;
if file == ""
    file = string(fullfile(obj.outputFolder(), obj.Name + "_fieldtrip.mat"));
end
if isfile(file) && ~opts.Overwrite
    error('EphysDataset:exportFieldTrip:Exists', ...
        '%s already exists (pass Overwrite=true to replace it).', file);
end

in = resolveExportInputs(obj, opts, 'exportFieldTrip');

origFs = NaN;
if isfield(in.S.info, 'origFs'); origFs = double(in.S.info.origFs); end
if ~isfinite(origFs) && ~isnan(obj.Fs); origFs = obj.Fs; end

validation = struct();
S = struct();
for sig = in.signals
    data = FieldTripExport.raw(in.S, sig);
    data.cfg.event = FieldTripExport.event(in.events, data.fsample);
    if opts.Validate
        [ok, msg] = FieldTripExport.validate(data, "raw");
        validation.("data_" + sig) = struct('ok', ok, 'message', msg);
        if ~ok
            warning('EphysDataset:exportFieldTrip:Validate', ...
                'ft_datatype_raw rejected data_%s: %s', sig, msg);
        end
    end
    S.("data_" + sig) = data;
end

S.spike = [];
if ~isempty(in.units)
    S.spike = FieldTripExport.spike(in.units);
    if opts.Validate
        [ok, msg] = FieldTripExport.validate(S.spike, "spike");
        validation.spike = struct('ok', ok, 'message', msg);
        if ~ok
            warning('EphysDataset:exportFieldTrip:Validate', 'ft_datatype_spike rejected spike: %s', msg);
        end
    end
end
S.spikeDetected = [];
if ~isempty(in.detected)
    S.spikeDetected = FieldTripExport.spikeFromDetected(in.detected);
end

if isfinite(origFs)
    S.event = FieldTripExport.event(in.events, origFs);
else
    S.event = FieldTripExport.event(struct(), 1);
end
S.behavior = in.behavior;
S.export = struct( ...
    'tool',       "EphysDataset.exportFieldTrip", ...
    'created',    string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'dataset',    obj.Name, ...
    'sourceFolder', obj.Folder, ...
    'signals',    in.signals, ...
    'eventFs',    origFs, ...
    'nUnits',     numel(in.units), ...
    'sources',    in.sources, ...
    'validation', validation, ...
    'fieldtripOnPath', FieldTripExport.hasFieldTrip());
if ~isempty(in.units); S.export.nUnits = numel(in.units.unitId); else; S.export.nUnits = 0; end

EphysDataset.saveAtomically(file, S, opts.MatVersion);

d = dir(file);
out = struct('file', file, 'bytes', d.bytes, 'seconds', toc(t0), ...
    'signals', in.signals, 'nUnits', S.export.nUnits, ...
    'nEvents', numel(S.event), 'validation', validation, 'sources', in.sources);
end
