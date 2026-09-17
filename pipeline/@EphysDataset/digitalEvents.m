function E = digitalEvents(obj, opts)
%digitalEvents  The recording's digital-input events, cached next to its outputs.
%   E = ds.digitalEvents() returns struct events (one field per line, [k x 2]
%   [t_on t_off] seconds, t = row/Fs, HIGH runs as recorded), Fs, nSamples,
%   digInNames and source ("cache" | "read"). Reading the events can mean
%   reading the whole recording (see EphysReader.readDigitalEvents), so the
%   result is saved as <outputFolder>/<Name>_events.mat and reused while the
%   recording files, their sample count and the label field are unchanged.
%
%   Options
%     LabelField   dig-in name used as the line name (default
%                  TrialConfig.LabelField)
%     Cache        true (default): read and write the cache file
%     Refresh      false (default): true ignores an existing cache
%     ProgressFcn  forwarded to readData as ProgressFcn(i, nFiles, name)
%
%   See also EphysReader.readDigitalEvents, EphysDataset.pairTrials.

arguments
    obj (1,1) EphysDataset
    opts.LabelField (1,1) string = ""
    opts.Cache (1,1) logical = true
    opts.Refresh (1,1) logical = false
    opts.ProgressFcn = []
end

labelField = opts.LabelField;
if labelField == ""
    labelField = string(obj.TrialConfig.LabelField);
end
obj.requireReader('digitalEvents');
if isnan(obj.Fs) || isempty(obj.PerFile)
    obj.refreshMetadata();
end
fp = string(jsonencode(struct('files', {cellstr(obj.Files(:).')}, ...
    'nSamples', obj.NumSamples, 'labelField', labelField)));
cacheFile = fullfile(obj.outputFolder(), obj.Name + "_events.mat");

if opts.Cache && ~opts.Refresh && isfile(cacheFile)
    try
        C = load(cacheFile, 'digitalEvents');
        if isfield(C, 'digitalEvents') && isfield(C.digitalEvents, 'fingerprint') ...
                && string(C.digitalEvents.fingerprint) == fp
            E = rmfield(C.digitalEvents, 'fingerprint');
            E.source = "cache";
            return
        end
    catch
    end
end

if isempty(opts.ProgressFcn)
    E = obj.Reader.readDigitalEvents(EventLabelField=labelField);
else
    data = obj.readData(KeepChannels=1, Precision="single", ...
        EventLabelField=labelField, ProgressFcn=opts.ProgressFcn);
    E = struct('events', data.events, 'Fs', data.Fs, ...
        'nSamples', size(data.amplifier, 1), 'digInNames', string(data.digInNames));
end
E = struct('events', E.events, 'Fs', E.Fs, 'nSamples', E.nSamples, 'digInNames', E.digInNames);

if opts.Cache
    digitalEvents = E;
    digitalEvents.fingerprint = fp;
    try
        outDir = fileparts(cacheFile);
        if ~isfolder(outDir); mkdir(outDir); end
        save(cacheFile, 'digitalEvents');
    catch ME
        warning('EphysDataset:digitalEvents:Cache', ...
            'Could not cache events for %s: %s', obj.Name, ME.message);
    end
end
E.source = "read";
end
