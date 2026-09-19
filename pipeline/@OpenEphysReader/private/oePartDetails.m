function P = oePartDetails(inv, part, stream, ordinal)
%oePartDetails  Sample count, stored-sample runs, start time and files of one recording.
%   P = oePartDetails(INV, PART, STREAM, ORDINAL) for PART of inventory INV
%   (oeInventory) and the selected STREAM; ORDINAL is the part's position
%   among its experiment's recordings (1-based). P has
%     nSamples     stored rows of the stream in this recording
%     runs         [k x 3] firstRow lastRow firstSampleNumber: gap-free runs
%                  of rows (one run when no samples were dropped)
%     firstSample  sample number of row 1
%     start        datetime (local, no time zone) of row 1; NaT if unknown
%     startSource  where the start came from
%     files        absolute paths of the data and event files
%   plus what the format's readers need (datFile / nChanStream; channelFiles
%   / firstRecord; file / dsPath / rowOffset).
%   Only headers and a few sample numbers (binary search) are read.

switch inv.format
    case "binary", P = binaryPart(part, stream);
    case "legacy", P = legacyPart(inv, part, stream, ordinal);
    case "nwb",    P = nwbPart(inv, part, stream, ordinal);
end
end


%% === Binary =================================================================
function P = binaryPart(part, stream)
cdir = fullfile(part.folder, "continuous", stream.key);
datFile = fullfile(cdir, "continuous.dat");
snFile  = fullfile(cdir, "sample_numbers.npy");
if ~isfile(datFile)
    error('OpenEphysReader:MissingFile', 'Missing %s', datFile);
end
nChan = numel(stream.channels);
d = dir(datFile);
n = floor(d.bytes / (2 * nChan));
if mod(d.bytes, 2 * nChan) ~= 0
    warning('OpenEphysReader:PartialSample', '%s ends with a partial sample; it is ignored.', datFile);
end
runs = [1 n 0];
firstSample = 0;
if isfile(snFile) && n > 0
    H = OpenEphysReader.npyHeader(snFile);
    if H.n ~= n
        warning('OpenEphysReader:SampleCount', ...
            '%s: continuous.dat holds %d samples but sample_numbers.npy %d; reading %d.', ...
            part.label, n, H.n, min(n, H.n));
        n = min(n, H.n);
    end
    fid = fopen(snFile, 'r', 'ieee-le');
    closer = onCleanup(@() fclose(fid));
    at = @(i) OpenEphysReader.npyAt(fid, H, i);
    runs = OpenEphysReader.findRuns(at, n, 1);
    firstSample = runs(1, 3);
    clear closer
end
[start, src] = binaryStart(part);
files = [string(datFile), string(snFile), fullfile(part.folder, "structure.oebin")];
ev = binaryEventDirs(part, stream);
for k = 1:numel(ev)
    files = [files, fullfile(ev(k).dir, ["states.npy" "sample_numbers.npy"])]; %#ok<AGROW>
end
runs = runs(runs(:, 1) <= n, :);
if ~isempty(runs); runs(end, 2) = min(runs(end, 2), n); end
P = struct('nSamples', n, 'runs', runs, 'firstSample', firstSample, ...
    'start', start, 'startSource', src, 'files', files(isfile(files)), ...
    'datFile', string(datFile), 'nChanStream', nChan, 'eventDirs', ev);
end


function ev = binaryEventDirs(part, stream)
%binaryEventDirs  TTL event folders of the stream (with the initial TTL word).
ev = struct('dir', {}, 'initialState', {}, 'name', {});
E = part.oebin;
if ~isfield(E, 'events') || isempty(E.events); return; end
C = E.events;
if isstruct(C); C = num2cell(C); end
for k = 1:numel(C)
    c = C{k};
    fn = string(regexprep(char(string(c.folder_name)), '[\\/]+$', ''));
    if ~startsWith(fn, stream.key + "/") && ~startsWith(fn, stream.key + "\"); continue; end
    leaf = extractAfter(fn, strlength(stream.key) + 1);
    if ~startsWith(leaf, "TTL"); continue; end
    init = NaN;
    if isfield(c, 'initial_state') && ~isempty(c.initial_state); init = double(c.initial_state); end
    ev(end+1) = struct('dir', string(fullfile(part.folder, "events", stream.key, leaf)), ...
        'initialState', init, 'name', leaf); %#ok<AGROW>
end
end


function [t, src] = binaryStart(part)
t = NaT; src = "";
f = fullfile(part.folder, "sync_messages.txt");
if isfile(f)
    txt = string(fileread(f));
    tok = regexp(txt, 'Software Time[^:\n]*:\s*(\d+)', 'tokens', 'once', 'ignorecase');
    if ~isempty(tok)
        t = OpenEphysReader.fromEpochMs(str2double(tok{1}));
        src = "sync_messages.txt";
        return
    end
end
d = dir(fullfile(part.folder, "structure.oebin"));
if ~isempty(d)
    t = datetime(d.datenum, 'ConvertFrom', 'datenum');
    src = "structure.oebin modification time";
end
end


%% === Open Ephys (legacy) format ================================================
function P = legacyPart(inv, part, stream, ordinal)
node = inv.nodeFolder;
chFiles = strings(1, numel(stream.channels));
for j = 1:numel(stream.channels)
    chFiles(j) = string(fullfile(node, stream.channels(j).base + part.expSuffix + ".continuous"));
end
missing = chFiles(~isfile(chFiles));
if ~isempty(missing)
    error('OpenEphysReader:MissingFile', 'Missing %s', strjoin(missing, ", "));
end
[fid, nRec] = OpenEphysReader.openContinuous(chFiles(1));
closer = onCleanup(@() fclose(fid));
% The block of records holding this recording number (binary search).
first = recordBound(fid, nRec, part.recNumber, "first");
last  = recordBound(fid, nRec, part.recNumber, "last");
if isnan(first)
    error('OpenEphysReader:NoRecords', '%s: no records of recording %d in %s.', ...
        part.label, part.recNumber, chFiles(1));
end
% The other channel files must hold the same records.
nRecAll = nRec;
for j = 2:numel(chFiles)
    d = dir(chFiles(j));
    nj = floor((d.bytes - 1024) / 2070);
    if nj ~= nRec
        nRecAll = min(nRecAll, nj);
    end
end
if nRecAll < nRec
    warning('OpenEphysReader:ChannelFilesDiffer', ...
        '%s: the channel files of %s hold different numbers of records; reading the %d they share.', ...
        part.label, stream.name, nRecAll);
    last = min(last, nRecAll - 1);
end
nRecords = max(0, last - first + 1);
runsRec = OpenEphysReader.findRuns(@(i) legacyRecordSample(fid, first + i - 1), nRecords, 1024);
runs = [(runsRec(:, 1) - 1) * 1024 + 1, runsRec(:, 2) * 1024, runsRec(:, 3)];
firstSample = NaN;
if ~isempty(runs); firstSample = runs(1, 3); end
% Start time: this recording's Software Time line, else the file header's
% creation time plus the offset from the experiment's first sample.
[t, src] = legacySoftwareTime(node, part.expSuffix, ordinal);
if isnat(t)
    h = OpenEphysReader.continuousHeader(chFiles(1));
    s0 = legacyRecordSample(fid, 0);
    if ~isnat(h.created)
        t = h.created + seconds((firstSample - s0) / stream.Fs);
        src = ".continuous header date_created";
    end
end
evFile = legacyEventsFile(node, stream, part.expSuffix);
files = chFiles;
if evFile ~= ""; files(end+1) = evFile; end
msg = fullfile(node, "messages" + part.expSuffix + ".events");
if isfile(msg); files(end+1) = string(msg); end
P = struct('nSamples', nRecords * 1024, 'runs', runs, 'firstSample', firstSample, ...
    'start', t, 'startSource', src, 'files', files, 'channelFiles', chFiles, ...
    'firstRecord', first, 'nRecords', nRecords, 'recNumber', part.recNumber, 'eventsFile', evFile);
end


function k = recordBound(fid, nRec, rn, which)
%recordBound  First / last record (0-based) with recording number RN, NaN if none.
k = NaN;
lo = 0; hi = nRec - 1;
if nRec == 0; return; end
if which == "first"
    while lo < hi
        mid = floor((lo + hi) / 2);
        [~, m] = OpenEphysReader.recordHeader(fid, mid);
        if m >= rn; hi = mid; else; lo = mid + 1; end
    end
else
    while lo < hi
        mid = floor((lo + hi + 1) / 2);
        [~, m] = OpenEphysReader.recordHeader(fid, mid);
        if m <= rn; lo = mid; else; hi = mid - 1; end
    end
end
[~, m] = OpenEphysReader.recordHeader(fid, lo);
if m == rn; k = lo; end
end


function s = legacyRecordSample(fid, k)
s = OpenEphysReader.recordHeader(fid, k);
end


function [t, src] = legacySoftwareTime(node, suffix, ordinal)
t = NaT; src = "";
f = fullfile(node, "messages" + suffix + ".events");
if ~isfile(f); return; end
txt = string(fileread(f));
tok = regexp(txt, '(\d+)\s*,\s*Software Time', 'tokens', 'ignorecase');
if numel(tok) >= ordinal
    t = OpenEphysReader.fromEpochMs(str2double(tok{ordinal}{1}));
    src = "messages" + suffix + ".events";
end
end


function f = legacyEventsFile(node, stream, suffix)
%legacyEventsFile  The stream's .events file (GUI 0.6+), else all_channels.events (0.4 / 0.5).
f = "";
cand = "all_channels" + suffix + ".events";
if stream.key ~= stream.processorId
    cand = [string(stream.key) + suffix + ".events", cand];
end
for c = cand
    if isfile(fullfile(node, c)); f = string(fullfile(node, c)); return; end
end
end


%% === NWB ======================================================================
function P = nwbPart(inv, part, stream, ordinal)
file = part.file;
ds = "/acquisition/" + stream.key;
info = h5info(file, ds + "/data");
nTotal = info.Dataspace.Size(2);
nChan = info.Dataspace.Size(1);
syncAt = @(i) double(h5read(file, ds + "/sync", i, 1));
% Recording boundaries: rows where this stream's "Start Time" sample numbers occur.
S = part.startSample;
mine = S(arrayfun(@(s) contains(s.text, "(" + stream.processorId + ") - " + stream.name + " @"), S));
nRecs = sum([inv.parts.experiment] == part.experiment);
rowStart = 1; rowEnd = nTotal;
if numel(mine) == nRecs && nTotal > 0
    starts = zeros(1, nRecs);
    for r = 1:nRecs
        starts(r) = firstRowAtLeast(syncAt, nTotal, mine(r).sample);
    end
    rowStart = starts(ordinal);
    if ordinal < nRecs; rowEnd = starts(ordinal + 1) - 1; end
elseif nRecs > 1
    if ordinal > 1; rowStart = nTotal + 1; end   % empty part: read the experiment as one
    if ordinal == 1
        warning('OpenEphysReader:NwbRecordings', ...
            ['%s: cannot find where each of its %d recordings starts (sync_messages); ' ...
             'reading experiment %d as one recording.'], file, nRecs, part.experiment);
    end
end
n = max(0, rowEnd - rowStart + 1);
runs = zeros(0, 3); firstSample = NaN;
if n > 0
    runs = OpenEphysReader.findRuns(@(i) syncAt(rowStart + i - 1), n, 1);
    firstSample = runs(1, 3);
end
t = NaT; src = "";
if isfinite(part.startTimeMs)
    t = OpenEphysReader.fromEpochMs(part.startTimeMs); src = "sync_messages";
else
    try
        s0 = h5read(file, '/session_start_time');
        t0 = OpenEphysReader.parseIsoLocal(string(s0));
        if ~isnat(t0) && n > 0
            t = t0 + seconds((firstSample - syncAt(1)) / stream.Fs);
            src = "session_start_time";
        end
    catch
    end
end
P = struct('nSamples', n, 'runs', runs, 'firstSample', firstSample, 'start', t, ...
    'startSource', src, 'files', string(file), 'file', string(file), 'dsPath', ds, ...
    'rowOffset', rowStart - 1, 'nChanStream', nChan);
end


function r = firstRowAtLeast(syncAt, n, value)
%firstRowAtLeast  First row whose sample number is >= VALUE (n + 1 if none).
lo = 1; hi = n + 1;
while lo < hi
    mid = floor((lo + hi) / 2);
    if syncAt(mid) >= value; hi = mid; else; lo = mid + 1; end
end
r = lo;
end
