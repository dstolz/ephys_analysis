function E = digitalEvents(obj, opts)
%digitalEvents  The recording's digital-input events, cached next to its outputs.
%   E = ds.digitalEvents() returns struct events (one field per line, [k x 2]
%   [t_on t_off] seconds, t = row/Fs, HIGH runs as recorded), Fs, nSamples,
%   digInNames (the final line names, see relabelEvents), digInNativeNames,
%   digInDefaultNames (the names without LineNames) and source ("cache" |
%   "read"). Reading the events can mean reading the whole recording (see
%   EphysReader.readDigitalEvents), so the reader's native-keyed result is
%   saved as <outputFolder>/<Name>_events.mat and reused while the recording
%   files, their sample count and the reader are unchanged. The lines are
%   named after loading, so renaming a line never re-reads the recording.
%
%   Options
%     LabelField   "custom" | "native": each line's default name (default
%                  TrialConfig.LabelField)
%     LineNames    "native=name" entries (default TrialConfig.LineNames)
%     Relabel      true (default); false returns the events keyed by the
%                  native line names (digInNames are then the custom names)
%     Cache        true (default): read and write the cache file
%     Refresh      false (default): true ignores an existing cache
%     ProgressFcn  forwarded to the reader as ProgressFcn(i, nFiles, name)
%
%   See also EphysReader.readDigitalEvents, EphysDataset.relabelEvents,
%   EphysDataset.pairTrials.

arguments
    obj (1,1) EphysDataset
    opts.LabelField (1,1) string = ""
    opts.LineNames = []
    opts.Relabel (1,1) logical = true
    opts.Cache (1,1) logical = true
    opts.Refresh (1,1) logical = false
    opts.ProgressFcn = []
end

[labelField, lineNames] = obj.lineNaming(opts.LabelField, opts.LineNames);
obj.requireReader('digitalEvents');
if isnan(obj.Fs) || isempty(obj.PerFile)
    obj.refreshMetadata();
end
fp = string(jsonencode(struct('reader', string(obj.Reader.Kind), ...
    'files', {cellstr(obj.Files(:).')}, 'nSamples', obj.NumSamples)));
cacheFile = fullfile(obj.outputFolder(), obj.Name + "_events.mat");

E = [];
if opts.Cache && ~opts.Refresh && isfile(cacheFile)
    try
        C = load(cacheFile, 'digitalEvents');
        if isfield(C, 'digitalEvents') && isfield(C.digitalEvents, 'fingerprint') ...
                && string(C.digitalEvents.fingerprint) == fp
            E = rmfield(C.digitalEvents, 'fingerprint');
            E.source = "cache";
        end
    catch
    end
end

if isempty(E)
    R = obj.Reader.readDigitalEvents(ProgressFcn=opts.ProgressFcn);
    E = struct('events', R.events, 'Fs', R.Fs, 'nSamples', R.nSamples, ...
        'digInNames', string(R.digInNames), 'digInNativeNames', string(R.digInNativeNames));
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

if opts.Relabel
    E = EphysDataset.relabelEvents(E, labelField, lineNames);
end
end
