function loadSignal(obj, opts)
%loadSignal  Read the configured continuous signal into memory (once).
%   cx.loadSignal() populates Data, Fs, ChannelLabels, Events and Info from the
%   source this connector was constructed with, and does nothing if the signal
%   is already loaded. Every data method calls it, so you rarely need to: call
%   it explicitly to control when the (possibly long) read happens, or with
%   Force=true to re-read after changing Signal or SignalOptions.
%
%   What is read, by source
%   -----------------------
%     IntanDataset, Signal "LFP"/"MUA"/"SPIKE"
%         IntanDataset.deriveSignals(SignalOptions..., dataTypeOut=Signal).
%         Data is that signal (single, microvolts), Fs its derived rate,
%         ChannelLabels info.labels, Events the digital-input events.
%     IntanDataset, Signal "RAW"
%         IntanDataset.readData, i.e. the broadband amplifier data at the
%         recording rate, unfiltered. Only keepAmpChannels and labelField are
%         honoured from SignalOptions (mapped to KeepChannels /
%         EventLabelField); any other field is an error, because the derived-
%         signal options have no meaning here.
%     .mat written by IntanDataset.toMat
%         Variables Y, events and info; Data is Y.(Signal), which must have
%         been requested in that conversion's dataTypeOut. "RAW" is not stored
%         in such a file.
%     numeric matrix
%         Nothing to read; Data was set at construction.
%
%   No values are modified: the samples are the ones deriveSignals / readData
%   produced, in microvolts, sample k at t = (k-1)/Fs seconds.
%
%   See also IntanDataset.deriveSignals, IntanDataset.readData,
%   IntanDataset.toMat.

arguments
    obj (1,1) ChronuxDataset
    opts.Force (1,1) logical = false     % re-read even when already loaded
end

if obj.Loaded && ~opts.Force
    return
end

switch obj.SourceType
    case "matrix"
        if isempty(obj.Data)
            error('ChronuxDataset:NoData', 'This connector holds no data.');
        end
        obj.Loaded = true;

    case "mat"
        loadFromMat(obj);

    case "dataset"
        loadFromDataset(obj);

    otherwise
        error('ChronuxDataset:NoSource', ...
            ['This ChronuxDataset has no data source. Construct it with an ' ...
             'IntanDataset, a recording folder, a toMat .mat file or a matrix.']);
end

if isempty(obj.ChannelLabels) && ~isempty(obj.Data)
    obj.ChannelLabels = "ch" + string(1:size(obj.Data, 2));
end
if numel(obj.ChannelLabels) ~= size(obj.Data, 2)
    warning('ChronuxDataset:LabelCount', ...
        ['%d channel labels for %d channels; labels are replaced by ch1..chN ' ...
         'so they cannot be mismatched.'], numel(obj.ChannelLabels), size(obj.Data, 2));
    obj.ChannelLabels = "ch" + string(1:size(obj.Data, 2));
end
end


function loadFromMat(obj)
%loadFromMat  Populate from a .mat written by IntanDataset.toMat.
if obj.Signal == "RAW"
    error('ChronuxDataset:RawFromMat', ...
        ['Signal "RAW" is not stored in a toMat .mat file (it holds the derived ' ...
         'LFP/MUA/SPIKE signals). Point this connector at the recording folder ' ...
         'instead.']);
end
vars = string(who('-file', obj.SourceFile)).';
missing = setdiff(["Y" "info"], vars);
if ~isempty(missing)
    error('ChronuxDataset:BadMat', ...
        '%s has no "%s" variable; is it an IntanDataset.toMat output?', ...
        obj.SourceFile, strjoin(missing, '", "'));
end
sel = cellstr(intersect(["Y" "events" "info"], vars));
S = load(obj.SourceFile, sel{:});
sig = obj.Signal;
if ~isfield(S.Y, sig) || isempty(S.Y.(sig))
    error('ChronuxDataset:SignalMissing', ...
        ['%s holds no %s signal (it was not in that conversion''s dataTypeOut). ' ...
         'Available: %s.'], obj.SourceFile, sig, availableSignals(S.Y));
end
if ~isfield(S.info, sig) || ~isfield(S.info.(sig), 'Fs')
    error('ChronuxDataset:SignalMissing', ...
        '%s has no info.%s.Fs, so the %s sample rate is unknown.', ...
        obj.SourceFile, sig, sig);
end

obj.Data = S.Y.(sig);
obj.Fs   = double(S.info.(sig).Fs);
if isfield(S.info, 'labels')
    obj.ChannelLabels = string(S.info.labels(:)).';
end
if isfield(S, 'events') && isstruct(S.events)
    obj.Events = S.events;
end
obj.Info = struct('source', "mat", 'file', obj.SourceFile, 'signal', sig, ...
    'fs', obj.Fs, 'units', "microvolts", 'derived', S.info);
obj.Loaded = true;
end


function loadFromDataset(obj)
%loadFromDataset  Populate from the IntanDataset (derived or raw).
ds = obj.Dataset;
if isempty(ds) || ~isa(ds, 'IntanDataset')
    error('ChronuxDataset:NoSource', 'No IntanDataset attached.');
end

if obj.Signal == "RAW"
    known = ["keepAmpChannels", "labelField"];
    extra = setdiff(string(fieldnames(obj.SignalOptions)).', known);
    if ~isempty(extra)
        error('ChronuxDataset:RawOptions', ...
            ['Signal "RAW" reads through IntanDataset.readData, which does not ' ...
             'take the derived-signal options %s. Only keepAmpChannels and ' ...
             'labelField apply.'], strjoin(extra, ', '));
    end
    args = {};
    if isfield(obj.SignalOptions, 'keepAmpChannels')
        args = [args, {'KeepChannels', obj.SignalOptions.keepAmpChannels}];
    end
    if isfield(obj.SignalOptions, 'labelField')
        args = [args, {'EventLabelField', obj.SignalOptions.labelField}];
    end
    d = ds.readData(args{:});
    obj.Data = d.amplifier;
    obj.Fs   = d.Fs;
    if isfield(obj.SignalOptions, 'labelField') && ...
            string(obj.SignalOptions.labelField) == "native_channel_name"
        obj.ChannelLabels = d.nativeNames;
    else
        obj.ChannelLabels = d.channelNames;
    end
    obj.Events = d.events;
    obj.Info = struct('source', "dataset", 'folder', ds.Folder, 'name', ds.Name, ...
        'signal', "RAW", 'fs', obj.Fs, 'units', "microvolts", ...
        'recordingFormat', ds.RecordingFormat, 'files', d.files, ...
        'filtered', false);
    obj.Loaded = true;
    return
end

if isfield(obj.SignalOptions, 'dataTypeOut')
    error('ChronuxDataset:DataTypeOut', ...
        ['Do not set dataTypeOut in SignalOptions; the Signal property ' ...
         '("%s") selects which signal this connector serves.'], obj.Signal);
end
args = namedargs2cell(obj.SignalOptions);
[Y, ev, info] = ds.deriveSignals(args{:}, 'dataTypeOut', obj.Signal);

sig = obj.Signal;
obj.Data = Y.(sig);
obj.Fs   = double(info.(sig).Fs);
obj.ChannelLabels = string(info.labels(:)).';
obj.Events = ev;
obj.Info = struct('source', "dataset", 'folder', ds.Folder, 'name', ds.Name, ...
    'signal', sig, 'fs', obj.Fs, 'units', "microvolts", ...
    'recordingFormat', ds.RecordingFormat, 'origFs', info.origFs, ...
    'derived', info);
obj.Loaded = true;
end


function s = availableSignals(Y)
%availableSignals  Comma-separated list of the non-empty signals in Y.
fn = string(fieldnames(Y)).';
have = fn(arrayfun(@(f) ~isempty(Y.(f)), fn));
if isempty(have)
    s = "none";
else
    s = strjoin(have, ", ");
end
end
