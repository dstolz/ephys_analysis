function files = writeTDTBlock(folder, spec)
%writeTDTBlock  Write a TDT Synapse block (TSQ / TEV / Tbk / SEV) for tests.
%   FILES = writeTDTBlock(FOLDER, SPEC) creates FOLDER and writes a block
%   in TDT's tank format, as TDTbin2mat / tdt.read_block read it:
%     <Name>.tsq   40-byte event headers ordered by time: a file header, the
%                  block start mark (code 1), stream chunk and epoc headers,
%                  and (unless SPEC.StopMark is false) the stop mark (code 2)
%     <Name>.tev   the stream chunks' samples, in TSQ order
%     <Name>.Tbk   store notes (when SPEC.Notes is given)
%     <Name>_<Store>_Ch<c>.sev   one file per channel of a SEV stream
%                  (40-byte header, version 3)
%   Returns the paths written (cellstr).
%
%   SPEC fields
%     Name       block name (the file stem)
%     StartTime  block start, seconds since 1970 (UTC)
%     StopTime   block stop (default: StartTime + the longest stream)
%     StopMark   true (default): write the stop mark
%     Streams    struct array: Name (4 chars), Fs, Data ([nSamp x nChan] of
%                the stored class: single, int16, int32, double, ...),
%                Npts (samples per TEV chunk, default 256), Sev (false:
%                TEV; true: SEV files), T0 (s from the start, default 0:
%                the time of the first sample), ChunkTimes (optional
%                [nChunks x 1] s: each chunk's time, for gap tests), Rate /
%                Decimate (SEV header: Fs = 2^(Rate-12)*25e6/Decimate),
%                Channels (channel numbers, default 1..nChan)
%     Epocs      struct array: Name, Onset, Value (column vectors, s from
%                the start), Offset ([] for an onset-only store), OffName
%                (the buddy offset store's name, when Offset is given)
%     Notes      struct array of .Tbk store notes (char fields), optional
%     Junk       optional [k x 1] header codes to add as snip headers (no data)
%
%   Plain MATLAB (no string or arguments syntax) so it also runs in Octave.

if ~isfield(spec, 'StopMark'); spec.StopMark = true; end
if ~exist(folder, 'dir'); mkdir(folder); end
files = {};
base = fullfile(folder, spec.Name);
start = spec.StartTime;

% --- collect events: [time, order, header words] ----------------------------
ev = struct('T', zeros(0, 1), 'W', zeros(10, 0, 'uint32'));
ev.payload = {};                      % TEV payload per event ([] for none)

streams = struct([]);
if isfield(spec, 'Streams'); streams = spec.Streams; end
longest = 0;
for s = 1:numel(streams)
    S = streams(s);
    X = S.Data;
    fmt = class(X);
    [dform, itemSize] = formatCode(fmt);
    nCh = size(X, 2);
    chans = 1:nCh;
    if isfield(S, 'Channels') && ~isempty(S.Channels); chans = S.Channels; end
    t0 = 0; if isfield(S, 'T0') && ~isempty(S.T0); t0 = S.T0; end
    sev = isfield(S, 'Sev') && ~isempty(S.Sev) && S.Sev;
    longest = max(longest, t0 + size(X, 1) / S.Fs);
    code = nameCode(S.Name);
    if sev
        type = hex2dec('8111');
        for c = 1:nCh
            ev = addEvent(ev, start + t0, streamWords(10, type, code, chans(c), dform, S.Fs), []);
        end
        rate = S.Rate; decimate = S.Decimate;
        for c = 1:nCh
            f = sprintf('%s_%s_Ch%d.sev', base, S.Name, chans(c));
            fid = fopen(f, 'w', 'ieee-le');
            fwrite(fid, 40 + size(X, 1) * itemSize, 'uint64');
            fwrite(fid, 'SEV', 'uint8');
            fwrite(fid, 3, 'uint8');
            fwrite(fid, pad4(S.Name), 'uint8');
            fwrite(fid, chans(c), 'uint16');
            fwrite(fid, nCh, 'uint16');
            fwrite(fid, itemSize, 'uint16');
            fwrite(fid, 0, 'uint16');
            fwrite(fid, dform, 'uint8');
            fwrite(fid, decimate, 'uint8');
            fwrite(fid, rate, 'uint16');
            fwrite(fid, zeros(1, 12), 'uint8');
            fwrite(fid, X(:, c), fmt);
            fclose(fid);
            files{end + 1} = f; %#ok<AGROW>
        end
    else
        npts = 256; if isfield(S, 'Npts') && ~isempty(S.Npts); npts = S.Npts; end
        nChunks = ceil(size(X, 1) / npts);
        if mod(size(X, 1), npts) ~= 0
            error('writeTDTBlock:Chunks', 'Stream %s: %d samples are not whole chunks of %d.', S.Name, size(X, 1), npts);
        end
        if isfield(S, 'ChunkTimes') && ~isempty(S.ChunkTimes)
            ct = S.ChunkTimes(:);
        else
            ct = t0 + (0:nChunks - 1).' * npts / S.Fs;
        end
        sizeWords = 10 + npts * itemSize / 4;
        for k = 1:nChunks
            for c = 1:nCh
                ev = addEvent(ev, start + ct(k), streamWords(sizeWords, hex2dec('8101'), code, chans(c), dform, S.Fs), ...
                    X((k - 1) * npts + (1:npts), c));
            end
        end
    end
end

epocs = struct([]);
if isfield(spec, 'Epocs'); epocs = spec.Epocs; end
for e = 1:numel(epocs)
    E = epocs(e);
    hasOff = isfield(E, 'Offset') && ~isempty(E.Offset);
    buddy = '    ';
    if hasOff; buddy = pad4(E.OffName); end
    for i = 1:numel(E.Onset)
        ev = addEvent(ev, start + E.Onset(i), epocWords(hex2dec('101'), nameCode(E.Name), buddy, E.Value(i)), []);
    end
    if hasOff
        for i = 1:numel(E.Offset)
            v = 0; if i <= numel(E.Value); v = E.Value(i); end
            ev = addEvent(ev, start + E.Offset(i), epocWords(hex2dec('102'), nameCode(E.OffName), pad4(E.Name), v), []);
        end
    end
end

if isfield(spec, 'Junk')
    for i = 1:numel(spec.Junk)
        ev = addEvent(ev, start + 0.001 * i, streamWords(10, hex2dec('8201'), spec.Junk(i), 1, 0, 24414.0625), []);
    end
end

[~, order] = sortrows([ev.T (1:numel(ev.T)).']);   % by time, then as added
W = ev.W(:, order); payload = ev.payload(order);

% --- TEV: payloads in TSQ order, offsets into the headers -----------------------
fid = fopen([base '.tev'], 'w', 'ieee-le');
pos = 0;
for i = 1:numel(payload)
    d = payload{i};
    if isempty(d); continue; end
    W(7:8, i) = typecast(uint64(pos), 'uint32');
    fwrite(fid, d, class(d));
    pos = pos + numel(d) * formatSize(class(d));
end
fclose(fid);
files{end + 1} = [base '.tev'];

% --- TSQ ---------------------------------------------------------------------------
stop = start + longest;
if isfield(spec, 'StopTime') && ~isempty(spec.StopTime); stop = spec.StopTime; end
head = zeros(10, 1, 'uint32');
startMark = markWords(1, start);
stopMark = markWords(2, stop);
allW = [head startMark W];
if spec.StopMark; allW = [allW stopMark]; end
fid = fopen([base '.tsq'], 'w', 'ieee-le');
fwrite(fid, allW, 'uint32');
fclose(fid);
files{end + 1} = [base '.tsq'];

% --- Tbk -----------------------------------------------------------------------------
if isfield(spec, 'Notes') && ~isempty(spec.Notes)
    N = spec.Notes;
    nl = char(10);
    txt = ['[USERNOTEDELIMITER]' nl 'block notes' nl '[USERNOTEDELIMITER]'];   % the first note follows the delimiter
    for k = 1:numel(N)
        f = fieldnames(N(k));
        f = [{'StoreName'}; f(~strcmp(f, 'StoreName'))];
        for j = 1:numel(f)
            txt = [txt 'Name=' f{j} ';Type=3;Value=' N(k).(f{j}) ';' nl]; %#ok<AGROW>
        end
    end
    txt = [txt '[USERNOTEDELIMITER]'];
    fid = fopen([base '.Tbk'], 'w');
    fwrite(fid, txt, 'uint8');
    fclose(fid);
    files{end + 1} = [base '.Tbk'];
end
end


function ev = addEvent(ev, t, words, data)
%addEvent  One TSQ header at time T (s since 1970) with its TEV payload.
words(5:6) = typecast(double(t), 'uint32');
ev.T(end + 1, 1) = t;
ev.W(:, end + 1) = words;
ev.payload{end + 1} = data;
end


function w = streamWords(sizeWords, type, code, chan, dform, fs)
w = zeros(10, 1, 'uint32');
w(1) = sizeWords;
w(2) = type;
w(3) = code;
w(4) = chan;
w(9) = dform;
w(10) = typecast(single(fs), 'uint32');
end


function w = epocWords(type, code, buddy, value)
w = zeros(10, 1, 'uint32');
w(1) = 10;
w(2) = type;
w(3) = code;
w(4) = typecast(uint8(buddy), 'uint32');
w(7:8) = typecast(double(value), 'uint32');
w(9) = 4;
end


function w = markWords(code, t)
w = zeros(10, 1, 'uint32');
w(1) = 10;
w(2) = hex2dec('8801');
w(3) = code;
w(5:6) = typecast(double(t), 'uint32');
end


function c = nameCode(name)
c = double(typecast(uint8(pad4(name)), 'uint32'));
end


function s = pad4(s)
s = [s repmat(' ', 1, 4 - numel(s))];
s = s(1:4);
end


function [dform, n] = formatCode(fmt)
switch fmt
    case 'single', dform = 0;
    case 'int32',  dform = 1;
    case 'int16',  dform = 2;
    case 'int8',   dform = 3;
    case 'double', dform = 4;
    case 'int64',  dform = 5;
    otherwise, error('writeTDTBlock:Format', 'Unsupported class %s.', fmt);
end
n = formatSize(fmt);
end


function n = formatSize(fmt)
switch fmt
    case {'single', 'int32'}, n = 4;
    case 'int16', n = 2;
    case 'int8', n = 1;
    case {'double', 'int64'}, n = 8;
end
end
