function inv = oeInventory(node)
%oeInventory  Experiments, recordings and continuous streams of one Record Node.
%   INV = oeInventory(NODE) (NODE from oeNodes) returns
%     format    "binary" | "legacy" | "nwb"
%     parts     struct array, one per recording in (experiment, recording)
%               order: experiment, recording (1-based), label ("exp1/rec1")
%               and the format's locations (see below)
%     streams   struct array: key (unique id), name (as the GUI shows it),
%               processor, processorId, Fs, and channels (struct array:
%               name, type "headstage" | "aux" | "adc", bitVolts, plus the
%               format's locations), in the stream's own channel order
%   Binary parts carry folder + oebin; legacy parts carry expSuffix and
%   recNumber (0-based, from the record headers); NWB parts carry file,
%   startSample (from sync_messages) and the stream-independent fields.
%   Only headers, small JSON/XML files and HDF5 metadata are read.

switch node.format
    case "binary", inv = binaryInventory(node.folder);
    case "legacy", inv = legacyInventory(node.folder);
    case "nwb",    inv = nwbInventory(node.folder);
    otherwise
        error('OpenEphysReader:Format', 'Unknown Open Ephys format "%s".', node.format);
end
inv.format = node.format;
inv.nodeFolder = string(node.folder);
end


%% === Binary =================================================================
function inv = binaryInventory(nodeFolder)
parts = struct('experiment', {}, 'recording', {}, 'label', {}, 'folder', {}, 'oebin', {});
for e = numberedDirs(nodeFolder, "experiment")
    expDir = fullfile(nodeFolder, "experiment" + e);
    for r = numberedDirs(expDir, "recording")
        recDir = fullfile(expDir, "recording" + r);
        f = fullfile(recDir, 'structure.oebin');
        if ~isfile(f); continue; end
        oebin = readJsonFile(f);
        parts(end+1) = struct('experiment', e, 'recording', r, ...
            'label', sprintf("exp%d/rec%d", e, r), 'folder', string(recDir), 'oebin', oebin); %#ok<AGROW>
    end
end
streams = emptyStreams();
if ~isempty(parts)
    streams = binaryStreams(parts(1).oebin);
end
inv = struct('parts', parts, 'streams', streams);
end


function streams = binaryStreams(oebin)
streams = emptyStreams();
C = asCell(fieldOr(oebin, 'continuous', {}));
for k = 1:numel(C)
    c = C{k};
    key = string(regexprep(char(string(c.folder_name)), '[\\/]+$', ''));
    chans = asCell(fieldOr(c, 'channels', {}));
    ch = struct('name', {}, 'type', {}, 'bitVolts', {});
    for j = 1:numel(chans)
        cj = chans{j};
        name = string(fieldOr(cj, 'channel_name', "CH" + j));
        ch(j) = struct('name', name, 'type', channelType(name, fieldOr(cj, 'type', [])), ...
            'bitVolts', double(fieldOr(cj, 'bit_volts', 1)));
    end
    nDecl = double(fieldOr(c, 'num_channels', numel(ch)));
    if nDecl ~= numel(ch)
        error('OpenEphysReader:BadOebin', ...
            'structure.oebin stream %s declares %d channels but lists %d.', key, nDecl, numel(ch));
    end
    streams(end+1) = struct('key', key, ...
        'name', string(fieldOr(c, 'stream_name', key)), ...
        'processor', string(fieldOr(c, 'source_processor_name', "")), ...
        'processorId', string(fieldOr(c, 'source_processor_id', "")), ...
        'Fs', double(c.sample_rate), 'channels', ch); %#ok<AGROW>
end
end


%% === Open Ephys (legacy) format ================================================
function inv = legacyInventory(nodeFolder)
D = dir(fullfile(nodeFolder, '*.continuous'));
D = D(~[D.isdir]);
% Parse "<proc>_<stream>_<channel>[_<exp>]" (GUI 0.6+) and
% "<proc>_<channel>[_<exp>]" (GUI 0.4 / 0.5). "_" never occurs inside a
% stream or channel name (the GUI replaces it with "-").
info = struct('file', {}, 'proc', {}, 'stream', {}, 'chanToken', {}, 'exp', {});
for k = 1:numel(D)
    [~, stem] = fileparts(D(k).name);
    tok = split(string(stem), "_").';
    exp = 1;
    if numel(tok) >= 3 && ~isempty(regexp(tok(end), '^\d+$', 'once'))
        exp = str2double(tok(end));
        tok = tok(1:end-1);
    end
    if numel(tok) < 2 || isempty(regexp(tok(1), '^\d+$', 'once')); continue; end
    if numel(tok) == 2
        stream = ""; chanToken = tok(2);
    else
        stream = strjoin(tok(2:end-1), "_"); chanToken = tok(end);
    end
    info(end+1) = struct('file', string(D(k).name), 'proc', tok(1), 'stream', stream, ...
        'chanToken', chanToken, 'exp', exp); %#ok<AGROW>
end
parts = struct('experiment', {}, 'recording', {}, 'label', {}, 'expSuffix', {}, 'recNumber', {});
streams = emptyStreams();
if isempty(info)
    inv = struct('parts', parts, 'streams', streams);
    return
end

% Streams from experiment 1's files (or the lowest experiment present).
exps = unique([info.exp]);
first = info([info.exp] == exps(1));
streamKey = [first.proc];
hasName = [first.stream] ~= "";
streamKey(hasName) = streamKey(hasName) + "_" + [first(hasName).stream];
keys = unique(streamKey, 'stable');
for s = keys
    sel = first(streamKey == s);
    ch = struct('name', {}, 'type', {}, 'bitVolts', {}, 'base', {}, 'Fs', {}, 'created', {});
    for j = 1:numel(sel)
        h = OpenEphysReader.continuousHeader(fullfile(nodeFolder, sel(j).file));
        name = h.channel;
        if name == ""; name = sel(j).chanToken; end
        base = sel(j).proc + "_" + sel(j).chanToken;
        if sel(j).stream ~= ""; base = sel(j).proc + "_" + sel(j).stream + "_" + sel(j).chanToken; end
        ch(j) = struct('name', name, 'type', channelType(name, []), 'bitVolts', h.bitVolts, ...
            'base', base, 'Fs', h.sampleRate, 'created', h.created);
    end
    ch = orderChannels(ch);
    fsAll = unique([ch.Fs]);
    streamName = sel(1).stream;
    if streamName == ""; streamName = sel(1).proc; end
    streams(end+1) = struct('key', s, 'name', streamName, 'processor', "", ...
        'processorId', sel(1).proc, 'Fs', fsAll(1), 'channels', rmfield(ch, 'Fs')); %#ok<AGROW>
    if numel(fsAll) > 1
        warning('OpenEphysReader:MixedRates', '%s: stream %s mixes sample rates %s Hz; using %g Hz.', ...
            nodeFolder, s, strjoin(string(fsAll), "/"), fsAll(1));
    end
end

% Recordings: the distinct recording numbers in each experiment's records
% (from the first file of the first stream; the reader checks the others).
for e = exps
    suffix = "";
    if e > 1; suffix = "_" + e; end
    f = fullfile(nodeFolder, streams(1).channels(1).base + suffix + ".continuous");
    if ~isfile(f); continue; end
    recs = legacyRecordingNumbers(f);
    for r = 1:numel(recs)
        parts(end+1) = struct('experiment', e, 'recording', recs(r) + 1, ...
            'label', sprintf("exp%d/rec%d", e, recs(r) + 1), 'expSuffix', suffix, ...
            'recNumber', recs(r)); %#ok<AGROW>
    end
end
inv = struct('parts', parts, 'streams', streams);
end


function recs = legacyRecordingNumbers(file)
%legacyRecordingNumbers  Distinct recording numbers in a .continuous file.
%   Recording numbers never decrease along the file, so each block is found
%   by a binary search for its last record.
recs = zeros(1, 0);
[fid, nRec] = OpenEphysReader.openContinuous(file);
if nRec == 0; fclose(fid); return; end
closer = onCleanup(@() fclose(fid));
k = 0;
while k < nRec
    [~, rn] = OpenEphysReader.recordHeader(fid, k);
    recs(end+1) = rn; %#ok<AGROW>
    lo = k; hi = nRec - 1;                      % last record with rn
    while lo < hi
        mid = floor((lo + hi + 1) / 2);
        [~, m] = OpenEphysReader.recordHeader(fid, mid);
        if m == rn; lo = mid; else; hi = mid - 1; end
    end
    k = lo + 1;
end
end


%% === NWB ======================================================================
function inv = nwbInventory(nodeFolder)
parts = struct('experiment', {}, 'recording', {}, 'label', {}, 'file', {}, 'startSample', {}, 'startTimeMs', {});
streams = emptyStreams();
D = dir(fullfile(nodeFolder, 'experiment*.nwb'));
nums = zeros(1, 0); files = strings(1, 0);
for k = 1:numel(D)
    tok = regexp(D(k).name, '^experiment(\d+)\.nwb$', 'tokens', 'once');
    if isempty(tok); continue; end
    nums(end+1) = str2double(tok{1}); %#ok<AGROW>
    files(end+1) = string(fullfile(D(k).folder, D(k).name)); %#ok<AGROW>
end
[nums, order] = sort(nums); files = files(order);
for k = 1:numel(nums)
    try
        I = h5info(files(k), '/acquisition');
    catch ME
        warning('OpenEphysReader:NwbUnreadable', ...
            'Cannot read %s (still open in the GUI, or not closed cleanly?): %s', files(k), ME.message);
        continue
    end
    if isempty(streams)
        streams = nwbStreams(files(k), I);
    end
    [starts, softMs] = nwbSyncMessages(files(k), I);
    n = max(1, numel(softMs));
    for r = 1:n
        ms = NaN; if r <= numel(softMs); ms = softMs(r); end
        parts(end+1) = struct('experiment', nums(k), 'recording', r, ...
            'label', sprintf("exp%d/rec%d", nums(k), r), 'file', files(k), ...
            'startSample', {starts}, 'startTimeMs', ms); %#ok<AGROW>
    end
end
inv = struct('parts', parts, 'streams', streams);
end


function streams = nwbStreams(file, I)
streams = emptyStreams();
[ids, groupNames] = electrodeTable(file);
for g = reshape(I.Groups, 1, [])
    if attr(g, 'neurodata_type') ~= "ElectricalSeries"; continue; end
    path = string(g.Name);
    key = extractAfter(path, "/acquisition/");
    parts = split(key, ".");
    proc = parts(1); streamName = strjoin(parts(2:end), ".");
    procId = string(regexp(char(proc), '(\d+)$', 'match', 'once'));
    procName = string(regexprep(char(proc), '-\d+$', ''));
    dsInfo = h5info(file, path + "/data");
    nCh = dsInfo.Dataspace.Size(1);             % MATLAB order: [channels x samples]
    conv = double(h5read(file, path + "/channel_conversion"));
    types = zeros(nCh, 1);
    try types = double(h5read(file, path + "/channel_type")); catch; end
    elec = (0:nCh-1).';
    try elec = double(h5read(file, path + "/electrodes")); catch; end
    base = min(elec);
    if ~isempty(ids)
        mine = ids(groupNames == key);
        if ~isempty(mine); base = min(mine); end
    end
    ti = h5info(file, path + "/timestamps");
    fs = NaN;
    ia = find(strcmp({ti.Attributes.Name}, 'interval'), 1);
    if ~isempty(ia); fs = 1 / double(ti.Attributes(ia).Value); end
    fs = round(fs, 2);
    if abs(fs - round(fs)) < 0.05; fs = round(fs); end
    ch = struct('name', {}, 'type', {}, 'bitVolts', {});
    nAux = 0; nAdc = 0;
    for j = 1:nCh
        switch types(j)
            case 1, nAux = nAux + 1; name = "AUX" + nAux; t = "aux";
            case 2, nAdc = nAdc + 1; name = "ADC" + nAdc; t = "adc";
            otherwise, name = "CH" + (elec(j) - base + 1); t = "headstage";
        end
        ch(j) = struct('name', name, 'type', t, 'bitVolts', round(conv(min(j, numel(conv))) * 1e6, 7, 'significant'));
    end
    streams(end+1) = struct('key', key, 'name', streamName, 'processor', procName, ...
        'processorId', procId, 'Fs', fs, 'channels', ch); %#ok<AGROW>
end
end


function [ids, groupNames] = electrodeTable(file)
%electrodeTable  Electrode ids and group names ("<proc>-<id>.<stream>") of the file.
ids = []; groupNames = strings(0, 1);
try
    ids = double(h5read(file, '/general/extracellular_ephys/electrodes/id'));
    g = h5read(file, '/general/extracellular_ephys/electrodes/group_name');
    groupNames = strtrim(string(g));
    groupNames = groupNames(:);
    if numel(groupNames) ~= numel(ids); ids = []; groupNames = strings(0, 1); end
catch
end
end


function [starts, softMs] = nwbSyncMessages(file, I)
%nwbSyncMessages  "Start Time for ..." entries and Software Time (ms) per recording.
starts = struct('text', {}, 'sample', {});
softMs = zeros(1, 0);
names = string({I.Groups.Name});
if ~any(names == "/acquisition/sync_messages"); return; end
try
    txt = strtrim(string(h5read(file, '/acquisition/sync_messages/data')));
    smp = double(h5read(file, '/acquisition/sync_messages/sync'));
catch
    return
end
txt = txt(:); smp = smp(:);
for k = 1:min(numel(txt), numel(smp))
    if startsWith(txt(k), "Software Time", 'IgnoreCase', true)
        softMs(end+1) = smp(k); %#ok<AGROW>
    elseif startsWith(txt(k), "Start Time for", 'IgnoreCase', true)
        starts(end+1) = struct('text', txt(k), 'sample', smp(k)); %#ok<AGROW>
    end
end
end


function v = attr(g, name)
v = "";
if isempty(g.Attributes); return; end
k = find(strcmp({g.Attributes.Name}, name), 1);
if ~isempty(k); v = string(g.Attributes(k).Value); end
end


%% === helpers ====================================================================
function s = emptyStreams()
s = struct('key', {}, 'name', {}, 'processor', {}, 'processorId', {}, 'Fs', {}, 'channels', {});
end


function n = numberedDirs(folder, prefix)
%numberedDirs  Sorted numbers N of the <prefix>N sub-folders.
n = zeros(1, 0);
D = dir(fullfile(folder, prefix + "*"));
D = D([D.isdir]);
for k = 1:numel(D)
    tok = regexp(D(k).name, "^" + prefix + "(\d+)$", 'tokens', 'once');
    if ~isempty(tok); n(end+1) = str2double(tok{1}); end %#ok<AGROW>
end
n = sort(n);
end


function t = channelType(name, typeField)
%channelType  "headstage" | "aux" | "adc" from the GUI's type (0/1/2), else the name.
if ~isempty(typeField) && isnumeric(typeField) && isscalar(typeField)
    switch typeField
        case 1, t = "aux"; return
        case 2, t = "adc"; return
        case 0, t = "headstage"; return
    end
end
if contains(upper(name), "AUX")
    t = "aux";
elseif contains(upper(name), "ADC")
    t = "adc";
else
    t = "headstage";
end
end


function ch = orderChannels(ch)
%orderChannels  Headstage, then aux, then ADC channels, each numerically by name.
if isempty(ch); return; end
cls = zeros(1, numel(ch));
cls([ch.type] == "aux") = 1;
cls([ch.type] == "adc") = 2;
num = EphysReader.trailingNumbers([ch.name]);
num(isnan(num)) = Inf;
[~, order] = sortrows([cls(:) num(:) (1:numel(ch)).']);
ch = ch(order);
end


function C = asCell(v)
if iscell(v); C = reshape(v, 1, []); elseif isstruct(v); C = num2cell(reshape(v, 1, [])); else; C = {}; end
end


function v = fieldOr(s, f, default)
if isstruct(s) && isfield(s, f) && ~isempty(s.(f)); v = s.(f); else; v = default; end
end
